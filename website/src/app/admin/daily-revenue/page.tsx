import type { Metadata } from "next";
import Link from "next/link";
import { ChevronLeft, ChevronRight, Receipt, AlertTriangle } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { formatINR } from "@/lib/format";
import { nowInIST } from "@/lib/ist-time";
import { DailyRevenueExportButton } from "@/components/admin/daily-revenue-export-button";
import { CountUp } from "@/components/count-up";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Daily Revenue - Vishal Fitness Admin",
};

// Unlike admin_dashboard_screen.dart's _safe() (mirrored in the Overview
// page), the numbers here feed an official CSV export - a swallowed error
// must not render identically to a genuine zero-revenue day. Callers check
// `hadError` and show a warning banner instead of silently trusting `data`.
async function safeSelect<T>(promise: PromiseLike<{ data: T[] | null; error: unknown }>) {
  try {
    const { data, error } = await promise;
    if (error) {
      console.error("daily-revenue/page: query failed:", error);
      return { data: [] as T[], hadError: true };
    }
    return { data: data ?? ([] as T[]), hadError: false };
  } catch (err) {
    console.error("daily-revenue/page: query threw:", err);
    return { data: [] as T[], hadError: true };
  }
}

function dayKey(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function parseDayParam(s: string | undefined, fallback: Date) {
  if (!s) return fallback;
  const [y, m, d] = s.split("-").map(Number);
  if (!y || !m || !d) return fallback;
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
    profiles: { full_name: string | null; phone: string | null } | null;
    gym_passes: { name: string | null; price: number | null } | null;
  } | null;
};

export default async function DailyRevenuePage({
  searchParams,
}: {
  searchParams: Promise<{ day?: string }>;
}) {
  const { day: dayParam } = await searchParams;
  const supabase = await createClient();

  const now = nowInIST();
  const day = parseDayParam(dayParam, now);
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

  const { data: payRows, hadError: payRowsErrored } = await safeSelect(
    supabase
      .from("payments")
      .select(
        `amount, payment_method, subscription_id,
         subscriptions:subscription_id (
           discount_amount,
           profiles:user_id ( full_name, phone ),
           gym_passes:pass_id ( name, price )
         )`,
      )
      .eq("payment_date", dayStr)
      .order("created_at")
      .returns<PaymentRow[]>(),
  );

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

  const txns = payRows.map((r) => {
    const sub = r.subscriptions;
    const price = sub?.gym_passes?.price ?? 0;
    const discount = sub?.discount_amount ?? 0;
    const effectiveFee = Math.max(price - discount, 0);
    const paid = r.amount ?? 0;
    const balance = Math.max(effectiveFee - (paidToDate.get(r.subscription_id ?? "") ?? 0), 0);
    return {
      name: sub?.profiles?.full_name ?? "Member",
      phone: sub?.profiles?.phone ?? "",
      passType: sub?.gym_passes?.name ?? "Pass",
      packageAmount: price,
      discount,
      paymentMethod: (r.payment_method ?? "").toUpperCase(),
      paidAmount: paid,
      balanceAmount: balance,
    };
  });

  const totalRevenue = txns.reduce((sum, t) => sum + t.paidAmount, 0);
  const dateStr = day.toLocaleDateString("en-GB").split("/").join("/"); // dd/mm/yyyy

  return (
    <div>
      {hadDataError && (
        <div className="mb-5 flex items-center gap-3 rounded-xl border border-danger/30 bg-danger/10 px-4 py-3 text-[13px] text-danger">
          <AlertTriangle className="size-4 shrink-0" />
          <span className="flex-1">Couldn&apos;t load some revenue data - figures below may be incomplete.</span>
          <a href={`/admin/daily-revenue?day=${dayStr}`} className="shrink-0 font-bold underline">
            Retry
          </a>
        </div>
      )}
      <div className="mb-5 flex flex-wrap items-end justify-between gap-4">
        <div>
          <div className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Daily Revenue Report
          </div>
          <h1 className="mt-1.5 font-display text-[32px] font-bold leading-none">{dayHeading}</h1>
        </div>
        <div className="flex items-center gap-2.5">
          <div className="flex items-center gap-2">
            <Link
              href={`/admin/daily-revenue?day=${dayKey(prevDay)}`}
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
                href={`/admin/daily-revenue?day=${dayKey(nextDay)}`}
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

      <div className="rounded-[20px] border border-border bg-card shadow-sm">
        {txns.length === 0 ? (
          <div className="flex flex-col items-center gap-3 px-6 py-16 text-center">
            <Receipt className="size-9 text-muted-foreground" />
            <p className="text-[13px] text-muted-foreground">No payments recorded on this day.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[820px] text-left text-[13px]">
              <thead>
                <tr className="border-b border-border text-[10.5px] font-semibold uppercase tracking-wide text-muted-foreground">
                  <th className="px-5 py-3 font-semibold">S.No</th>
                  <th className="px-3 py-3 font-semibold">Member</th>
                  <th className="px-3 py-3 font-semibold">Subscription</th>
                  <th className="px-3 py-3 font-semibold">Mode</th>
                  <th className="px-3 py-3 text-right font-semibold">Package</th>
                  <th className="px-3 py-3 text-right font-semibold">Discount</th>
                  <th className="px-3 py-3 text-right font-semibold">Paid</th>
                  <th className="px-5 py-3 text-right font-semibold">Balance</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {txns.map((t, i) => (
                  <tr key={i}>
                    <td className="px-5 py-3.5 text-muted-foreground">{i + 1}</td>
                    <td className="px-3 py-3.5">
                      <div className="font-bold">{t.name}</div>
                      {t.phone && <div className="text-[11.5px] text-muted-foreground">{t.phone}</div>}
                    </td>
                    <td className="px-3 py-3.5">
                      <span className="rounded-md bg-aqua/12 px-2 py-1 text-[11px] font-semibold text-aqua">
                        {t.passType}
                      </span>
                    </td>
                    <td className="px-3 py-3.5">
                      <span className="rounded-md bg-muted px-2 py-1 text-[11px] font-semibold text-muted-foreground">
                        {t.paymentMethod}
                      </span>
                    </td>
                    <td className="num px-3 py-3.5 text-right">{formatINR(t.packageAmount)}</td>
                    <td className="num px-3 py-3.5 text-right text-energy">
                      {t.discount > 0 ? formatINR(t.discount) : "-"}
                    </td>
                    <td className="num px-3 py-3.5 text-right font-bold text-brand">{formatINR(t.paidAmount)}</td>
                    <td className="num px-5 py-3.5 text-right font-semibold">
                      {t.balanceAmount > 0 ? (
                        <span className="text-energy">{formatINR(t.balanceAmount)}</span>
                      ) : (
                        <span className="font-semibold text-brand">Fully Paid</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
