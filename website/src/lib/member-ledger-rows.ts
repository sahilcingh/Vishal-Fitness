import type { LedgerRow } from "@/components/admin/member-ledger";

export type LedgerSubscription = {
  id: string;
  start_date: string;
  end_date: string;
  entry_date: string;
  pass_price: number | null;
  discount_amount: number | null;
  gym_passes: { name: string | null } | null;
};

export type LedgerPayment = {
  amount: number;
  payment_method: string | null;
  payment_date: string;
  notes: string | null;
  subscription_id: string | null;
};

// Supabase returns `date` columns as bare "YYYY-MM-DD" but `timestamp`/
// `timestamptz` columns as a full ISO string - normalize to the first 10
// chars before parsing via explicit y/m/d components (not
// `new Date("YYYY-MM-DD")`, which the spec parses as UTC midnight and a
// negative-UTC-offset viewer could render a day early).
function prettyYMD(dateStr: string) {
  const [y, m, d] = dateStr.slice(0, 10).split("-").map(Number);
  return new Date(y, m - 1, d).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
}

function dayKeyOf(dateStr: string) {
  return dateStr.slice(0, 10);
}

// A real accounting-style ledger: every membership charge is a Debit (what
// they now owe), every discount and payment is a Credit (what reduces that),
// and Balance is the running amount still owed - one continuous account
// across the member's whole history, not reset per subscription. Sorted
// oldest-first, like a bank statement.
export function buildLedgerRows(subscriptions: LedgerSubscription[], payments: LedgerPayment[]): LedgerRow[] {
  const passNameBySub = new Map(subscriptions.map((s) => [s.id, s.gym_passes?.name ?? "Pass"]));

  type UnsortedRow = { date: string; description: string; debit: number; credit: number };
  const unsortedRows: UnsortedRow[] = [];

  subscriptions.forEach((s, i) => {
    const fee = s.pass_price ?? 0;
    const discount = s.discount_amount ?? 0;
    const passName = s.gym_passes?.name ?? "Pass";
    unsortedRows.push({
      date: s.entry_date,
      description: `${i === 0 ? "Subscribed to" : "Renewed to"} ${passName} (${prettyYMD(s.start_date)} → ${prettyYMD(s.end_date)})`,
      debit: fee,
      credit: 0,
    });
    if (discount > 0) {
      unsortedRows.push({ date: s.entry_date, description: `Discount applied - ${passName}`, debit: 0, credit: discount });
    }
  });

  payments.forEach((p) => {
    const passName = p.subscription_id ? passNameBySub.get(p.subscription_id) : null;
    const method = (p.payment_method ?? "").toUpperCase();
    const label = [`Payment received${method ? ` - ${method}` : ""}`, passName ? `(${passName})` : null, p.notes ? `- ${p.notes}` : null]
      .filter(Boolean)
      .join(" ");
    unsortedRows.push({ date: p.payment_date, description: label, debit: 0, credit: p.amount ?? 0 });
  });

  // Compare by calendar day first, not the raw string - entry_date and
  // payment_date are both plain dates, but a genuine same-day tie should
  // still show the charge before the payment that settles it (the natural
  // reading order), rather than an arbitrary string-comparison artifact.
  unsortedRows.sort((a, b) => {
    const dayCompare = dayKeyOf(a.date).localeCompare(dayKeyOf(b.date));
    if (dayCompare !== 0) return dayCompare;
    const aIsCharge = a.debit > 0 ? 0 : 1;
    const bIsCharge = b.debit > 0 ? 0 : 1;
    if (aIsCharge !== bIsCharge) return aIsCharge - bIsCharge;
    return a.date.localeCompare(b.date);
  });

  return unsortedRows.reduce<LedgerRow[]>((rows, r, i) => {
    const prevBalance = rows.length > 0 ? rows[rows.length - 1].balance : 0;
    const balance = prevBalance + r.debit - r.credit;
    return [...rows, { id: `row-${i}`, date: r.date, description: r.description, debit: r.debit, credit: r.credit, balance }];
  }, []);
}
