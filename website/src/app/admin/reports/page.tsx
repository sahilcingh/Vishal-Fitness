import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft, CalendarRange, IndianRupee, UserCheck, UserSearch, Users } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { nowInIST } from "@/lib/ist-time";
import { ReportCard, type ReportColumn, type ReportRow } from "@/components/admin/report-card";
import { CountUp } from "@/components/count-up";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Reports - Vishal Fitness Admin",
};

// Mirrors _safe() / safeSelect() on the other admin pages - one failing query
// never takes down the rest of the dashboard. Errors are still logged (not
// just swallowed) so a genuine query failure is distinguishable from real
// zero rows in server logs.
async function safeSelect<T>(promise: PromiseLike<{ data: T[] | null; error: unknown }>) {
  try {
    const { data, error } = await promise;
    if (error) {
      console.error("reports/page: query failed:", error);
      return [] as T[];
    }
    return data ?? ([] as T[]);
  } catch (err) {
    console.error("reports/page: query threw:", err);
    return [] as T[];
  }
}

// ── local date helpers (no shared date lib on purpose, see project convention) ──

function pad2(n: number) {
  return String(n).padStart(2, "0");
}
function toYMD(d: Date) {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}
function parseYMD(s: string) {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}
function addDays(d: Date, n: number) {
  const r = new Date(d);
  r.setDate(r.getDate() + n);
  return r;
}
// Supabase `date` columns return plain "YYYY-MM-DD" but `timestamp`/`timestamptz`
// columns return a full ISO string - normalize either to a bare date so date-only
// comparisons never silently misfire.
function normalizeYMD(s: string | null | undefined) {
  if (!s) return "";
  const sliced = s.slice(0, 10);
  return /^\d{4}-\d{2}-\d{2}$/.test(sliced) ? sliced : "";
}
function fmtDMY(s: string | null | undefined) {
  const ymd = normalizeYMD(s);
  if (!ymd) return "";
  const [y, m, d] = ymd.split("-");
  return `${d}/${m}/${y}`;
}
function fmtTime(s: string | null | undefined) {
  if (!s) return "";
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return "";
  let h = d.getHours();
  const m = d.getMinutes();
  const ampm = h >= 12 ? "PM" : "AM";
  h = h % 12 || 12;
  return `${pad2(h)}:${pad2(m)} ${ampm}`;
}
function daysDiffTrunc(a: Date, b: Date) {
  return Math.trunc((a.getTime() - b.getTime()) / 86_400_000);
}
function stamp(d: Date) {
  return `${d.getFullYear()}${pad2(d.getMonth() + 1)}${pad2(d.getDate())}`;
}

// ── row types for the embedded Supabase relations (no generated schema, so these
// are explicit and chained with .returns<T[]>() per project convention) ──

type ProfileRef = { full_name: string | null; phone: string | null; gender?: string | null };
type PassRef = { name: string | null; price: number | null };

type SubActiveRow = {
  entry_date: string;
  end_date: string;
  user_id: string;
  profiles: ProfileRef | null;
  gym_passes: PassRef | null;
};
type SubExpiredRow = {
  end_date: string;
  profiles: ProfileRef | null;
  gym_passes: PassRef | null;
};
type SubMonthCreatedRow = {
  entry_date: string;
  end_date: string;
  profiles: ProfileRef | null;
  gym_passes: PassRef | null;
};
type SubTodayCreatedRow = {
  entry_date: string;
  profiles: ProfileRef | null;
  gym_passes: PassRef | null;
};
type SubAllRow = {
  end_date: string;
  status: string | null;
  gym_passes: PassRef | null;
};
type SubNotCancelledRow = {
  id: string;
  profiles: ProfileRef | null;
  gym_passes: PassRef | null;
};
type PaymentRow = {
  subscription_id: string | null;
  amount: number;
  payment_date: string;
  payment_method: string | null;
  notes: string | null;
  subscriptions: {
    profiles: ProfileRef | null;
    gym_passes: { name: string | null } | null;
  } | null;
};
type CheckInRow = {
  user_id: string;
  checked_in_at: string;
  profiles: ProfileRef | null;
};

export default async function ReportsPage() {
  const supabase = await createClient();

  // Server runs in whatever timezone the host uses (often UTC), but every
  // "today"/"this month" boundary here must reflect the gym's IST calendar
  // day - see src/lib/ist-time.ts (same convention as admin/page.tsx and
  // admin/daily-revenue/page.tsx).
  //
  // nowInIST()'s own .getTime() is NOT a real instant (constructing a Date
  // from plain numbers is always interpreted via the server's own timezone)
  // - safe to use for calendar-component reads (toYMD, addDays) and for
  // comparisons against other same-way-constructed dates (parseYMD(...) -
  // the construction bias is identical on both sides so it cancels out in a
  // difference), but NOT for comparisons against a real timestamptz column.
  // Those need Date.now(), which gives a real epoch value (see cutoff30Ms).
  const now = nowInIST();
  const todayYMD = toYMD(now);
  const monthStartYMD = `${now.getFullYear()}-${pad2(now.getMonth() + 1)}-01`;
  const in30YMD = toYMD(addDays(now, 30));
  const cutoff30Ms = new Date().getTime() - 30 * 86_400_000;

  // PERF: this eagerly fetches all 17 reports' worth of data on every page
  // load regardless of which cards are expanded. Fine at current data
  // volume; if it becomes slow, look at deferring per-card fetches (e.g. via
  // a Route Handler triggered on expand) instead of one big Promise.all here.
  const [subsActiveFull, subsExpiredFull, subsMonthCreated, subsTodayCreated, subsAll, subsNotCancelled, paymentsAll, checkInsAll] =
    await Promise.all([
      safeSelect<SubActiveRow>(
        supabase
          .from("subscriptions")
          .select("entry_date, end_date, user_id, profiles:user_id(full_name, phone, gender), gym_passes:pass_id(name, price)")
          .gte("end_date", todayYMD)
          .neq("status", "cancelled")
          .order("end_date")
          .returns<SubActiveRow[]>(),
      ),
      safeSelect<SubExpiredRow>(
        supabase
          .from("subscriptions")
          .select("end_date, profiles:user_id(full_name, phone), gym_passes:pass_id(name, price)")
          .lt("end_date", todayYMD)
          .order("end_date", { ascending: false })
          .returns<SubExpiredRow[]>(),
      ),
      safeSelect<SubMonthCreatedRow>(
        supabase
          .from("subscriptions")
          .select("entry_date, end_date, profiles:user_id(full_name, phone), gym_passes:pass_id(name, price)")
          .gte("entry_date", monthStartYMD)
          .order("entry_date", { ascending: false })
          .returns<SubMonthCreatedRow[]>(),
      ),
      safeSelect<SubTodayCreatedRow>(
        supabase
          .from("subscriptions")
          .select("entry_date, profiles:user_id(full_name, phone), gym_passes:pass_id(name, price)")
          .eq("entry_date", todayYMD)
          .order("entry_date")
          .returns<SubTodayCreatedRow[]>(),
      ),
      safeSelect<SubAllRow>(
        supabase.from("subscriptions").select("end_date, status, gym_passes:pass_id(name, price)").returns<SubAllRow[]>(),
      ),
      safeSelect<SubNotCancelledRow>(
        supabase
          .from("subscriptions")
          .select("id, profiles:user_id(full_name, phone), gym_passes:pass_id(name, price)")
          .neq("status", "cancelled")
          .returns<SubNotCancelledRow[]>(),
      ),
      safeSelect<PaymentRow>(
        supabase
          .from("payments")
          .select(
            `subscription_id, amount, payment_date, payment_method, notes,
             subscriptions:subscription_id ( profiles:user_id( full_name, phone ), gym_passes:pass_id( name ) )`,
          )
          .order("payment_date", { ascending: false })
          .returns<PaymentRow[]>(),
      ),
      safeSelect<CheckInRow>(
        supabase
          .from("check_ins")
          .select("user_id, checked_in_at, profiles:user_id(full_name, phone)")
          .order("checked_in_at")
          .returns<CheckInRow[]>(),
      ),
    ]);

  // ────────────────────────────────────────────────────────────
  // 1. MEMBERSHIP REPORTS
  // ────────────────────────────────────────────────────────────

  const activeMembersRows: ReportRow[] = subsActiveFull.map((r) => {
    const endYmd = normalizeYMD(r.end_date);
    const endDate = endYmd ? parseYMD(endYmd) : null;
    const daysLeft = endDate ? daysDiffTrunc(endDate, now) : null;
    return [
      r.profiles?.full_name ?? "",
      r.profiles?.phone ?? "",
      r.gym_passes?.name ?? "",
      (r.gym_passes?.price ?? 0).toFixed(0),
      fmtDMY(r.entry_date),
      fmtDMY(r.end_date),
      daysLeft === null ? "" : daysLeft.toString(),
    ];
  });

  const upcomingExpiryRows: ReportRow[] = subsActiveFull
    .filter((r) => {
      const ymd = normalizeYMD(r.end_date);
      return ymd && ymd <= in30YMD;
    })
    .map((r) => {
      const endYmd = normalizeYMD(r.end_date);
      const endDate = endYmd ? parseYMD(endYmd) : null;
      const daysLeft = endDate ? daysDiffTrunc(endDate, now) : null;
      return [
        r.profiles?.full_name ?? "",
        r.profiles?.phone ?? "",
        r.gym_passes?.name ?? "",
        fmtDMY(r.end_date),
        daysLeft === null ? "" : daysLeft.toString(),
      ];
    });

  const genderWiseRows: ReportRow[] = subsActiveFull.map((r) => [
    r.profiles?.full_name ?? "",
    r.profiles?.phone ?? "",
    r.profiles?.gender ?? "Not specified",
    r.gym_passes?.name ?? "",
  ]);

  const recentCheckinUserIds = new Set(
    checkInsAll.filter((c) => new Date(c.checked_in_at).getTime() >= cutoff30Ms).map((c) => c.user_id),
  );
  const inactiveMembersRows: ReportRow[] = subsActiveFull
    .filter((r) => !recentCheckinUserIds.has(r.user_id))
    .map((r) => [r.profiles?.full_name ?? "", r.profiles?.phone ?? "", r.gym_passes?.name ?? "", "No visit in 30+ days"]);

  const expiredBase = subsExpiredFull.map((r) => {
    const endYmd = normalizeYMD(r.end_date);
    const endDate = endYmd ? parseYMD(endYmd) : null;
    const daysSince = endDate ? daysDiffTrunc(now, endDate) : null;
    return {
      name: r.profiles?.full_name ?? "",
      phone: r.profiles?.phone ?? "",
      passName: r.gym_passes?.name ?? "",
      price: (r.gym_passes?.price ?? 0).toFixed(0),
      expiredOn: fmtDMY(r.end_date),
      days: daysSince === null ? "" : daysSince.toString(),
    };
  });
  const expiredMembersRows: ReportRow[] = expiredBase.map((e) => [e.name, e.phone, e.passName, e.price, e.expiredOn, e.days]);
  const pendingRenewalsRows: ReportRow[] = expiredBase.map((e) => [e.name, e.phone, e.passName, e.price, e.expiredOn, e.days]);

  const newAdmissionsRows: ReportRow[] = subsMonthCreated.map((r) => [
    r.profiles?.full_name ?? "",
    r.profiles?.phone ?? "",
    r.gym_passes?.name ?? "",
    (r.gym_passes?.price ?? 0).toFixed(0),
    fmtDMY(r.entry_date),
    fmtDMY(r.end_date),
  ]);

  const typeWiseMap = new Map<string, { price: number; active: number; expired: number }>();
  for (const r of subsAll) {
    const name = r.gym_passes?.name ?? "Unknown";
    const endYmd = normalizeYMD(r.end_date);
    const endDate = endYmd ? parseYMD(endYmd) : null;
    const isActive = !!endDate && endDate.getTime() > now.getTime() && r.status !== "cancelled";
    const entry = typeWiseMap.get(name) ?? { price: r.gym_passes?.price ?? 0, active: 0, expired: 0 };
    if (isActive) entry.active++;
    else entry.expired++;
    typeWiseMap.set(name, entry);
  }
  const typeWiseRows: ReportRow[] = Array.from(typeWiseMap.entries()).map(([name, v]) => [
    name,
    v.price.toFixed(0),
    v.active.toString(),
    v.expired.toString(),
    (v.active + v.expired).toString(),
  ]);

  // ────────────────────────────────────────────────────────────
  // 2. PAYMENT & FINANCE REPORTS
  // ────────────────────────────────────────────────────────────

  const revenueByPassMap = new Map<string, { price: number; count: number; total: number }>();
  for (const r of subsAll) {
    const name = r.gym_passes?.name ?? "Unknown";
    const price = r.gym_passes?.price ?? 0;
    const entry = revenueByPassMap.get(name) ?? { price, count: 0, total: 0 };
    entry.count++;
    entry.total += price;
    revenueByPassMap.set(name, entry);
  }
  const revenueByPassEntries = Array.from(revenueByPassMap.entries());
  const revenueByPassGrand = revenueByPassEntries.reduce((sum, [, v]) => sum + v.total, 0);
  const revenueByPassRows: ReportRow[] = revenueByPassEntries.map(([name, v]) => [
    name,
    v.price.toFixed(0),
    v.count.toString(),
    v.total.toFixed(0),
  ]);

  type UserCollection = { name: string; phone: string; passType: string; newSub: number; installments: number };
  function buildCollection(subs: SubTodayCreatedRow[] | SubMonthCreatedRow[], payments: PaymentRow[]) {
    const grouped = new Map<string, UserCollection>();
    for (const r of subs) {
      const phone = r.profiles?.phone ?? "";
      const entry = grouped.get(phone) ?? {
        name: r.profiles?.full_name ?? "",
        phone,
        passType: r.gym_passes?.name ?? "",
        newSub: 0,
        installments: 0,
      };
      entry.newSub += r.gym_passes?.price ?? 0;
      grouped.set(phone, entry);
    }
    for (const p of payments) {
      const sub = p.subscriptions;
      const phone = sub?.profiles?.phone ?? "";
      const entry = grouped.get(phone) ?? {
        name: sub?.profiles?.full_name ?? "",
        phone,
        passType: sub?.gym_passes?.name ?? "",
        newSub: 0,
        installments: 0,
      };
      entry.installments += p.amount ?? 0;
      grouped.set(phone, entry);
    }
    return Array.from(grouped.values());
  }

  const paymentsToday = paymentsAll.filter((p) => normalizeYMD(p.payment_date) === todayYMD);
  const paymentsThisMonth = paymentsAll.filter((p) => normalizeYMD(p.payment_date) >= monthStartYMD);

  const dailyCollectionGroups = buildCollection(subsTodayCreated, paymentsToday);
  const dailyCollectionGrand = dailyCollectionGroups.reduce((sum, u) => sum + u.newSub + u.installments, 0);
  const dailyCollectionRows: ReportRow[] = dailyCollectionGroups.map((u) => [
    u.name,
    u.phone,
    u.passType,
    u.newSub.toFixed(0),
    u.installments.toFixed(0),
    (u.newSub + u.installments).toFixed(0),
  ]);

  const monthlyCollectionGroups = buildCollection(subsMonthCreated, paymentsThisMonth);
  const monthlyCollectionGrand = monthlyCollectionGroups.reduce((sum, u) => sum + u.newSub + u.installments, 0);
  const monthlyCollectionRows: ReportRow[] = monthlyCollectionGroups.map((u) => [
    u.name,
    u.phone,
    u.passType,
    u.newSub.toFixed(0),
    u.installments.toFixed(0),
    (u.newSub + u.installments).toFixed(0),
  ]);

  const installmentLogRows: ReportRow[] = paymentsAll.map((p) => [
    p.subscriptions?.profiles?.full_name ?? "",
    p.subscriptions?.profiles?.phone ?? "",
    p.subscriptions?.gym_passes?.name ?? "",
    (p.amount ?? 0).toFixed(0),
    p.payment_method ?? "",
    fmtDMY(p.payment_date),
    p.notes ?? "",
  ]);

  const paidMap = new Map<string, number>();
  for (const p of paymentsAll) {
    if (!p.subscription_id) continue;
    paidMap.set(p.subscription_id, (paidMap.get(p.subscription_id) ?? 0) + (p.amount ?? 0));
  }
  const outstandingBalances = subsNotCancelled
    .map((r) => {
      const fee = r.gym_passes?.price ?? 0;
      const paid = paidMap.get(r.id) ?? 0;
      return {
        name: r.profiles?.full_name ?? "",
        phone: r.profiles?.phone ?? "",
        passName: r.gym_passes?.name ?? "",
        fee,
        paid,
        balance: fee - paid,
      };
    })
    .filter((r) => r.balance > 0);
  const outstandingTotal = outstandingBalances.reduce((sum, r) => sum + r.balance, 0);
  const outstandingBalancesRows: ReportRow[] = outstandingBalances.map((r) => [
    r.name,
    r.phone,
    r.passName,
    r.fee.toFixed(0),
    r.paid.toFixed(0),
    r.balance.toFixed(0),
  ]);

  const actualMonthlyTotal = paymentsThisMonth.reduce((sum, p) => sum + (p.amount ?? 0), 0);
  const actualMonthlyRows: ReportRow[] = paymentsThisMonth.map((p) => [
    p.subscriptions?.profiles?.full_name ?? "",
    p.subscriptions?.profiles?.phone ?? "",
    p.subscriptions?.gym_passes?.name ?? "",
    (p.amount ?? 0).toFixed(0),
    p.payment_method ?? "",
    fmtDMY(p.payment_date),
  ]);

  // ────────────────────────────────────────────────────────────
  // 3. ATTENDANCE REPORTS
  // ────────────────────────────────────────────────────────────

  const dailyAttendanceRows: ReportRow[] = checkInsAll
    .filter((c) => normalizeYMD(c.checked_in_at) === todayYMD)
    .map((c) => [c.profiles?.full_name ?? "", c.profiles?.phone ?? "", fmtTime(c.checked_in_at)]);

  const monthlyAttendanceRows: ReportRow[] = checkInsAll
    .filter((c) => normalizeYMD(c.checked_in_at) >= monthStartYMD)
    .map((c) => [c.profiles?.full_name ?? "", c.profiles?.phone ?? "", fmtDMY(c.checked_in_at), fmtTime(c.checked_in_at)]);

  type VisitData = { name: string; phone: string; count: number; last: string };
  const visitMap = new Map<string, VisitData>();
  for (const c of checkInsAll) {
    const uid = c.user_id ?? "";
    const entry = visitMap.get(uid) ?? { name: c.profiles?.full_name ?? uid, phone: c.profiles?.phone ?? "", count: 0, last: "" };
    entry.count++;
    if (c.checked_in_at > entry.last) entry.last = c.checked_in_at;
    visitMap.set(uid, entry);
  }
  const visitFrequencyRows: ReportRow[] = Array.from(visitMap.values())
    .sort((a, b) => b.count - a.count)
    .map((v) => [v.name, v.phone, v.count.toString(), fmtDMY(v.last)]);

  // ────────────────────────────────────────────────────────────
  // Snapshot stats
  // ────────────────────────────────────────────────────────────

  const activeCount = subsActiveFull.length;
  const expiredCount = subsExpiredFull.length;
  const newThisMonthCount = subsMonthCreated.length;
  const inactiveCount = inactiveMembersRows.length;

  return (
    <div>
      <div className="mb-6 flex items-center gap-3">
        <Link href="/admin" className="grid size-9 place-items-center rounded-xl border border-border bg-card" aria-label="Back">
          <ArrowLeft className="size-4" />
        </Link>
        <div>
          <div className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">Data Exports</div>
          <h1 className="mt-1 font-display text-[26px] font-bold leading-none">Reports</h1>
        </div>
      </div>

      <Link
        href="/admin/daily-revenue"
        className="card-hover mb-5 flex items-center gap-3.5 rounded-[20px] border border-border bg-[linear-gradient(135deg,#141414,#242424)] p-4 text-white shadow-sm"
      >
        <span className="grid size-10 shrink-0 place-items-center rounded-full bg-brand/15">
          <CalendarRange className="size-5 text-brand" />
        </span>
        <span className="min-w-0 flex-1">
          <span className="block font-display text-[15px] font-bold">Daily Revenue & New Members</span>
          <span className="mt-0.5 block text-[11.5px] text-white/70">
            Every payment received today - name, amount, balance
          </span>
        </span>
      </Link>

      <div className="mb-6 grid grid-cols-1 gap-3.5 sm:grid-cols-2 md:grid-cols-4 xl:grid-cols-8">
        <SnapshotStat label="Active Members" value={activeCount} />
        <SnapshotStat label="Expired Members" value={expiredCount} />
        <SnapshotStat label="New This Month" value={newThisMonthCount} />
        <SnapshotStat label="Today's Collection" value={dailyCollectionGrand} format="inr" />
        <SnapshotStat label="Monthly Collection" value={monthlyCollectionGrand} format="inr" />
        <SnapshotStat label="Outstanding" value={outstandingTotal} format="inr" />
        <SnapshotStat label="Today's Check-ins" value={dailyAttendanceRows.length} />
        <SnapshotStat label="Inactive (30d)" value={inactiveCount} />
      </div>

      <Section title="Membership Reports" tone="brand" icon={Users}>
        <ReportCard
          title="Active Members"
          subtitle="All currently active subscriptions"
          tone="brand"
          columns={membershipCols.active}
          rows={activeMembersRows}
          csvFileName={`active_members_${stamp(now)}.csv`}
        />
        <ReportCard
          title="Expired Members"
          subtitle="Members with lapsed subscriptions"
          tone="brand"
          columns={membershipCols.expired}
          rows={expiredMembersRows}
          csvFileName={`expired_members_${stamp(now)}.csv`}
        />
        <ReportCard
          title="Upcoming Expiry (30 Days)"
          subtitle="Members expiring within 30 days"
          tone="brand"
          columns={membershipCols.upcoming}
          rows={upcomingExpiryRows}
          csvFileName={`upcoming_expiry_${stamp(now)}.csv`}
        />
        <ReportCard
          title="New Admissions This Month"
          subtitle="Members who joined this month"
          tone="brand"
          columns={membershipCols.newAdmissions}
          rows={newAdmissionsRows}
          csvFileName={`new_admissions_${stamp(now)}.csv`}
        />
        <ReportCard
          title="Membership Type Wise"
          subtitle="Active vs expired count per pass type"
          tone="brand"
          columns={membershipCols.typeWise}
          rows={typeWiseRows}
          csvFileName={`type_wise_${stamp(now)}.csv`}
        />
        <ReportCard
          title="Gender Wise Members"
          subtitle="Active members grouped by gender"
          tone="brand"
          columns={membershipCols.genderWise}
          rows={genderWiseRows}
          csvFileName={`gender_wise_${stamp(now)}.csv`}
        />
      </Section>

      <Section title="Payment & Finance Reports" tone="energy" icon={IndianRupee}>
        <ReportCard
          title="Today's Collection"
          subtitle="All payments received today"
          tone="energy"
          columns={paymentCols.collection}
          rows={dailyCollectionRows}
          csvFileName={`daily_collection_${stamp(now)}.csv`}
          csvFooterLines={["", `,,,,,GRAND TOTAL (₹),${dailyCollectionGrand.toFixed(0)}`]}
        />
        <ReportCard
          title="Monthly Collection"
          subtitle="All payments received this month"
          tone="energy"
          columns={paymentCols.collection}
          rows={monthlyCollectionRows}
          csvFileName={`monthly_collection_${stamp(now)}.csv`}
          csvFooterLines={["", `,,,,,GRAND TOTAL (₹),${monthlyCollectionGrand.toFixed(0)}`]}
        />
        <ReportCard
          title="Pending Renewals / Dues"
          subtitle="Expired members who have not renewed"
          tone="energy"
          columns={paymentCols.pendingRenewals}
          rows={pendingRenewalsRows}
          csvFileName={`pending_renewals_${stamp(now)}.csv`}
        />
        <ReportCard
          title="Revenue by Pass Type"
          subtitle="Total revenue breakdown per pass"
          tone="energy"
          columns={paymentCols.revenueByPass}
          rows={revenueByPassRows}
          csvFileName={`revenue_by_pass_${stamp(now)}.csv`}
          csvFooterLines={["", `,,GRAND TOTAL (₹),${revenueByPassGrand.toFixed(0)}`]}
        />
        <ReportCard
          title="Installment Payment Log"
          subtitle="Every individual payment entry recorded"
          tone="energy"
          columns={paymentCols.installmentLog}
          rows={installmentLogRows}
          csvFileName={`installment_log_${stamp(now)}.csv`}
        />
        <ReportCard
          title="Outstanding Balances"
          subtitle="Members who still have a pending balance"
          tone="energy"
          columns={paymentCols.outstanding}
          rows={outstandingBalancesRows}
          csvFileName={`outstanding_balances_${stamp(now)}.csv`}
          csvFooterLines={["", `,,,,,TOTAL OUTSTANDING (₹),${outstandingTotal.toFixed(0)}`]}
        />
        <ReportCard
          title="Actual Monthly Collections"
          subtitle="Real cash received this month via payments table"
          tone="energy"
          columns={paymentCols.actualMonthly}
          rows={actualMonthlyRows}
          csvFileName={`actual_monthly_collection_${stamp(now)}.csv`}
          csvFooterLines={["", `,,,TOTAL COLLECTED (₹),${actualMonthlyTotal.toFixed(0)}`]}
        />
      </Section>

      <Section title="Attendance Reports" tone="aqua" icon={UserCheck}>
        <ReportCard
          title="Today's Attendance"
          subtitle="All check-ins logged today"
          tone="aqua"
          columns={attendanceCols.daily}
          rows={dailyAttendanceRows}
          csvFileName={`daily_attendance_${stamp(now)}.csv`}
          csvFooterLines={["", `Total Check-ins: ${dailyAttendanceRows.length}`]}
        />
        <ReportCard
          title="Monthly Attendance"
          subtitle="Every check-in this month"
          tone="aqua"
          columns={attendanceCols.monthly}
          rows={monthlyAttendanceRows}
          csvFileName={`monthly_attendance_${stamp(now)}.csv`}
          csvFooterLines={["", `Total Check-ins This Month: ${monthlyAttendanceRows.length}`]}
        />
        <ReportCard
          title="Member Visit Frequency"
          subtitle="Total all-time visits per member"
          tone="aqua"
          columns={attendanceCols.visitFrequency}
          rows={visitFrequencyRows}
          csvFileName={`visit_frequency_${stamp(now)}.csv`}
        />
        <ReportCard
          title="Inactive Members (30 Days)"
          subtitle="Active members with no visit in 30 days"
          tone="aqua"
          columns={attendanceCols.inactive}
          rows={inactiveMembersRows}
          csvFileName={`inactive_members_${stamp(now)}.csv`}
          csvFooterLines={["", `Total Inactive: ${inactiveMembersRows.length}`]}
        />
      </Section>

      <Section title="Lead & Inquiry Reports" tone="pulse" icon={UserSearch}>
        <div className="col-span-full rounded-[20px] border border-border bg-card p-6 text-center shadow-sm">
          <span className="mx-auto mb-3 grid size-10 place-items-center rounded-full bg-pulse/12">
            <UserSearch className="size-5 text-pulse" />
          </span>
          <div className="font-display text-[15px] font-bold">Coming Soon</div>
          <p className="mx-auto mt-1.5 max-w-md text-[12.5px] leading-relaxed text-muted-foreground">
            Lead & Inquiry tracking is coming soon. This will include new inquiries, follow-ups, trial members and
            conversion rates.
          </p>
        </div>
      </Section>
    </div>
  );
}

function SnapshotStat({ label, value, format }: { label: string; value: number; format?: "inr" }) {
  return (
    <div className="card-hover rounded-[20px] border border-border bg-card p-4 shadow-sm">
      <div className="text-[9.5px] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{label}</div>
      <div className="num mt-2 font-display text-[19px] font-bold">
        <CountUp value={value} format={format} />
      </div>
    </div>
  );
}

const SECTION_TONE_CLASSES = {
  brand: "bg-brand/12 text-brand",
  energy: "bg-energy/12 text-energy",
  aqua: "bg-aqua/12 text-aqua",
  pulse: "bg-pulse/12 text-pulse",
} as const;

function Section({
  title,
  tone,
  icon: Icon,
  children,
}: {
  title: string;
  tone: keyof typeof SECTION_TONE_CLASSES;
  icon: React.ComponentType<{ className?: string }>;
  children: React.ReactNode;
}) {
  return (
    <div className="mb-6">
      <div className="mb-3.5 flex items-center gap-2.5">
        <span className={`grid size-8 place-items-center rounded-lg ${SECTION_TONE_CLASSES[tone]}`}>
          <Icon className="size-4" />
        </span>
        <h2 className="font-display text-[17px] font-bold">{title}</h2>
      </div>
      <div className="grid items-start grid-cols-1 gap-3.5 md:grid-cols-2 xl:grid-cols-3">{children}</div>
    </div>
  );
}

// ── column definitions (kept outside the component body - static, never re-created) ──

const membershipCols = {
  active: [
    { header: "Member Name", kind: "text" },
    { header: "Phone", kind: "phone" },
    { header: "Pass Type", kind: "text" },
    { header: "Price (₹)", kind: "currency" },
    { header: "Joined", kind: "date" },
    { header: "Expiry", kind: "date" },
    { header: "Days Left", kind: "number" },
  ],
  expired: [
    { header: "Member Name", kind: "text" },
    { header: "Phone", kind: "phone" },
    { header: "Pass Type", kind: "text" },
    { header: "Price (₹)", kind: "currency" },
    { header: "Expired On", kind: "date" },
    { header: "Days Since Expiry", kind: "number" },
  ],
  upcoming: [
    { header: "Member Name", kind: "text" },
    { header: "Phone", kind: "phone" },
    { header: "Pass Type", kind: "text" },
    { header: "Expiry Date", kind: "date" },
    { header: "Days Left", kind: "number" },
  ],
  newAdmissions: [
    { header: "Member Name", kind: "text" },
    { header: "Phone", kind: "phone" },
    { header: "Pass Type", kind: "text" },
    { header: "Price (₹)", kind: "currency" },
    { header: "Join Date", kind: "date" },
    { header: "Expiry Date", kind: "date" },
  ],
  typeWise: [
    { header: "Pass Type", kind: "text" },
    { header: "Price (₹)", kind: "currency" },
    { header: "Active", kind: "number" },
    { header: "Expired", kind: "number" },
    { header: "Total", kind: "number" },
  ],
  genderWise: [
    { header: "Member Name", kind: "text" },
    { header: "Phone", kind: "phone" },
    { header: "Gender", kind: "text" },
    { header: "Pass Type", kind: "text" },
  ],
} satisfies Record<string, ReportColumn[]>;

const paymentCols = {
  collection: [
    { header: "Member Name", kind: "text" },
    { header: "Phone", kind: "phone" },
    { header: "Pass Type", kind: "text" },
    { header: "New Sub (₹)", kind: "currency" },
    { header: "Installments (₹)", kind: "currency" },
    { header: "Total (₹)", kind: "currency" },
  ],
  pendingRenewals: [
    { header: "Member Name", kind: "text" },
    { header: "Phone", kind: "phone" },
    { header: "Last Pass", kind: "text" },
    { header: "Last Price (₹)", kind: "currency" },
    { header: "Expired On", kind: "date" },
    { header: "Days Overdue", kind: "number" },
  ],
  revenueByPass: [
    { header: "Pass Type", kind: "text" },
    { header: "Price (₹)", kind: "currency" },
    { header: "Subscriptions", kind: "number" },
    { header: "Total Revenue (₹)", kind: "currency" },
  ],
  installmentLog: [
    { header: "Member Name", kind: "text" },
    { header: "Phone", kind: "phone" },
    { header: "Pass Type", kind: "text" },
    { header: "Amount (₹)", kind: "currency" },
    { header: "Method", kind: "text" },
    { header: "Date", kind: "date" },
    { header: "Note", kind: "text" },
  ],
  outstanding: [
    { header: "Member Name", kind: "text" },
    { header: "Phone", kind: "phone" },
    { header: "Pass Type", kind: "text" },
    { header: "Total Fee (₹)", kind: "currency" },
    { header: "Paid (₹)", kind: "currency" },
    { header: "Balance (₹)", kind: "currency" },
  ],
  actualMonthly: [
    { header: "Member Name", kind: "text" },
    { header: "Phone", kind: "phone" },
    { header: "Pass Type", kind: "text" },
    { header: "Amount (₹)", kind: "currency" },
    { header: "Method", kind: "text" },
    { header: "Date", kind: "date" },
  ],
} satisfies Record<string, ReportColumn[]>;

const attendanceCols = {
  daily: [
    { header: "Member Name", kind: "text" },
    { header: "Phone", kind: "phone" },
    { header: "Check-in Time", kind: "date" },
  ],
  monthly: [
    { header: "Member Name", kind: "text" },
    { header: "Phone", kind: "phone" },
    { header: "Date", kind: "date" },
    { header: "Time", kind: "date" },
  ],
  visitFrequency: [
    { header: "Member Name", kind: "text" },
    { header: "Phone", kind: "phone" },
    { header: "Total Visits", kind: "number" },
    { header: "Last Visit", kind: "date" },
  ],
  inactive: [
    { header: "Member Name", kind: "text" },
    { header: "Phone", kind: "phone" },
    { header: "Pass Type", kind: "text" },
    { header: "Status", kind: "text" },
  ],
} satisfies Record<string, ReportColumn[]>;
