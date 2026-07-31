import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { SubscriptionsList, type SubscriptionRow } from "@/components/admin/subscriptions-list";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Subscriptions — Vishal Fitness Admin",
};

export default async function SubscriptionsPage() {
  const supabase = await createClient();

  const [subsRes, paymentsRes, passesRes] = await Promise.all([
    supabase
      .from("subscriptions")
      .select(
        `id, start_date, end_date, status, user_id, discount_amount, pass_id,
         profiles:user_id ( full_name, phone, photo_url, time_slot ),
         gym_passes:pass_id ( name, duration_days, price )`,
      )
      .order("end_date", { ascending: true })
      .returns<Omit<SubscriptionRow, "paid">[]>(),
    supabase.from("payments").select("subscription_id, amount"),
    supabase.from("gym_passes").select("id, name, price, duration_days").eq("is_active", true).order("duration_days", { ascending: true }),
  ]);

  const paidMap = new Map<string, number>();
  for (const p of paymentsRes.data ?? []) {
    paidMap.set(p.subscription_id, (paidMap.get(p.subscription_id) ?? 0) + (p.amount ?? 0));
  }

  const subscriptions: SubscriptionRow[] = (subsRes.data ?? []).map((s) => ({
    ...s,
    paid: paidMap.get(s.id) ?? 0,
  }));

  const nowMs = new Date().getTime();

  return (
    <div>
      <div className="mb-6 flex items-center gap-3">
        <Link href="/admin" className="grid size-9 place-items-center rounded-xl border border-border bg-card" aria-label="Back">
          <ArrowLeft className="size-4" />
        </Link>
        <h1 className="font-display text-[26px] font-bold leading-none">Subscriptions</h1>
      </div>

      <SubscriptionsList subscriptions={subscriptions} passes={passesRes.data ?? []} nowMs={nowMs} />
    </div>
  );
}
