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
    const { user_id, new_email } = await req.json()

    if (!user_id) {
      return new Response(JSON.stringify({ error: 'user_id is required' }), {
        status: 400,
        headers: corsHeaders,
      })
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Email-change mode: admin-initiated, skips OTP entirely via email_confirm.
    if (new_email) {
      const { error: emailError } = await supabase.auth.admin.updateUserById(user_id, {
        email: new_email,
        email_confirm: true,
      })
      if (emailError) {
        return new Response(JSON.stringify({ error: emailError.message }), {
          status: 400,
          headers: corsHeaders,
        })
      }
      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Password-reset mode: generate a new temp password, same format as create-member.
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789'
    let tempPassword = 'VF-'
    for (let i = 0; i < 7; i++) {
      tempPassword += chars[Math.floor(Math.random() * chars.length)]
    }

    const { error: authError } = await supabase.auth.admin.updateUserById(user_id, {
      password: tempPassword,
    })
    if (authError) {
      return new Response(JSON.stringify({ error: authError.message }), {
        status: 400,
        headers: corsHeaders,
      })
    }

    // Force the member through the change-password flow on next login, same
    // as newly-created members via create-member.
    const { error: profileError } = await supabase
      .from('profiles')
      .update({ needs_password_reset: true, updated_at: new Date().toISOString() })
      .eq('id', user_id)
    if (profileError) {
      return new Response(JSON.stringify({ error: profileError.message }), {
        status: 500,
        headers: corsHeaders,
      })
    }

    return new Response(
      JSON.stringify({ success: true, temp_password: tempPassword }),
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
