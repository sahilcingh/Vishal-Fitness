"use client";

import { useState } from "react";
import Link from "next/link";
import { formatINR, formatINRCompact } from "@/lib/format";

export type RevenueDay = { label: string; date: string; amount: number };

// `today` is passed in (rather than inferred from array position) so "today"
// stays correct regardless of which month is being viewed - the selected
// month's last entry isn't necessarily today once a past month is picked.
export function RevenueChart({ days, today }: { days: RevenueDay[]; today: string }) {
  const [hovered, setHovered] = useState<number | null>(null);

  const max = Math.max(1, ...days.map((d) => d.amount));

  return (
    <div className="overflow-x-auto">
      <div className="flex h-[170px] min-w-[560px] items-end gap-1">
        {days.map((day, i) => {
          const isToday = day.date === today;
          const hasRevenue = day.amount > 0;
          // Zero-revenue days still get a thin visible baseline tick (in a
          // muted tone) instead of collapsing to nothing - a day with no
          // revenue is still a real day, not blank space in the chart. Fixed
          // px height + minimal radius here (rather than a % height with the
          // same rounded-t-md as real bars) so it reads as a flat tick, not a
          // floating pill - a % height that small combined with a 6px corner
          // radius rounds away the whole shape.
          const pct = Math.max(Math.round((day.amount / max) * 100), 4);
          const heightStyle = hasRevenue ? `${pct}%` : "4px";
          return (
            <Link
              key={day.date}
              href={`/admin/daily-revenue/${day.date}`}
              aria-label={`${day.label}: ${formatINR(day.amount)} - view this day's data`}
              className="group relative flex h-full flex-1 flex-col items-center justify-end gap-1 outline-none"
              onMouseEnter={() => setHovered(i)}
              onMouseLeave={() => setHovered(null)}
              onFocus={() => setHovered(i)}
              onBlur={() => setHovered(null)}
            >
              {isToday && (
                <span className="absolute -top-5 whitespace-nowrap text-[8px] font-bold tracking-wide text-brand">TODAY</span>
              )}
              {hovered === i && (
                <div className="absolute bottom-[calc(100%+10px)] z-10 whitespace-nowrap rounded-lg border border-border bg-card px-2.5 py-1.5 text-[11.5px] shadow-lg">
                  {day.label} · <span className="num font-bold text-brand">{formatINR(day.amount)}</span>
                </div>
              )}
              <div className={`num text-[8px] font-bold ${hasRevenue ? "text-brand" : "text-transparent"}`}>
                {hasRevenue ? formatINRCompact(day.amount) : "0"}
              </div>
              <div
                className={`w-full max-w-[18px] transition-[background-color,height] duration-700 ease-[cubic-bezier(0.16,1,0.3,1)] group-hover:opacity-80 ${
                  hasRevenue ? "rounded-t-md" : "rounded-t-[2px]"
                } ${isToday ? "bg-brand" : hasRevenue ? "bg-brand/25" : "bg-muted-foreground/20"}`}
                style={{ height: heightStyle }}
              />
              <div className="num h-3 text-[8px] font-semibold text-muted-foreground">{day.label}</div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
