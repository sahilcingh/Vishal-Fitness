import type { Metadata } from "next";
import Link from "next/link";
import { UserPlus, TrendingUp, TrendingDown, Bell } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { formatINR } from "@/lib/format";
import { nowInIST, istMidnightMs } from "@/lib/ist-time";
import { RevenueChart, type RevenueDay } from "@/components/admin/revenue-chart";
import { RefreshButton } from "@/components/admin/refresh-button";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Overview — Vishal Fitness Admin",
};

// Mirrors _safe() in admin_dashboard_screen.dart — one failing query never
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

// Local-calendar formatting — NOT .toISOString(), which would convert
// through UTC first and can land on the wrong IST calendar day.
function dayKey(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

// classes.start_time is stored as a naive local (IST) string with no
// timezone suffix (matches the Flutter app's own storage format) — compare
// against the same naive shape rather than a real UTC instant.
function naiveISO(d: Date) {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

export default async function OverviewPage() {
  const supabase = await createClient();

  const nowReal = new Date();
  const now = nowInIST();
  const monthStart = new Date(istMidnightMs(now.getFullYear(), now.getMonth(), 1));
  const lastMonthStart = new Date(istMidnightMs(now.getFullYear(), now.getMonth() - 1, 1));
  const todayStart = new Date(istMidnightMs(now.getFullYear(), now.getMonth(), now.getDate()));
  const fourteenDaysAgo = new Date(now);
  fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 13);

  const [
    activeSubs,
    paymentsThisMonth,
    paymentsLastMonth,
    newToday,
    upcomingClassesRows,
    allActiveSubEndDates,
    paymentsLast14Days,
  ] = await Promise.all([
    safeSelect<{ id: string }>(supabase.from("subscriptions").select("id").eq("status", "active")),
    safeSelect<{ amount: number }>(
      supabase.from("payments").select("amount").gte("created_at", monthStart.toISOString()),
    ),
    safeSelect<{ amount: number }>(
      supabase
        .from("payments")
        .select("amount")
        .gte("created_at", lastMonthStart.toISOString())
        .lt("created_at", monthStart.toISOString()),
    ),
    safeSelect<{ id: string }>(
      supabase.from("subscriptions").select("id").gte("created_at", todayStart.toISOString()),
    ),
    safeSelect<{ id: string }>(supabase.from("classes").select("id").gt("start_time", naiveISO(now))),
    safeSelect<{ end_date: string }>(
      supabase.from("subscriptions").select("end_date").neq("status", "cancelled"),
    ),
    safeSelect<{ amount: number; payment_date: string }>(
      supabase
        .from("payments")
        .select("amount, payment_date")
        .gte("payment_date", dayKey(fourteenDaysAgo)),
    ),
  ]);

  const activeMembers = activeSubs.length;
  const revenueThisMonth = paymentsThisMonth.reduce((sum, p) => sum + (p.amount ?? 0), 0);
  const revenueLastMonth = paymentsLastMonth.reduce((sum, p) => sum + (p.amount ?? 0), 0);
  const newMembersToday = newToday.length;
  const upcomingClasses = upcomingClassesRows.length;

  let trendLabel = "";
  let trendPositive = true;
  if (revenueLastMonth > 0) {
    const pct = Math.round(((revenueThisMonth - revenueLastMonth) / revenueLastMonth) * 100);
    trendPositive = pct >= 0;
    trendLabel = `${trendPositive ? "+" : ""}${pct}% vs last month`;
  } else if (revenueThisMonth > 0) {
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

  const revenueByDay = new Map<string, number>();
  for (const p of paymentsLast14Days) {
    revenueByDay.set(p.payment_date, (revenueByDay.get(p.payment_date) ?? 0) + (p.amount ?? 0));
  }
  const chartDays: RevenueDay[] = Array.from({ length: 14 }, (_, i) => {
    const d = new Date(fourteenDaysAgo);
    d.setDate(d.getDate() + i);
    const key = dayKey(d);
    return {
      date: key,
      label: d.toLocaleDateString("en-GB", { day: "2-digit", month: "short" }).toUpperCase(),
      amount: revenueByDay.get(key) ?? 0,
    };
  });

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
          <Link href="/admin/add-member" className="flex items-center gap-2 rounded-xl bg-brand px-4 py-2.5 text-[13px] font-bold text-on-brand">
            <UserPlus className="size-[15px]" />
            Add Member
          </Link>
          <RefreshButton />
        </div>
      </div>

      <div className="mb-5 grid grid-cols-1 gap-3.5 sm:grid-cols-2 xl:grid-cols-[1.4fr_1fr_1fr_1fr]">
        <div className="rounded-[20px] border border-border bg-[linear-gradient(135deg,#141414,#242424)] p-5 text-white shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-[10px] font-semibold uppercase tracking-[0.14em] text-white/60">
              Revenue this month
            </span>
            {trendLabel && (
              <span
                className={`flex items-center gap-1 rounded-full px-2.5 py-1 text-[11px] font-bold ${
                  trendPositive ? "bg-brand/20 text-[#4FE393]" : "bg-energy/20 text-energy"
                }`}
              >
                {trendPositive ? <TrendingUp className="size-3" /> : <TrendingDown className="size-3" />}
                {trendLabel}
              </span>
            )}
          </div>
          <div className="num mt-3.5 font-display text-[38px] font-bold">{formatINR(revenueThisMonth)}</div>
          <Link href="/admin/daily-revenue" className="mt-1 inline-block text-[12px] font-bold text-[#4FE393]">
            Day-wise breakdown →
          </Link>
        </div>

        <StatCard label="Active Members" value={activeMembers.toString()} sub={`+${newMembersToday} today`} />
        <StatCard label="New Today" value={newMembersToday.toString()} sub="Since midnight" />
        <StatCard label="Upcoming Classes" value={upcomingClasses.toString()} sub="Next 7 days" />
      </div>

      <div className="mb-4 rounded-[20px] border border-border bg-card p-5 shadow-sm">
        <div className="mb-5 flex items-center justify-between">
          <h3 className="font-display text-[18px] font-bold">14-Day Revenue</h3>
          <span className="flex items-center gap-1.5 text-[12px] font-medium text-muted-foreground">
            <span className="size-2 rounded-sm bg-brand" /> Daily collections (₹)
          </span>
        </div>
        <RevenueChart days={chartDays} />
      </div>

      <div className="mb-5 rounded-[20px] border border-border bg-card p-5 shadow-sm">
        <h3 className="mb-3.5 flex items-center gap-2 font-display text-[17px] font-bold">
          <Bell className="size-4 text-energy" /> Expiry Alerts
        </h3>
        <div className="flex gap-2.5">
          <AlertChip count={expired} label="Expired" tone="danger" />
          <AlertChip count={critical} label="≤ 7 Days" tone="critical" />
          <AlertChip count={expiring} label="≤ 30 Days" tone="warn" />
        </div>
      </div>
    </div>
  );
}

function StatCard({ label, value, sub }: { label: string; value: string; sub: string }) {
  return (
    <div className="rounded-[20px] border border-border bg-card p-5 shadow-sm">
      <div className="text-[10px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">{label}</div>
      <div className="num mt-3.5 font-display text-[26px] font-bold">{value}</div>
      <div className="mt-1.5 text-[12px] font-semibold text-muted-foreground">{sub}</div>
    </div>
  );
}

const TONE_CLASSES = {
  danger: "bg-danger/10 text-danger",
  critical: "bg-energy/12 text-energy",
  warn: "bg-sun/[0.18] text-[#B8930A]",
} as const;

function AlertChip({ count, label, tone }: { count: number; label: string; tone: keyof typeof TONE_CLASSES }) {
  return (
    <div className={`flex-1 rounded-xl px-3.5 py-3 ${TONE_CLASSES[tone]}`}>
      <div className="num font-display text-[21px] font-bold">{count}</div>
      <div className="text-[10px] font-bold uppercase tracking-wide">{label}</div>
    </div>
  );
}
