import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!

// ─── Firebase HTTP v1 auth helpers ────────────────────────────────────────────

function pemToDer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s/g, '')
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes.buffer
}

function base64url(data: ArrayBuffer | Uint8Array): string {
  const bytes = data instanceof Uint8Array ? data : new Uint8Array(data)
  let str = ''
  for (const b of bytes) str += String.fromCharCode(b)
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

async function getFcmAccessToken(sa: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const enc = new TextEncoder()

  const headerB64 = base64url(enc.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })))
  const payloadB64 = base64url(enc.encode(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })))

  const signingInput = `${headerB64}.${payloadB64}`

  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    enc.encode(signingInput),
  )

  const jwt = `${signingInput}.${base64url(signature)}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  const { access_token } = await res.json()
  return access_token as string
}

// ─── Main handler ─────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  try {
    const body = await req.json()
    // Supabase webhook sends { type, table, record, old_record }
    const record = body.record as Record<string, unknown>

    const title = record.title as string
    const message = record.message as string
    const isActive = record.is_active as boolean

    // Skip notifications for drafts (is_active = false)
    if (!isActive) {
      return new Response(JSON.stringify({ sent: 0, reason: 'inactive' }), { status: 200 })
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const { data: tokenRows, error } = await supabase
      .from('device_tokens')
      .select('token')

    if (error) {
      console.error('device_tokens fetch error:', error.message)
      return new Response(JSON.stringify({ error: error.message }), { status: 500 })
    }

    if (!tokenRows?.length) {
      return new Response(JSON.stringify({ sent: 0, reason: 'no_tokens' }), { status: 200 })
    }

    const sa = JSON.parse(serviceAccountJson) as Record<string, string>
    const accessToken = await getFcmAccessToken(sa)
    const projectId = sa.project_id

    let sent = 0
    const staleTokens: string[] = []

    await Promise.all(
      tokenRows.map(async ({ token }: { token: string }) => {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              message: {
                token,
                notification: { title, body: message },
                android: {
                  notification: {
                    channel_id: 'announcements',
                    priority: 'high',
                  },
                },
                apns: {
                  payload: { aps: { sound: 'default', badge: 1 } },
                },
              },
            }),
          },
        )

        if (res.ok) {
          sent++
        } else {
          const err = await res.json()
          // UNREGISTERED / INVALID_ARGUMENT = stale token, clean it up
          const code = err?.error?.details?.[0]?.errorCode ?? ''
          if (code === 'UNREGISTERED' || code === 'INVALID_ARGUMENT') {
            staleTokens.push(token)
          }
          console.error(`FCM error for token ${token.slice(-8)}:`, JSON.stringify(err))
        }
      }),
    )

    // Remove stale tokens so they don't accumulate
    if (staleTokens.length) {
      await supabase.from('device_tokens').delete().in('token', staleTokens)
    }

    return new Response(
      JSON.stringify({ sent, total: tokenRows.length, stale_removed: staleTokens.length }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    console.error('Unhandled error:', e)
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 })
  }
})
