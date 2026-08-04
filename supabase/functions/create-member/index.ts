import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Best-effort cleanup after a failed profile/subscription insert. Without
// checking this, a failed rollback leaves a silent orphan: an auth user
// with no matching profile row, which then blocks re-registering the same
// phone/email with no visible cause (the error the admin sees is just
// "already registered", nothing points at the real, already-failed cleanup).
async function rollbackAuthUser(supabase: ReturnType<typeof createClient>, userId: string): Promise<string | null> {
  const { error } = await supabase.auth.admin.deleteUser(userId)
  if (error) {
    console.error(`rollbackAuthUser: failed to delete orphaned auth user ${userId}:`, error)
    return error.message
  }
  return null
}

// This function creates auth accounts and writes member records with the
// service-role key, so it must independently verify the caller is an actual
// logged-in admin - the platform's default JWT check only proves the caller
// has *some* valid token (the public anon key qualifies), not that they're
// authorized to do this.
async function requireAdmin(req: Request, supabase: ReturnType<typeof createClient>): Promise<Response | null> {
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '')
  if (!token) {
    return new Response(JSON.stringify({ error: 'Missing Authorization token' }), { status: 401, headers: corsHeaders })
  }
  const { data: userData, error: userError } = await supabase.auth.getUser(token)
  if (userError || !userData?.user) {
    return new Response(JSON.stringify({ error: 'Invalid or expired session' }), { status: 401, headers: corsHeaders })
  }
  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', userData.user.id)
    .single()
  if (profileError || profile?.role !== 'admin') {
    return new Response(JSON.stringify({ error: 'Admin privileges required' }), { status: 403, headers: corsHeaders })
  }
  return null
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: corsHeaders,
    })
  }

  try {
    const { name, phone, email, gender, address, pass_id, start_date, entry_date, discount_amount, extra_days } =
      await req.json()

    if (!name || !String(name).trim() || !phone || !String(phone).trim() || !pass_id || !start_date) {
      return new Response(
        JSON.stringify({ error: 'name, phone, pass_id and start_date are required' }),
        { status: 400, headers: corsHeaders },
      )
    }
    if (Number.isNaN(new Date(start_date).getTime())) {
      return new Response(JSON.stringify({ error: 'start_date is not a valid date' }), {
        status: 400,
        headers: corsHeaders,
      })
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const adminCheck = await requireAdmin(req, supabase)
    if (adminCheck) return adminCheck

    // Server-side duplicate-phone check - the admin UI already does this via
    // a blur handler + pre-submit re-check, but that's client-side only and
    // has a real bypass (supplying any custom, non-blank email for a phone
    // that already has an account skips the UI's only duplicate signal).
    // This is the actual create path, so it's the only place that can catch
    // every case regardless of what the client sent.
    const { data: existingByPhone } = await supabase
      .from('profiles')
      .select('id')
      .eq('phone', (phone as string).trim())
      .maybeSingle()
    if (existingByPhone) {
      return new Response(JSON.stringify({ error: 'This phone number is already registered.' }), {
        status: 409,
        headers: corsHeaders,
      })
    }

    // Fetch pass to compute end_date and to snapshot pass_price atomically
    // with the subscription insert below - price and duration must never be
    // read live again after this point (a later price change on gym_passes
    // must not retroactively affect this member's charge).
    const { data: pass, error: passError } = await supabase
      .from('gym_passes')
      .select('price, duration_days')
      .eq('id', pass_id)
      .single()

    if (passError || !pass) {
      return new Response(JSON.stringify({ error: 'Pass not found' }), {
        status: 400,
        headers: corsHeaders,
      })
    }

    const start = new Date(start_date)
    const end = new Date(start)
    end.setDate(end.getDate() + (pass.duration_days as number) + (Number(extra_days) > 0 ? Number(extra_days) : 0))
    const end_date = end.toISOString().substring(0, 10)

    // Use provided email or generate a placeholder
    const memberEmail = email?.trim()
      ? (email.trim() as string)
      : `${(phone as string).replace(/\D/g, '')}@member.vishalfitness.in`

    // Generate temporary password: VF-XXXXXXX
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789'
    let tempPassword = 'VF-'
    for (let i = 0; i < 7; i++) {
      tempPassword += chars[Math.floor(Math.random() * chars.length)]
    }

    // Create auth user — email_confirm: true skips OTP entirely
    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
      email: memberEmail,
      password: tempPassword,
      email_confirm: true,
      user_metadata: { full_name: name },
    })

    if (authError) {
      return new Response(JSON.stringify({ error: authError.message }), {
        status: 400,
        headers: corsHeaders,
      })
    }

    const userId = authData.user.id

    // Insert profile
    const { error: profileError } = await supabase.from('profiles').upsert({
      id: userId,
      full_name: (name as string).trim(),
      phone: (phone as string).trim(),
      gender: gender || null,
      address: address || null,
      updated_at: new Date().toISOString(),
    })

    if (profileError) {
      const rollbackError = await rollbackAuthUser(supabase, userId)
      const message = rollbackError
        ? `Profile error: ${profileError.message}. Additionally, cleanup failed (${rollbackError}) - auth user ${userId} is now orphaned and must be deleted manually from Supabase Authentication before this phone/email can be reused.`
        : `Profile error: ${profileError.message}`
      return new Response(JSON.stringify({ error: message }), { status: 500, headers: corsHeaders })
    }

    // Insert subscription - pass_price is snapshotted from `pass.price` right
    // now, in the same insert as everything else, so there is no window
    // where this row could be left with pass_price = NULL (which would
    // silently zero this member's charge in every ledger/report forever).
    const { error: subError } = await supabase.from('subscriptions').insert({
      user_id: userId,
      pass_id,
      status: 'active',
      start_date,
      end_date,
      entry_date: entry_date || start_date,
      pass_price: pass.price,
      discount_amount: Number(discount_amount) > 0 ? Number(discount_amount) : 0,
    })

    if (subError) {
      const rollbackError = await rollbackAuthUser(supabase, userId)
      const message = rollbackError
        ? `Subscription error: ${subError.message}. Additionally, cleanup failed (${rollbackError}) - auth user ${userId} is now orphaned and must be deleted manually from Supabase Authentication before this phone/email can be reused.`
        : `Subscription error: ${subError.message}`
      return new Response(JSON.stringify({ error: message }), { status: 500, headers: corsHeaders })
    }

    return new Response(
      JSON.stringify({
        success: true,
        user_id: userId,
        email: memberEmail,
        temp_password: tempPassword,
        end_date,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    console.error('Unhandled error:', e)
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: corsHeaders,
    })
  }
})
