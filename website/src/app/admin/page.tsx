import type { Metadata } from "next";
import Link from "next/link";
import { UserPlus, TrendingUp, TrendingDown, ArrowRight } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { nowInIST, istMidnightMs } from "@/lib/ist-time";
import { RevenueChart, type RevenueDay } from "@/components/admin/revenue-chart";
import { MonthPicker } from "@/components/admin/month-picker";
import { RefreshButton } from "@/components/admin/refresh-button";
import { QuickRenewButton } from "@/components/admin/quick-renew-button";
import { CountUp } from "@/components/count-up";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Overview - Vishal Fitness Admin",
};

type Pass = { id: string; name: string; price: number; duration_days: number };

// Mirrors _safe() in admin_dashboard_screen.dart - one failing query never
// takes down the rest of the dashboard.
async function safeSelect<T>(promise: PromiseLike<{ data: T[] | null; error: unknown }>) {
  try {
    const { data, error } = await promise;
    if (error) {
      console.error("admin/page: query failed:", error);
      return [] as T[];
    }
    return data ?? ([] as T[]);
  } catch (err) {
    console.error("admin/page: query threw:", err);
    return [] as T[];
  }
}

// Local-calendar formatting - NOT .toISOString(), which would convert
// through UTC first and can land on the wrong IST calendar day.
function dayKey(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function monthKeyOf(year: number, month0: number) {
  return `${year}-${String(month0 + 1).padStart(2, "0")}`;
}

function isValidMonthKey(s: string | undefined): s is string {
  return !!s && /^\d{4}-\d{2}$/.test(s);
}

export default async function OverviewPage({
  searchParams,
}: {
  searchParams: Promise<{ month?: string }>;
}) {
  const { month: monthParam } = await searchParams;
  const supabase = await createClient();

  const nowReal = new Date();
  const now = nowInIST();
  const currentMonthKey = monthKeyOf(now.getFullYear(), now.getMonth());
  // Can't select a future month - clamp anything past the current one back
  // to "now" instead of silently querying an empty range.
  const monthKey = isValidMonthKey(monthParam) && monthParam <= currentMonthKey ? monthParam : currentMonthKey;
  const [selYear, selMonth1] = monthKey.split("-").map(Number);
  const selMonth0 = selMonth1 - 1;
  const isSelectedCurrentMonth = monthKey === currentMonthKey;

  const monthFirstDay = new Date(selYear, selMonth0, 1);
  const monthLastDay = new Date(selYear, selMonth0 + 1, 0);
  // The current month can't show revenue for days that haven't happened yet.
  const lastVisibleDay = isSelectedCurrentMonth ? now : monthLastDay;
  const monthStartYMD = dayKey(monthFirstDay);
  const monthEndYMD = dayKey(monthLastDay);

  const prevMonthFirstDay = new Date(selYear, selMonth0 - 1, 1);
  const prevMonthLastDay = new Date(selYear, selMonth0, 0);
  const prevMonthStartYMD = dayKey(prevMonthFirstDay);
  const prevMonthEndYMD = dayKey(prevMonthLastDay);

  const todayStart = new Date(istMidnightMs(now.getFullYear(), now.getMonth(), now.getDate()));

  const [
    totalMembersRes,
    paymentsSelectedMonth,
    paymentsPrevMonth,
    newToday,
    allActiveSubEndDates,
    passes,
  ] = await Promise.all([
    supabase.from("subscriptions").select("id", { count: "exact", head: true }),
    safeSelect<{ amount: number; payment_date: string }>(
      supabase.from("payments").select("amount, payment_date").gte("payment_date", monthStartYMD).lte("payment_date", monthEndYMD),
    ),
    safeSelect<{ amount: number }>(
      supabase.from("payments").select("amount").gte("payment_date", prevMonthStartYMD).lte("payment_date", prevMonthEndYMD),
    ),
    safeSelect<{ id: string }>(
      supabase.from("subscriptions").select("id").gte("created_at", todayStart.toISOString()),
    ),
    safeSelect<{ end_date: string }>(
      supabase.from("subscriptions").select("end_date").neq("status", "cancelled"),
    ),
    safeSelect<Pass>(
      supabase.from("gym_passes").select("id, name, price, duration_days").eq("is_active", true).order("duration_days", { ascending: true }),
    ),
  ]);

  if (totalMembersRes.error) console.error("admin/page: total members count failed:", totalMembersRes.error);
  const totalMembers = totalMembersRes.count ?? 0;
  const monthRevenue = paymentsSelectedMonth.reduce((sum, p) => sum + (p.amount ?? 0), 0);
  const prevMonthRevenue = paymentsPrevMonth.reduce((sum, p) => sum + (p.amount ?? 0), 0);
  const newMembersToday = newToday.length;

  let trendLabel = "";
  let trendPositive = true;
  if (prevMonthRevenue > 0) {
    const pct = Math.round(((monthRevenue - prevMonthRevenue) / prevMonthRevenue) * 100);
    trendPositive = pct >= 0;
    trendLabel = `${trendPositive ? "+" : ""}${pct}% vs last month`;
  } else if (monthRevenue > 0) {
    trendLabel = "New this month";
  }

  let expired = 0;
  let critical = 0;
  let expiring = 0;
  for (const sub of allActiveSubEndDates) {
    const endDate = sub.end_date ? new Date(sub.end_date) : null;
    if (!endDate) continue;
    const days = Math.floor((endDate.getTime() - nowReal.getTime()) / 86_400_000);
    if (days < 0) expired++;
    else if (days <= 7) critical++;
    else if (days <= 30) expiring++;
  }
  const expiringSoon = critical + expiring;

  const revenueByDay = new Map<string, number>();
  for (const p of paymentsSelectedMonth) {
    revenueByDay.set(p.payment_date, (revenueByDay.get(p.payment_date) ?? 0) + (p.amount ?? 0));
  }
  const chartDays: RevenueDay[] = [];
  for (const cursor = new Date(monthFirstDay); cursor <= lastVisibleDay; cursor.setDate(cursor.getDate() + 1)) {
    const key = dayKey(cursor);
    chartDays.push({ date: key, label: String(cursor.getDate()), amount: revenueByDay.get(key) ?? 0 });
  }
  const todayYMD = dayKey(now);

  return (
    <div>
      <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
        <div>
          <div className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            {now.toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long" }).toUpperCase()}
          </div>
          <h1 className="mt-1.5 font-display text-[32px] font-bold leading-none">Overview</h1>
        </div>
        <div className="flex items-center gap-2.5">
          <QuickRenewButton passes={passes} />
          <Link href="/admin/add-member" className="btn-shine flex items-center gap-2 rounded-xl bg-brand px-4 py-2.5 text-[13px] font-bold text-on-brand">
            <UserPlus className="size-[15px]" />
            Add Member
          </Link>
          <RefreshButton />
        </div>
      </div>

      <div className="mb-5 grid grid-cols-1 gap-3.5 sm:grid-cols-2 xl:grid-cols-[1.4fr_1fr_1fr_1fr]">
        <div className="rounded-[20px] border border-border bg-[linear-gradient(135deg,#141414,#242424)] p-5 text-white shadow-sm">
          <div className="flex items-center justify-between gap-2">
            <span className="text-[10px] font-semibold uppercase tracking-[0.14em] text-white/60">Revenue</span>
            {trendLabel && (
              <span
                className={`flex shrink-0 items-center gap-1 rounded-full px-2.5 py-1 text-[11px] font-bold ${
                  trendPositive ? "bg-brand/20 text-[#4FE393]" : "bg-energy/20 text-energy"
                }`}
              >
                {trendPositive ? <TrendingUp className="size-3" /> : <TrendingDown className="size-3" />}
                {trendLabel}
              </span>
            )}
          </div>
          <div className="mt-1.5">
            <MonthPicker month={monthKey} currentMonth={currentMonthKey} basePath="/admin" />
          </div>
          <div className="num mt-2.5 font-display text-[38px] font-bold">
            <CountUp value={monthRevenue} format="inr" />
          </div>
          <Link
            href={`/admin/daily-revenue?from=${monthStartYMD}&to=${dayKey(lastVisibleDay)}`}
            className="mt-1 inline-block text-[12px] font-bold text-[#4FE393]"
          >
            Day-wise breakdown →
          </Link>
        </div>

        <StatCard
          label="Total Members"
          value={totalMembers}
          sub={`+${newMembersToday} today`}
          href="/admin/subscriptions"
        />
        <StatCard
          label="Expired"
          value={expired}
          sub="Needs renewal"
          href="/admin/expiry?filter=expired"
        />
        <StatCard
          label="Expiring Soon"
          value={expiringSoon}
          sub="Within 30 days"
          href="/admin/expiry?filter=soon"
        />
      </div>

      <div className="mb-4 rounded-[20px] border border-border bg-card p-5 shadow-sm">
        <div className="mb-1 flex items-center justify-between">
          <h3 className="font-display text-[18px] font-bold">
            {monthKeyOf(selYear, selMonth0) === currentMonthKey
              ? "Revenue Trend"
              : `Revenue Trend — ${monthFirstDay.toLocaleDateString("en-GB", { month: "long", year: "numeric" })}`}
          </h3>
          <span className="flex items-center gap-1.5 text-[12px] font-medium text-muted-foreground">
            <span className="size-2 rounded-sm bg-brand" /> Daily collections (₹)
          </span>
        </div>
        <RevenueChart days={chartDays} today={todayYMD} />
      </div>
    </div>
  );
}

function StatCard({ label, value, sub, href }: { label: string; value: number; sub: string; href?: string }) {
  const content = (
    <>
      <div className="flex items-center justify-between">
        <span className="text-[10px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">{label}</span>
        {href && <ArrowRight className="size-3.5 text-muted-foreground/50 transition-transform group-hover:translate-x-0.5 group-hover:text-brand" />}
      </div>
      <div className="num mt-3.5 font-display text-[26px] font-bold">
        <CountUp value={value} />
      </div>
      <div className="mt-1.5 text-[12px] font-semibold text-muted-foreground">{sub}</div>
    </>
  );

  if (href) {
    return (
      <Link href={href} className="card-hover group block rounded-[20px] border border-border bg-card p-5 shadow-sm">
        {content}
      </Link>
    );
  }

  return <div className="card-hover rounded-[20px] border border-border bg-card p-5 shadow-sm">{content}</div>;
}
