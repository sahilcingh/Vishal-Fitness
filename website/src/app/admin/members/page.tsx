import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { MembersDirectory, type MemberRow } from "@/components/admin/members-directory";
import { MembersExportButton } from "@/components/admin/members-export-button";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Trial Balance / Ledger - Vishal Fitness Admin",
};

type SubBalanceRow = { user_id: string; discount_amount: number | null; gym_passes: { price: number | null } | null };
type PaymentBalanceRow = { user_id: string; amount: number };

export default async function MembersLedgerPage() {
  const supabase = await createClient();

  const [profilesRes, subsRes, paymentsRes] = await Promise.all([
    supabase
      .from("profiles")
      .select("id, full_name, phone, photo_url, created_at")
      .neq("role", "admin")
      .order("full_name", { ascending: true })
      .returns<Omit<MemberRow, "balance">[]>(),
    supabase.from("subscriptions").select("user_id, discount_amount, gym_passes:pass_id ( price )").returns<SubBalanceRow[]>(),
    supabase.from("payments").select("user_id, amount").returns<PaymentBalanceRow[]>(),
  ]);

  // Same Debit (charge) / Credit (payment) math as the individual member
  // ledger, aggregated per member so the directory can show at a glance who
  // still owes money vs. who's overpaid.
  const balanceByUser = new Map<string, number>();
  for (const s of subsRes.data ?? []) {
    const fee = s.gym_passes?.price ?? 0;
    const discount = s.discount_amount ?? 0;
    const netPayable = Math.max(fee - discount, 0);
    balanceByUser.set(s.user_id, (balanceByUser.get(s.user_id) ?? 0) + netPayable);
  }
  for (const p of paymentsRes.data ?? []) {
    balanceByUser.set(p.user_id, (balanceByUser.get(p.user_id) ?? 0) - (p.amount ?? 0));
  }

  const members: MemberRow[] = (profilesRes.data ?? []).map((m) => ({ ...m, balance: balanceByUser.get(m.id) ?? 0 }));

  return (
    <div>
      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-display text-[26px] font-bold leading-none">
            Trial Balance <span className="text-muted-foreground">/ Ledger</span>
          </h1>
          <p className="mt-1.5 text-[13px] text-muted-foreground">
            Search any member to see their full history - membership, payments, visits, and changes.
          </p>
        </div>
        <MembersExportButton members={members} />
      </div>
      <MembersDirectory members={members} />
    </div>
  );
}
