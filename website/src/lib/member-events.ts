import type { createClient } from "@/lib/supabase/client";

export type MemberEventType = "status_change" | "discount_change" | "subscription_edit" | "profile_edit";

// Logs an entry for the member ledger (src/app/admin/members/[id]/page.tsx).
// subscriptions/payments/check_ins already keep full history on their own
// (insert-only); this only covers the mutations that overwrite data in
// place with no history - status, discount, and profile/subscription edits.
// Best-effort: a logging failure must never block or surface as an error
// for the mutation it's describing, which has already succeeded by the time
// this is called.
export async function logMemberEvent(
  supabase: ReturnType<typeof createClient>,
  params: { userId: string; subscriptionId?: string | null; eventType: MemberEventType; description: string },
) {
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser();
    const { error } = await supabase.from("member_events").insert({
      user_id: params.userId,
      subscription_id: params.subscriptionId ?? null,
      event_type: params.eventType,
      description: params.description,
      created_by: user?.id ?? null,
    });
    if (error) console.error("logMemberEvent: insert failed:", error);
  } catch (err) {
    console.error("logMemberEvent: threw:", err);
  }
}
