import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

// Next.js 16: cookies() is fully async, so this factory must be awaited
// wherever it's called from a Server Component, Route Handler, or Server Action.
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // Called from a Server Component during render — safe to ignore
            // since the proxy (middleware) is responsible for refreshing sessions.
          }
        },
      },
    },
  );
}
