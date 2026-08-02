import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ChevronLeft, ChevronRight, AlertTriangle } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { nowInIST } from "@/lib/ist-time";
import { DailyRevenueExportButton } from "@/components/admin/daily-revenue-export-button";
import { DayActivityTable, type DayActivityRow } from "@/components/admin/day-activity-table";
import { CountUp } from "@/components/count-up";

export const dynamic = "force-dynamic";

export async function generateMetadata({ params }: { params: Promise<{ day: string }> }): Promise<Metadata> {
  const { day } = await params;
  return { title: `${day} Revenue - Vishal Fitness Admin` };
}

// Mirrors _safe() elsewhere in admin/ - but unlike that helper, callers here
// also feed an official CSV export, so a swallowed error must not render
// identically to a genuine zero-revenue day; `hadError` lets callers show a
// warning instead of silently trusting `data`.
async function safeSelect<T>(promise: PromiseLike<{ data: T[] | null; error: unknown }>) {
  try {
    const { data, error } = await promise;
    if (error) {
      console.error("daily-revenue/[day]/page: query failed:", error);
      return { data: [] as T[], hadError: true };
    }
    return { data: data ?? ([] as T[]), hadError: false };
  } catch (err) {
    console.error("daily-revenue/[day]/page: query threw:", err);
    return { data: [] as T[], hadError: true };
  }
}

function dayKey(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
function isValidYMD(s: string) {
  return /^\d{4}-\d{2}-\d{2}$/.test(s);
}
function parseYMD(s: string) {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}
function isSameDay(a: Date, b: Date) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

type PaymentRow = {
  amount: number;
  payment_method: string | null;
  subscription_id: string | null;
  subscriptions: {
    discount_amount: number | null;
    pass_price: number | null;
    profiles: { full_name: string | null; phone: string | null } | null;
    gym_passes: { name: string | null } | null;
  } | null;
};

type NewMemberRow = {
  id: string;
  entry_date: string;
  pass_price: number | null;
  profiles: { full_name: string | null; phone: string | null } | null;
  gym_passes: { name: string | null } | null;
};

export default async function DailyRevenueDayPage({ params }: { params: Promise<{ day: string }> }) {
  const { day: dayParam } = await params;
  if (!isValidYMD(dayParam)) notFound();

  const supabase = await createClient();
  const now = nowInIST();
  const day = parseYMD(dayParam);
  const dayStr = dayKey(day);
  const isToday = isSameDay(day, now);

  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  const dayLabel = isToday
    ? "Today"
    : isSameDay(day, yesterday)
      ? "Yesterday"
      : day.toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long" });
  const dayHeading = day.toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long" });

  const prevDay = new Date(day);
  prevDay.setDate(prevDay.getDate() - 1);
  const nextDay = new Date(day);
  nextDay.setDate(nextDay.getDate() + 1);

  const [{ data: payRows, hadError: payRowsErrored }, { data: newMembers, hadError: newMembersErrored }] = await Promise.all([
    safeSelect(
      supabase
        .from("payments")
        .select(
          `amount, payment_method, subscription_id,
           subscriptions:subscription_id (
             discount_amount,
             pass_price,
             profiles:user_id ( full_name, phone ),
             gym_passes:pass_id ( name )
           )`,
        )
        .eq("payment_date", dayStr)
        .order("created_at")
        .returns<PaymentRow[]>(),
    ),
    safeSelect(
      supabase
        .from("subscriptions")
        .select(`id, entry_date, pass_price, profiles:user_id ( full_name, phone ), gym_passes:pass_id ( name )`)
        .eq("entry_date", dayStr)
        .order("entry_date")
        .returns<NewMemberRow[]>(),
    ),
  ]);

  const subscriptionIds = [...new Set(payRows.map((r) => r.subscription_id).filter((id): id is string => !!id))];

  const paidToDate = new Map<string, number>();
  let totalsErrored = false;
  if (subscriptionIds.length > 0) {
    const { data: totals, hadError } = await safeSelect<{ subscription_id: string; amount: number }>(
      supabase.from("payments").select("subscription_id, amount").in("subscription_id", subscriptionIds),
    );
    totalsErrored = hadError;
    for (const t of totals) {
      paidToDate.set(t.subscription_id, (paidToDate.get(t.subscription_id) ?? 0) + (t.amount ?? 0));
    }
  }

  const hadDataError = payRowsErrored || totalsErrored;
  const newMemberSubIds = new Set(newMembers.map((m) => m.id));

  const paymentActivityRows: DayActivityRow[] = payRows.map((r, i) => {
    const sub = r.subscriptions;
    const price = sub?.pass_price ?? 0;
    const discount = sub?.discount_amount ?? 0;
    const effectiveFee = Math.max(price - discount, 0);
    const balance = Math.max(effectiveFee - (paidToDate.get(r.subscription_id ?? "") ?? 0), 0);
    return {
      key: `pay-${i}`,
      name: sub?.profiles?.full_name ?? "Member",
      phone: sub?.profiles?.phone ?? "",
      passType: sub?.gym_passes?.name ?? "Pass",
      paymentMethod: (r.payment_method ?? "").toUpperCase(),
      packageAmount: price,
      discount,
      paidAmount: r.amount ?? 0,
      balanceAmount: balance,
      isNewMember: newMemberSubIds.has(r.subscription_id ?? ""),
    };
  });

  // New members who joined this day but have no payment row yet (e.g. a
  // signup recorded ahead of the first payment) - shown so the table doesn't
  // silently drop them.
  const coveredSubIds = new Set(payRows.map((r) => r.subscription_id).filter((id): id is string => !!id));
  const unpaidNewMemberRows: DayActivityRow[] = newMembers
    .filter((m) => !coveredSubIds.has(m.id))
    .map((m) => ({
      key: `new-${m.id}`,
      name: m.profiles?.full_name ?? "Member",
      phone: m.profiles?.phone ?? "",
      passType: m.gym_passes?.name ?? "Pass",
      paymentMethod: "",
      packageAmount: m.pass_price ?? 0,
      discount: 0,
      paidAmount: 0,
      balanceAmount: m.pass_price ?? 0,
      isNewMember: true,
    }));

  const activityRows: DayActivityRow[] = [...paymentActivityRows, ...unpaidNewMemberRows];

  // CSV export stays payment-only (it's a revenue/reconciliation document) -
  // derived from the same payment rows the table uses, just without the
  // table-only `key`/`isNewMember` fields.
  const txns = paymentActivityRows.map((r) => ({
    name: r.name,
    phone: r.phone,
    passType: r.passType,
    packageAmount: r.packageAmount,
    discount: r.discount,
    paymentMethod: r.paymentMethod,
    paidAmount: r.paidAmount,
    balanceAmount: r.balanceAmount,
  }));

  const totalRevenue = txns.reduce((sum, t) => sum + t.paidAmount, 0);
  const dateStr = day.toLocaleDateString("en-GB").split("/").join("/"); // dd/mm/yyyy

  return (
    <div>
      {(hadDataError || newMembersErrored) && (
        <div className="mb-5 flex items-center gap-3 rounded-xl border border-danger/30 bg-danger/10 px-4 py-3 text-[13px] text-danger">
          <AlertTriangle className="size-4 shrink-0" />
          <span className="flex-1">Couldn&apos;t load some data for this day - figures below may be incomplete.</span>
          <a href={`/admin/daily-revenue/${dayStr}`} className="shrink-0 font-bold underline">
            Retry
          </a>
        </div>
      )}
      <div className="mb-5 flex flex-wrap items-end justify-between gap-4">
        <div>
          <Link href="/admin/daily-revenue" className="text-[12px] font-semibold text-muted-foreground hover:text-brand">
            ← Back to revenue range
          </Link>
          <h1 className="mt-1.5 font-display text-[32px] font-bold leading-none">{dayHeading}</h1>
        </div>
        <div className="flex items-center gap-2.5">
          <div className="flex items-center gap-2">
            <Link
              href={`/admin/daily-revenue/${dayKey(prevDay)}`}
              className="grid size-9 place-items-center rounded-lg border border-border bg-card"
              aria-label="Previous day"
            >
              <ChevronLeft className="size-4" />
            </Link>
            <span className="font-display text-[14px] font-bold">{dayLabel}</span>
            {isToday ? (
              <span className="grid size-9 place-items-center rounded-lg border border-border/50 text-muted-foreground/30">
                <ChevronRight className="size-4" />
              </span>
            ) : (
              <Link
                href={`/admin/daily-revenue/${dayKey(nextDay)}`}
                className="grid size-9 place-items-center rounded-lg border border-border bg-card"
                aria-label="Next day"
              >
                <ChevronRight className="size-4" />
              </Link>
            )}
          </div>
          <DailyRevenueExportButton
            txns={txns}
            dateStr={dateStr}
            fileDateStr={dayStr.split("-").join("_")}
            totalRevenue={totalRevenue}
          />
        </div>
      </div>

      <div className="mb-5 rounded-[20px] border border-border bg-[linear-gradient(135deg,#141414,#242424)] p-6 text-white shadow-sm">
        <div className="text-[11px] font-semibold uppercase tracking-[0.14em] text-white/60">Total Revenue</div>
        <div className="num mt-2 font-display text-[40px] font-bold">
          <CountUp value={totalRevenue} format="inr" />
        </div>
        <div className="mt-1 text-[12px] text-white/60">
          {txns.length} payment{txns.length === 1 ? "" : "s"} recorded
        </div>
      </div>

      <DayActivityTable rows={activityRows} />
    </div>
  );
}
