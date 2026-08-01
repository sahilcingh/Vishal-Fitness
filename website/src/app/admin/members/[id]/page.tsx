import type { Metadata } from "next";
import Image from "next/image";
import { notFound } from "next/navigation";
import { User } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { formatINR } from "@/lib/format";
import { initials } from "@/lib/utils";
import { MemberDetailTables, type LedgerRow } from "@/components/admin/member-ledger";
import { BackButton } from "@/components/admin/back-button";

export const dynamic = "force-dynamic";

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params;
  return { title: `Member Ledger - Vishal Fitness Admin`, description: id };
}

function membershipNo(userId: string) {
  return `MBR-${userId.replace(/-/g, "").slice(0, 6).toUpperCase()}`;
}

// Supabase returns `date` columns as bare "YYYY-MM-DD" but `timestamp`/
// `timestamptz` columns as a full ISO string - normalize to the first 10
// chars before parsing via explicit y/m/d components (not
// `new Date("YYYY-MM-DD")`, which the spec parses as UTC midnight and a
// negative-UTC-offset viewer could render a day early). Matches the
// normalizeYMD pattern used elsewhere in this app for the same reason.
function prettyYMD(dateStr: string) {
  const [y, m, d] = dateStr.slice(0, 10).split("-").map(Number);
  return new Date(y, m - 1, d).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
}

function dayKeyOf(dateStr: string) {
  return dateStr.slice(0, 10);
}

type ProfileRow = {
  id: string;
  full_name: string | null;
  phone: string | null;
  photo_url: string | null;
  created_at: string;
};

type SubRow = {
  id: string;
  pass_id: string | null;
  start_date: string;
  end_date: string;
  status: string;
  discount_amount: number | null;
  created_at: string;
  gym_passes: { name: string | null; price: number | null; duration_days: number | null } | null;
};

type PaymentRow = {
  id: string;
  amount: number;
  payment_method: string | null;
  payment_date: string;
  notes: string | null;
  subscription_id: string | null;
};

export default async function MemberLedgerPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, full_name, phone, photo_url, created_at")
    .eq("id", id)
    .maybeSingle<ProfileRow>();
  if (!profile) notFound();

  const [subsRes, paymentsRes, checkInsCountRes] = await Promise.all([
    supabase
      .from("subscriptions")
      .select("id, pass_id, start_date, end_date, status, discount_amount, created_at, gym_passes:pass_id ( name, price, duration_days )")
      .eq("user_id", id)
      .order("created_at", { ascending: true })
      .returns<SubRow[]>(),
    supabase
      .from("payments")
      .select("id, amount, payment_method, payment_date, notes, subscription_id")
      .eq("user_id", id)
      .order("payment_date", { ascending: true })
      .returns<PaymentRow[]>(),
    supabase.from("check_ins").select("id", { count: "exact", head: true }).eq("user_id", id),
  ]);

  const subscriptions = subsRes.data ?? [];
  const payments = paymentsRes.data ?? [];
  const totalVisits = checkInsCountRes.count ?? 0;

  // A real accounting-style ledger: every membership charge is a Debit
  // (what they now owe), every discount and payment is a Credit (what
  // reduces that), and Balance is the running amount still owed - one
  // continuous account across the member's whole history, not reset per
  // subscription. Sorted oldest-first, like a bank statement.
  const passNameBySub = new Map(subscriptions.map((s) => [s.id, s.gym_passes?.name ?? "Pass"]));

  type UnsortedRow = { date: string; description: string; debit: number; credit: number };
  const unsortedRows: UnsortedRow[] = [];

  subscriptions.forEach((s, i) => {
    const fee = s.gym_passes?.price ?? 0;
    const discount = s.discount_amount ?? 0;
    const passName = s.gym_passes?.name ?? "Pass";
    unsortedRows.push({
      date: s.created_at,
      description: `${i === 0 ? "Subscribed to" : "Renewed to"} ${passName} (${prettyYMD(s.start_date)} → ${prettyYMD(s.end_date)})`,
      debit: fee,
      credit: 0,
    });
    if (discount > 0) {
      unsortedRows.push({ date: s.created_at, description: `Discount applied - ${passName}`, debit: 0, credit: discount });
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

  // Compare by calendar day first, not the raw string - subscriptions.created_at
  // is a full timestamp while payments.payment_date is date-only, and comparing
  // those as plain strings would sort the shorter date-only string before a
  // same-day timestamp regardless of real order. On a genuine same-day tie,
  // show the charge before the payment that settles it (the natural reading
  // order), rather than an arbitrary string-comparison artifact.
  unsortedRows.sort((a, b) => {
    const dayCompare = dayKeyOf(a.date).localeCompare(dayKeyOf(b.date));
    if (dayCompare !== 0) return dayCompare;
    const aIsCharge = a.debit > 0 ? 0 : 1;
    const bIsCharge = b.debit > 0 ? 0 : 1;
    if (aIsCharge !== bIsCharge) return aIsCharge - bIsCharge;
    return a.date.localeCompare(b.date);
  });

  let runningBalance = 0;
  const ledgerRows: LedgerRow[] = unsortedRows.map((r, i) => {
    runningBalance += r.debit - r.credit;
    return { id: `row-${i}`, date: r.date, description: r.description, debit: r.debit, credit: r.credit, balance: runningBalance };
  });

  const totalPaid = payments.reduce((sum, p) => sum + (p.amount ?? 0), 0);
  const latestSub = [...subscriptions].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())[0];
  const currentStatus = latestSub ? latestSub.status.charAt(0).toUpperCase() + latestSub.status.slice(1) : "No subscription";

  const name = profile.full_name ?? "Member";

  return (
    <div>
      <div className="mb-6 flex items-center gap-3">
        <BackButton fallbackHref="/admin/members" />
        <span className="grid size-12 shrink-0 place-items-center overflow-hidden rounded-full border border-border bg-brand/12 text-[15px] font-bold text-brand">
          {profile.photo_url ? (
            <Image src={profile.photo_url} alt="" width={48} height={48} className="size-full object-cover" />
          ) : (
            initials(name)
          )}
        </span>
        <div className="min-w-0">
          <h1 className="truncate font-display text-[22px] font-bold leading-tight">{name}</h1>
          <div className="flex flex-wrap items-center gap-1.5 text-[12px] text-muted-foreground">
            <span className="rounded bg-brand/8 px-1.5 py-0.5 text-[10px] font-bold text-brand">{membershipNo(id)}</span>
            {profile.phone && <span>{profile.phone}</span>}
          </div>
        </div>
      </div>

      <div className="mb-5 grid grid-cols-2 gap-3.5 sm:grid-cols-4">
        <StatTile label="Member Since" value={new Date(profile.created_at).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" })} />
        <StatTile label="Total Paid" value={formatINR(totalPaid)} valueClass="text-brand" />
        <StatTile label="Visits" value={String(totalVisits)} />
        <StatTile label="Status" value={currentStatus} />
      </div>

      {ledgerRows.length === 0 ? (
        <div className="flex flex-col items-center gap-3 rounded-[20px] border border-border bg-card px-6 py-16 text-center">
          <User className="size-9 text-muted-foreground" />
          <p className="text-[13px] text-muted-foreground">No activity recorded for this member yet.</p>
        </div>
      ) : (
        <MemberDetailTables rows={ledgerRows} openingDate={profile.created_at} />
      )}
    </div>
  );
}

function StatTile({ label, value, valueClass }: { label: string; value: string; valueClass?: string }) {
  return (
    <div className="rounded-[20px] border border-border bg-card p-4">
      <div className="text-[10px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">{label}</div>
      <div className={`num mt-2 font-display text-[18px] font-bold ${valueClass ?? ""}`}>{value}</div>
    </div>
  );
}
