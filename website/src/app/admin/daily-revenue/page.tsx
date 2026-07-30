import Link from "next/link";
import { ChevronLeft, ChevronRight, Receipt } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { formatINR } from "@/lib/format";
import { DailyRevenueExportButton } from "@/components/admin/daily-revenue-export-button";

export const dynamic = "force-dynamic";

async function safeSelect<T>(promise: PromiseLike<{ data: T[] | null; error: unknown }>) {
  try {
    const { data, error } = await promise;
    if (error) return [] as T[];
    return data ?? ([] as T[]);
  } catch {
    return [] as T[];
  }
}

function dayKey(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function parseDayParam(s: string | undefined) {
  if (!s) return new Date();
  const [y, m, d] = s.split("-").map(Number);
  if (!y || !m || !d) return new Date();
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

  const now = new Date();
  const day = parseDayParam(dayParam);
  const dayStr = dayKey(day);
  const isToday = isSameDay(day, now);

  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  const dayLabel = isToday
    ? "Today"
    : isSameDay(day, yesterday)
      ? "Yesterday"
      : day.toLocaleDateString("en-US", { weekday: "long", day: "numeric", month: "long" });

  const prevDay = new Date(day);
  prevDay.setDate(prevDay.getDate() - 1);
  const nextDay = new Date(day);
  nextDay.setDate(nextDay.getDate() + 1);

  const payRows = await safeSelect(
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
  if (subscriptionIds.length > 0) {
    const totals = await safeSelect<{ subscription_id: string; amount: number }>(
      supabase.from("payments").select("subscription_id, amount").in("subscription_id", subscriptionIds),
    );
    for (const t of totals) {
      paidToDate.set(t.subscription_id, (paidToDate.get(t.subscription_id) ?? 0) + (t.amount ?? 0));
    }
  }

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
      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <div className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Daily Revenue Report
          </div>
          <h1 className="mt-1.5 font-display text-[32px] font-bold leading-none">Daily Revenue</h1>
        </div>
        <DailyRevenueExportButton
          txns={txns}
          dateStr={dateStr}
          fileDateStr={dayStr.split("-").join("_")}
          totalRevenue={totalRevenue}
        />
      </div>

      <div className="mb-5 flex items-center justify-center gap-3">
        <Link
          href={`/admin/daily-revenue?day=${dayKey(prevDay)}`}
          className="grid size-9 place-items-center rounded-lg border border-border bg-card"
          aria-label="Previous day"
        >
          <ChevronLeft className="size-4" />
        </Link>
        <span className="font-display text-[16px] font-bold">{dayLabel}</span>
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

      <div className="mb-5 rounded-[20px] border border-border bg-[linear-gradient(135deg,#141414,#242424)] p-6 text-white shadow-sm">
        <div className="text-[11px] font-semibold uppercase tracking-[0.14em] text-white/60">Total Revenue</div>
        <div className="num mt-2 font-display text-[40px] font-bold">{formatINR(totalRevenue)}</div>
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
                      {t.discount > 0 ? formatINR(t.discount) : "—"}
                    </td>
                    <td className="num px-3 py-3.5 text-right font-bold text-brand">{formatINR(t.paidAmount)}</td>
                    <td className="num px-5 py-3.5 text-right font-semibold">
                      {t.balanceAmount > 0 ? (
                        <span className="text-energy">{formatINR(t.balanceAmount)}</span>
                      ) : (
                        <span className="text-muted-foreground">Fully paid</span>
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
