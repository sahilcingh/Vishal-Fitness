import type { createClient } from "@/lib/supabase/client";

export type MemberProfileDetail = {
  full_name: string | null;
  phone: string | null;
  gender: string | null;
  address: string | null;
  time_slot: string | null;
  photo_url: string | null;
  created_at: string;
};

export type MemberSubscriptionDetail = {
  id: string;
  pass_id: string | null;
  status: string;
  start_date: string;
  end_date: string;
  created_at: string;
  discount_amount: number | null;
  gym_passes: { name: string | null; price: number | null; duration_days: number | null } | null;
};

export type MemberPaymentDetail = {
  amount: number;
  payment_method: string | null;
  payment_date: string;
  notes: string | null;
  subscription_id: string | null;
};

// Everything needed to render a member's full picture in one place: profile
// fields, every subscription (not just the active/latest one), and every
// payment. The subscriptions shape is a superset of what buildLedgerRows
// needs, so the same array can drive both a subscriptions list and the
// ledger table without a second query or a conversion step.
export async function fetchMemberDetail(supabase: ReturnType<typeof createClient>, userId: string) {
  const [{ data: profile }, { data: subscriptions }, { data: payments }] = await Promise.all([
    supabase
      .from("profiles")
      .select("full_name, phone, gender, address, time_slot, photo_url, created_at")
      .eq("id", userId)
      .maybeSingle<MemberProfileDetail>(),
    supabase
      .from("subscriptions")
      .select("id, pass_id, status, start_date, end_date, created_at, discount_amount, gym_passes:pass_id ( name, price, duration_days )")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .returns<MemberSubscriptionDetail[]>(),
    supabase
      .from("payments")
      .select("amount, payment_method, payment_date, notes, subscription_id")
      .eq("user_id", userId)
      .order("payment_date", { ascending: false })
      .returns<MemberPaymentDetail[]>(),
  ]);

  return {
    profile: profile ?? null,
    subscriptions: subscriptions ?? [],
    payments: payments ?? [],
  };
}
