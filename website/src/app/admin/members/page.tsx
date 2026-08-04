import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { MembersDirectory, type MemberRow } from "@/components/admin/members-directory";
import { MembersExportButton } from "@/components/admin/members-export-button";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Trial Balance / Ledger - Vishal Fitness Admin",
};

type SubBalanceRow = { user_id: string; discount_amount: number | null; pass_price: number | null };
type PaymentBalanceRow = { user_id: string; amount: number };

export default async function MembersLedgerPage() {
  const supabase = await createClient();

  const [profilesRes, subsRes, paymentsRes] = await Promise.all([
    supabase
      .from("profiles")
      .select("id, full_name, phone, photo_url, created_at")
      .neq("role", "admin")
      .is("archived_at", null)
      .order("full_name", { ascending: true })
      .returns<Omit<MemberRow, "balance">[]>(),
    supabase.from("subscriptions").select("user_id, discount_amount, pass_price").returns<SubBalanceRow[]>(),
    supabase.from("payments").select("user_id, amount").returns<PaymentBalanceRow[]>(),
  ]);

  // Same Debit (charge) / Credit (discount + payment) convention as the
  // individual member's own ledger (member-ledger-rows.ts): a subscription's
  // full pass_price is the Debit, and any discount is its own Credit-side
  // line rather than being netted into the Debit - otherwise this directory's
  // gross totals wouldn't reconcile with a member's own "Closing Balance" row.
  const debitByUser = new Map<string, number>();
  const creditByUser = new Map<string, number>();
  for (const s of subsRes.data ?? []) {
    const fee = s.pass_price ?? 0;
    const discount = s.discount_amount ?? 0;
    debitByUser.set(s.user_id, (debitByUser.get(s.user_id) ?? 0) + fee);
    if (discount > 0) {
      creditByUser.set(s.user_id, (creditByUser.get(s.user_id) ?? 0) + discount);
    }
  }
  for (const p of paymentsRes.data ?? []) {
    creditByUser.set(p.user_id, (creditByUser.get(p.user_id) ?? 0) + (p.amount ?? 0));
  }

  const members: MemberRow[] = (profilesRes.data ?? []).map((m) => {
    const debit = debitByUser.get(m.id) ?? 0;
    const credit = creditByUser.get(m.id) ?? 0;
    return { ...m, debit, credit, balance: debit - credit };
  });

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
