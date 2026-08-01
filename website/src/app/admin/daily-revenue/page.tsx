import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { nowInIST } from "@/lib/ist-time";
import { DateRangePicker } from "@/components/admin/date-range-picker";
import { DayWiseRevenueList, type DayRevenueRow } from "@/components/admin/day-wise-revenue-list";
import { CountUp } from "@/components/count-up";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Revenue - Vishal Fitness Admin",
};

function toYMD(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
function parseYMD(s: string) {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}
function isValidYMD(s: string | undefined): s is string {
  return !!s && /^\d{4}-\d{2}-\d{2}$/.test(s);
}

// Mirrors _safe() elsewhere in admin/ - one failing query never takes down
// the whole page.
async function safeSelect<T>(promise: PromiseLike<{ data: T[] | null; error: unknown }>) {
  try {
    const { data, error } = await promise;
    if (error) {
      console.error("daily-revenue/page: query failed:", error);
      return [] as T[];
    }
    return data ?? ([] as T[]);
  } catch (err) {
    console.error("daily-revenue/page: query threw:", err);
    return [] as T[];
  }
}

export default async function DailyRevenuePage({
  searchParams,
}: {
  searchParams: Promise<{ from?: string; to?: string }>;
}) {
  const { from: fromParam, to: toParam } = await searchParams;
  const supabase = await createClient();

  const now = nowInIST();
  const todayYMD = toYMD(now);
  const monthStartYMD = toYMD(new Date(now.getFullYear(), now.getMonth(), 1));

  // Defaults to the current month, matching the "Revenue this month" card
  // this page is linked from - the admin can widen the range from here.
  const from = isValidYMD(fromParam) ? fromParam : monthStartYMD;
  const to = isValidYMD(toParam) && toParam <= todayYMD ? toParam : todayYMD;
  const [rangeFrom, rangeTo] = from <= to ? [from, to] : [to, from];

  const payments = await safeSelect<{ amount: number; payment_date: string }>(
    supabase.from("payments").select("amount, payment_date").gte("payment_date", rangeFrom).lte("payment_date", rangeTo),
  );

  const byDay = new Map<string, { amount: number; count: number }>();
  for (const p of payments) {
    const bucket = byDay.get(p.payment_date) ?? { amount: 0, count: 0 };
    bucket.amount += p.amount ?? 0;
    bucket.count += 1;
    byDay.set(p.payment_date, bucket);
  }

  const days: DayRevenueRow[] = [];
  const cursor = parseYMD(rangeTo);
  const start = parseYMD(rangeFrom);
  while (cursor >= start) {
    const key = toYMD(cursor);
    const bucket = byDay.get(key);
    days.push({
      date: key,
      label: cursor.toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short", year: "numeric" }),
      amount: bucket?.amount ?? 0,
      count: bucket?.count ?? 0,
    });
    cursor.setDate(cursor.getDate() - 1);
  }

  const totalRevenue = days.reduce((sum, d) => sum + d.amount, 0);

  return (
    <div>
      <div className="mb-5 flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <Link href="/admin" className="grid size-9 place-items-center rounded-xl border border-border bg-card" aria-label="Back">
            <ArrowLeft className="size-4" />
          </Link>
          <h1 className="font-display text-[26px] font-bold leading-none">Revenue</h1>
        </div>
        <DateRangePicker from={rangeFrom} to={rangeTo} today={todayYMD} basePath="/admin/daily-revenue" />
      </div>

      <div className="mb-5 rounded-[20px] border border-border bg-[linear-gradient(135deg,#141414,#242424)] p-6 text-white shadow-sm">
        <div className="text-[11px] font-semibold uppercase tracking-[0.14em] text-white/60">
          Total Revenue · {days.length} day{days.length === 1 ? "" : "s"}
        </div>
        <div className="num mt-2 font-display text-[40px] font-bold">
          <CountUp value={totalRevenue} format="inr" />
        </div>
      </div>

      <DayWiseRevenueList days={days} />
    </div>
  );
}
