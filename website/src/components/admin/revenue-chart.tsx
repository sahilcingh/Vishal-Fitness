"use client";

import { useState } from "react";
import { formatINR } from "@/lib/format";

export type RevenueDay = { label: string; date: string; amount: number };

export function RevenueChart({ days }: { days: RevenueDay[] }) {
  const [hovered, setHovered] = useState<number | null>(null);
  const max = Math.max(1, ...days.map((d) => d.amount));

  return (
    <div className="flex h-[150px] items-end gap-1.5">
      {days.map((day, i) => {
        const isToday = i === days.length - 1;
        const showLabel = i === 0 || i === Math.floor(days.length / 2) || isToday;
        const pct = Math.round((day.amount / max) * 100);
        return (
          <div
            key={day.date}
            tabIndex={0}
            aria-label={`${day.label}: ${formatINR(day.amount)}`}
            className="relative flex h-full flex-1 flex-col items-center justify-end gap-2 outline-none"
            onMouseEnter={() => setHovered(i)}
            onMouseLeave={() => setHovered(null)}
            onFocus={() => setHovered(i)}
            onBlur={() => setHovered(null)}
          >
            {isToday && (
              <span className="absolute -top-5 text-[8.5px] font-bold tracking-wide text-brand">TODAY</span>
            )}
            {hovered === i && (
              <div className="absolute bottom-[calc(100%+10px)] z-10 whitespace-nowrap rounded-lg border border-border bg-card px-2.5 py-1.5 text-[11.5px] shadow-lg">
                {day.label} · <span className="num font-bold text-brand">{formatINR(day.amount)}</span>
              </div>
            )}
            <div
              className={`w-full max-w-[26px] rounded-t-md transition-colors ${
                isToday ? "bg-brand" : "bg-brand/25 hover:bg-brand/50"
              }`}
              style={{ height: `${pct}%` }}
            />
            <div className="h-3 text-[9.5px] font-semibold text-muted-foreground">
              {showLabel && !isToday ? day.label : ""}
            </div>
          </div>
        );
      })}
    </div>
  );
}
