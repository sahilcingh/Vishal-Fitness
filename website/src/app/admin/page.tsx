import { UserPlus, RefreshCw, TrendingUp, TrendingDown, Users, CalendarClock, Bell } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { formatINR } from "@/lib/format";
import { RevenueChart, type RevenueDay } from "@/components/admin/revenue-chart";

export const dynamic = "force-dynamic";

// Mirrors _safe() in admin_dashboard_screen.dart — one failing query never
// takes down the rest of the dashboard.
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
  return d.toISOString().slice(0, 10);
}

export default async function OverviewPage() {
  const supabase = await createClient();

  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const lastMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const fourteenDaysAgo = new Date(now);
  fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 13);

  const [
    activeSubs,
    paymentsThisMonth,
    paymentsLastMonth,
    newToday,
    upcomingClassesRows,
    allActiveSubEndDates,
    recentCheckIns,
    recentSubs,
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
    safeSelect<{ id: string }>(supabase.from("classes").select("id").gt("start_time", now.toISOString())),
    safeSelect<{ end_date: string }>(
      supabase.from("subscriptions").select("end_date").neq("status", "cancelled"),
    ),
    safeSelect(
      supabase
        .from("check_ins")
        .select("checked_in_at, profiles(full_name)")
        .order("checked_in_at", { ascending: false })
        .limit(10)
        .returns<{ checked_in_at: string; profiles: { full_name: string | null } | null }[]>(),
    ),
    safeSelect(
      supabase
        .from("subscriptions")
        .select("created_at, profiles(full_name), gym_passes(name)")
        .order("created_at", { ascending: false })
        .limit(10)
        .returns<
          {
            created_at: string;
            profiles: { full_name: string | null } | null;
            gym_passes: { name: string | null } | null;
          }[]
        >(),
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
    const days = Math.floor((endDate.getTime() - now.getTime()) / 86_400_000);
    if (days < 0) expired++;
    else if (days <= 7) critical++;
    else if (days <= 30) expiring++;
  }

  type Activity = { title: string; subtitle: string; time: Date; kind: "checkin" | "sub" };
  const activity: Activity[] = [
    ...recentCheckIns.flatMap((c) => {
      const t = c.checked_in_at ? new Date(c.checked_in_at) : null;
      if (!t) return [];
      return [
        {
          title: `${c.profiles?.full_name ?? "A member"} checked in`,
          subtitle: "Gym visit recorded",
          time: t,
          kind: "checkin" as const,
        },
      ];
    }),
    ...recentSubs.flatMap((s) => {
      const t = s.created_at ? new Date(s.created_at) : null;
      if (!t) return [];
      return [
        {
          title: "New subscription",
          subtitle: `${s.profiles?.full_name ?? "A member"} — ${s.gym_passes?.name ?? "Pass"}`,
          time: t,
          kind: "sub" as const,
        },
      ];
    }),
  ]
    .sort((a, b) => b.time.getTime() - a.time.getTime())
    .slice(0, 10);

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
            {now.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" }).toUpperCase()}
          </div>
          <h1 className="mt-1.5 font-display text-[32px] font-bold leading-none">Overview</h1>
        </div>
        <div className="flex items-center gap-2.5">
          <button className="flex items-center gap-2 rounded-xl bg-brand px-4 py-2.5 text-[13px] font-bold text-on-brand">
            <UserPlus className="size-[15px]" />
            Add Member
          </button>
          <button className="grid size-[38px] place-items-center rounded-xl border border-border bg-card">
            <RefreshCw className="size-4 text-muted-foreground" />
          </button>
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
          <a href="/admin/daily-revenue" className="mt-1 inline-block text-[12px] font-bold text-[#4FE393]">
            Day-wise breakdown →
          </a>
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

      <div className="mb-5 grid grid-cols-1 gap-3.5 lg:grid-cols-[1fr_1.15fr]">
        <div className="rounded-[20px] border border-border bg-card p-5 shadow-sm">
          <h3 className="mb-3.5 flex items-center gap-2 font-display text-[17px] font-bold">
            <Bell className="size-4 text-energy" /> Expiry Alerts
          </h3>
          <div className="flex gap-2.5">
            <AlertChip count={expired} label="Expired" tone="danger" />
            <AlertChip count={critical} label="≤ 7 Days" tone="critical" />
            <AlertChip count={expiring} label="≤ 30 Days" tone="warn" />
          </div>
        </div>

        <div className="rounded-[20px] border border-border bg-card p-5 shadow-sm">
          <h3 className="mb-3.5 font-display text-[17px] font-bold">Recent Activity</h3>
          {activity.length === 0 ? (
            <p className="py-6 text-center text-[13px] text-muted-foreground">No recent activity</p>
          ) : (
            <ul className="divide-y divide-border">
              {activity.map((a, i) => (
                <li key={i} className="flex items-center gap-3 py-2.5">
                  <span
                    className={`grid size-8 shrink-0 place-items-center rounded-full ${
                      a.kind === "checkin" ? "bg-brand/15 text-brand" : "bg-aqua/15 text-aqua"
                    }`}
                  >
                    {a.kind === "checkin" ? <Users className="size-4" /> : <CalendarClock className="size-4" />}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[13px] font-bold">{a.title}</span>
                    <span className="block truncate text-[11.5px] text-muted-foreground">{a.subtitle}</span>
                  </span>
                  <span className="shrink-0 text-[11px] text-muted-foreground">{timeAgo(a.time)}</span>
                </li>
              ))}
            </ul>
          )}
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
      <div className="mt-1.5 text-[12px] font-semibold text-brand">{sub}</div>
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

function timeAgo(date: Date) {
  const diffMs = Date.now() - date.getTime();
  const mins = Math.floor(diffMs / 60_000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d ago`;
  return date.toLocaleDateString("en-GB", { day: "numeric", month: "short" });
}
