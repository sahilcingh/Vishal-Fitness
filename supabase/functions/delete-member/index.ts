import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// This function permanently deletes a member's entire record with the
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
    const { user_id } = await req.json()

    if (!user_id) {
      return new Response(JSON.stringify({ error: 'user_id is required' }), {
        status: 400,
        headers: corsHeaders,
      })
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const adminCheck = await requireAdmin(req, supabase)
    if (adminCheck) return adminCheck

    // Soft delete only: archive the profile and revoke login. Their
    // subscriptions/payments/check_ins/member_events are deliberately left
    // untouched - hard-deleting them would retroactively change past
    // Daily Revenue/Overview totals for whatever months their payments
    // fell in, which is exactly what `archived_at` exists to avoid.
    const { error: profileError } = await supabase
      .from('profiles')
      .update({ archived_at: new Date().toISOString() })
      .eq('id', user_id)
    if (profileError) {
      return new Response(
        JSON.stringify({ error: `Failed to archive the member: ${profileError.message}. Nothing was changed.` }),
        { status: 500, headers: corsHeaders },
      )
    }

    // Revoke login without deleting the auth account, so their id keeps
    // pointing at real history instead of becoming an orphaned reference.
    const { error: authError } = await supabase.auth.admin.updateUserById(user_id, { ban_duration: '876000h' })
    if (authError) {
      return new Response(
        JSON.stringify({
          error: `The member was archived, but revoking their login failed (${authError.message}) - they may still be able to sign in.`,
        }),
        { status: 500, headers: corsHeaders },
      )
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error('Unhandled error:', e)
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: corsHeaders,
    })
  }
})
