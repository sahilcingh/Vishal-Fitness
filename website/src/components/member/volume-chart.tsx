"use client";

import { useState } from "react";

export type VolumeDay = { short: string; full: string; volume: number };

// Hand-rolled bar chart, same pattern as admin/revenue-chart.tsx (plain divs,
// no charting library — one was tried earlier in this project and dropped
// for a React 19 peer-dependency conflict).
export function VolumeChart({ days }: { days: VolumeDay[] }) {
  const [hovered, setHovered] = useState<number | null>(null);
  const max = Math.max(1, ...days.map((d) => d.volume));

  return (
    <div className="flex h-24 items-end gap-1">
      {days.map((day, i) => {
        const pct = Math.round((day.volume / max) * 100);
        return (
          <div
            key={i}
            tabIndex={0}
            role="img"
            aria-label={`${day.full}: ${Math.round(day.volume).toLocaleString("en-IN")} kg`}
            className="relative flex h-full flex-1 flex-col items-end justify-end gap-1.5 outline-none focus-visible:ring-2 focus-visible:ring-brand"
            onMouseEnter={() => setHovered(i)}
            onMouseLeave={() => setHovered(null)}
            onFocus={() => setHovered(i)}
            onBlur={() => setHovered(null)}
          >
            {hovered === i && (
              <div className="absolute bottom-[calc(100%+8px)] left-1/2 z-10 -translate-x-1/2 whitespace-nowrap rounded-lg border border-border bg-card px-2.5 py-1.5 text-[11px] shadow-lg">
                {day.full} · <span className="num font-bold text-brand">{Math.round(day.volume).toLocaleString("en-IN")} kg</span>
              </div>
            )}
            <div
              className={`w-full max-w-[16px] rounded-t-md transition-colors ${
                day.volume > 0 ? "bg-brand/70 hover:bg-brand" : "bg-border/60"
              }`}
              style={{ height: `${day.volume > 0 ? Math.max(pct, 4) : 4}%` }}
            />
            <div className="pt-1 text-[9px] font-semibold uppercase text-muted-foreground">{day.short}</div>
          </div>
        );
      })}
    </div>
  );
}
