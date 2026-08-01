import Link from "next/link";
import { ChevronRight, Receipt } from "lucide-react";
import { formatINR } from "@/lib/format";

export type DayRevenueRow = { date: string; label: string; amount: number; count: number };

// Plain server-rendered list - the staggered reveal is pure CSS (animation-delay
// per row via inline style), so no client JS is needed just to animate it in.
export function DayWiseRevenueList({ days }: { days: DayRevenueRow[] }) {
  if (days.length === 0) {
    return (
      <div className="flex flex-col items-center gap-3 rounded-[20px] border border-border bg-card px-6 py-16 text-center">
        <Receipt className="size-9 text-muted-foreground" />
        <p className="text-[13px] text-muted-foreground">No days in this range yet.</p>
      </div>
    );
  }

  const max = Math.max(1, ...days.map((d) => d.amount));

  return (
    <div className="flex flex-col gap-2">
      {days.map((day, i) => {
        const pct = Math.round((day.amount / max) * 100);
        return (
          <Link
            key={day.date}
            href={`/admin/daily-revenue/${day.date}`}
            style={{ animationDelay: `${Math.min(i, 20) * 30}ms` }}
            className="group relative flex animate-[panel-fade_0.4s_ease-out_both] items-center gap-4 overflow-hidden rounded-2xl border border-border bg-card px-4 py-3.5 transition-colors hover:border-brand/40"
          >
            <div
              className="absolute inset-y-0 left-0 bg-brand/[0.06] transition-[width] duration-700 ease-[cubic-bezier(0.16,1,0.3,1)] group-hover:bg-brand/[0.1]"
              style={{ width: `${pct}%` }}
              aria-hidden
            />
            <div className="relative min-w-0 flex-1">
              <div className="font-display text-[14px] font-bold">{day.label}</div>
              <div className="text-[11.5px] text-muted-foreground">
                {day.count} payment{day.count === 1 ? "" : "s"}
              </div>
            </div>
            <div className="num relative font-display text-[16px] font-bold text-brand">{formatINR(day.amount)}</div>
            <ChevronRight className="relative size-4 shrink-0 text-muted-foreground transition-transform group-hover:translate-x-0.5" />
          </Link>
        );
      })}
    </div>
  );
}
