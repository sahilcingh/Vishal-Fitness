import type { createClient } from "@/lib/supabase/client";

export type MemberEventType =
  | "status_change"
  | "discount_change"
  | "subscription_edit"
  | "profile_edit"
  | "payment_edit"
  | "payment_delete";

// Logs an entry for the member ledger (src/app/admin/members/[id]/page.tsx).
// check_ins keeps full history on its own (insert-only); this covers the
// mutations that overwrite or remove data in place with no history of their
// own otherwise - status, discount, profile/subscription edits, and direct
// payment edits/deletes (payments are otherwise insert-only too, but once a
// payment can be corrected or removed after the fact, that correction needs
// its own trail or it becomes invisible).
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
