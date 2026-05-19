import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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
    const { name, phone, email, gender, pass_id, start_date } = await req.json()

    if (!name || !phone || !pass_id || !start_date) {
      return new Response(
        JSON.stringify({ error: 'name, phone, pass_id and start_date are required' }),
        { status: 400, headers: corsHeaders },
      )
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Fetch pass to compute end_date
    const { data: pass, error: passError } = await supabase
      .from('gym_passes')
      .select('duration_days')
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
    end.setDate(end.getDate() + (pass.duration_days as number))
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
      updated_at: new Date().toISOString(),
    })

    if (profileError) {
      await supabase.auth.admin.deleteUser(userId)
      return new Response(
        JSON.stringify({ error: `Profile error: ${profileError.message}` }),
        { status: 500, headers: corsHeaders },
      )
    }

    // Insert subscription
    const { error: subError } = await supabase.from('subscriptions').insert({
      user_id: userId,
      pass_id,
      status: 'active',
      start_date,
      end_date,
    })

    if (subError) {
      await supabase.auth.admin.deleteUser(userId)
      return new Response(
        JSON.stringify({ error: `Subscription error: ${subError.message}` }),
        { status: 500, headers: corsHeaders },
      )
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
