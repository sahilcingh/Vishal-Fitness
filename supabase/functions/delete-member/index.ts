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
    const { user_id } = await req.json()

    if (!user_id) {
      return new Response(JSON.stringify({ error: 'user_id is required' }), {
        status: 400,
        headers: corsHeaders,
      })
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // A true, permanent delete - every trace of this member. Cleared
    // explicitly table-by-table (child tables first) rather than relying on
    // whatever foreign-key cascade behavior may or may not be configured -
    // this way the result is the same regardless. Order matters: payments
    // and member_events reference subscriptions, so they're cleared first.
    const tablesToClear = ['member_events', 'payments', 'check_ins', 'subscriptions']
    for (const table of tablesToClear) {
      const { error } = await supabase.from(table).delete().eq('user_id', user_id)
      if (error) {
        return new Response(
          JSON.stringify({ error: `Failed clearing ${table}: ${error.message}. Nothing further was deleted.` }),
          { status: 500, headers: corsHeaders },
        )
      }
    }

    // Best-effort: remove their uploaded photo too. Doesn't block the rest
    // of the deletion if this fails - a leftover file in storage is a much
    // smaller problem than stopping a delete the admin already confirmed.
    try {
      const { data: files } = await supabase.storage.from('member-photos').list(user_id)
      if (files && files.length > 0) {
        await supabase.storage.from('member-photos').remove(files.map((f) => `${user_id}/${f.name}`))
      }
    } catch (storageErr) {
      console.error('delete-member: storage cleanup failed (continuing):', storageErr)
    }

    const { error: profileError } = await supabase.from('profiles').delete().eq('id', user_id)
    if (profileError) {
      return new Response(
        JSON.stringify({ error: `Their history was cleared, but deleting the profile failed (${profileError.message}) - the login account was NOT removed either.` }),
        { status: 500, headers: corsHeaders },
      )
    }

    // Auth account last - once nothing else references it.
    const { error: authError } = await supabase.auth.admin.deleteUser(user_id)
    if (authError) {
      return new Response(
        JSON.stringify({
          error: `Their profile and history were deleted, but removing the login account failed (${authError.message}) - auth user ${user_id} must be deleted manually from Supabase Authentication.`,
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
