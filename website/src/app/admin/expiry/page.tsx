import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { nowInIST } from "@/lib/ist-time";
import { ExpiryTable, type ExpiryRow } from "@/components/admin/expiry-table";
import { ExpiryExportButton } from "@/components/admin/expiry-export-button";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Expiry Alerts — Vishal Fitness Admin",
};

// One failing query never takes down the whole page. Errors are still
// logged (not just swallowed) so a genuine query failure is distinguishable
// from real zero rows in server logs.
async function safeSelect<T>(promise: PromiseLike<{ data: T[] | null; error: unknown }>) {
  try {
    const { data, error } = await promise;
    if (error) {
      console.error("expiry/page: query failed:", error);
      return [] as T[];
    }
    return data ?? ([] as T[]);
  } catch (err) {
    console.error("expiry/page: query threw:", err);
    return [] as T[];
  }
}

type Pass = { id: string; name: string; price: number; duration_days: number };

type SubRow = {
  id: string;
  user_id: string | null;
  start_date: string | null;
  end_date: string | null;
  profiles: { full_name: string | null; phone: string | null } | null;
  gym_passes: { name: string | null; price: number | null } | null;
};

function toYMD(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
function parseYMD(s: string) {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}
function prettyDate(s: string) {
  return parseYMD(s).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
}
function isValidYMD(s: string) {
  return /^\d{4}-\d{2}-\d{2}$/.test(s);
}
// Supabase returns `date` columns as "YYYY-MM-DD" but `timestamp`/`timestamptz`
// columns as a full ISO string — normalize either to a bare date so we never
// silently misread a real stored date.
function normalizeYMD(s: string | null | undefined) {
  if (!s) return "";
  const sliced = s.slice(0, 10);
  return isValidYMD(sliced) ? sliced : "";
}
// Mirrors _daysLeft() in admin_expiry_screen.dart: whole calendar days between
// two date-only values (no time-of-day component).
function daysLeft(endYMD: string, todayYMD: string) {
  return Math.round((parseYMD(endYMD).getTime() - parseYMD(todayYMD).getTime()) / 86_400_000);
}

export default async function ExpiryPage() {
  const supabase = await createClient();
  // Server may run in a different timezone than the gym (Vercel defaults to
  // UTC) — see src/lib/ist-time.ts. toYMD() only reads local calendar
  // getters here, so nowInIST() is safe (no real-instant/.getTime() use).
  const todayYMD = toYMD(nowInIST());

  const [subs, passes] = await Promise.all([
    safeSelect(
      supabase
        .from("subscriptions")
        .select(
          `id, user_id, start_date, end_date,
           profiles:user_id ( full_name, phone ),
           gym_passes:pass_id ( name, price )`,
        )
        .order("end_date", { ascending: true })
        .returns<SubRow[]>(),
    ),
    safeSelect<Pass>(
      supabase
        .from("gym_passes")
        .select("id, name, price, duration_days")
        .eq("is_active", true)
        .order("duration_days", { ascending: true }),
    ),
  ]);

  // Mirrors _categoryOf()/_daysLeft() in admin_expiry_screen.dart. A row with
  // no usable end_date can't be bucketed — skip it rather than crash (the
  // Dart screen assumes end_date is always present).
  const rows: ExpiryRow[] = subs
    .map((s): ExpiryRow | null => {
      const endYMD = normalizeYMD(s.end_date);
      if (!endYMD) return null;
      const startYMD = normalizeYMD(s.start_date);
      const days = daysLeft(endYMD, todayYMD);
      const category = days < 0 ? "expired" : days <= 7 ? "critical" : days <= 30 ? "expiring" : "healthy";
      return {
        subscriptionId: s.id,
        userId: s.user_id,
        name: s.profiles?.full_name ?? "Unknown",
        phone: s.profiles?.phone ?? "",
        passName: s.gym_passes?.name ?? "—",
        passPrice: s.gym_passes?.price ?? null,
        startDate: startYMD,
        endDate: endYMD,
        formattedStart: startYMD ? prettyDate(startYMD) : "—",
        formattedEnd: prettyDate(endYMD),
        days,
        category,
        statusLabel: days < 0 ? `${-days}d overdue` : `${days} days left`,
      };
    })
    .filter((r): r is ExpiryRow => r !== null);

  return (
    <div>
      <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <Link href="/admin" className="grid size-9 place-items-center rounded-xl border border-border bg-card" aria-label="Back">
            <ArrowLeft className="size-4" />
          </Link>
          <h1 className="font-display text-[26px] font-bold leading-none">Expiry Alerts</h1>
        </div>
        <ExpiryExportButton rows={rows} />
      </div>

      <ExpiryTable rows={rows} passes={passes} />
    </div>
  );
}
