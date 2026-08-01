"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { CalendarRange, ChevronLeft, ChevronRight, Check } from "lucide-react";

function toYMD(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
function parseYMD(s: string) {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}
function addDays(s: string, n: number) {
  const d = parseYMD(s);
  d.setDate(d.getDate() + n);
  return toYMD(d);
}
function prettyDate(s: string) {
  return parseYMD(s).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
}

type Preset = { label: string; range: () => { from: string; to: string } };

function buildPresets(today: string): Preset[] {
  const now = parseYMD(today);
  const monthStart = toYMD(new Date(now.getFullYear(), now.getMonth(), 1));
  return [
    { label: "Last 7 Days", range: () => ({ from: addDays(today, -6), to: today }) },
    { label: "Last 30 Days", range: () => ({ from: addDays(today, -29), to: today }) },
    { label: "This Month", range: () => ({ from: monthStart, to: today }) },
    {
      label: "Last Month",
      range: () => {
        const lastMonthEnd = new Date(now.getFullYear(), now.getMonth(), 0);
        const lastMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        return { from: toYMD(lastMonthStart), to: toYMD(lastMonthEnd) };
      },
    },
  ];
}

export function DateRangePicker({
  from,
  to,
  today,
  basePath,
}: {
  from: string;
  to: string;
  today: string;
  basePath: string;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [pendingFrom, setPendingFrom] = useState(from);
  const [pendingTo, setPendingTo] = useState<string | null>(to);
  const [selecting, setSelecting] = useState(false);
  const [hoverDay, setHoverDay] = useState<string | null>(null);
  const [viewMonth, setViewMonth] = useState(() => {
    const d = parseYMD(to);
    return new Date(d.getFullYear(), d.getMonth(), 1);
  });

  const presets = useMemo(() => buildPresets(today), [today]);

  function apply(nextFrom: string, nextTo: string) {
    const ordered = nextFrom <= nextTo ? [nextFrom, nextTo] : [nextTo, nextFrom];
    router.push(`${basePath}?from=${ordered[0]}&to=${ordered[1]}`);
    setOpen(false);
    setSelecting(false);
  }

  function openPicker() {
    setPendingFrom(from);
    setPendingTo(to);
    setSelecting(false);
    setViewMonth(() => {
      const d = parseYMD(to);
      return new Date(d.getFullYear(), d.getMonth(), 1);
    });
    setOpen(true);
  }

  function pickDay(day: string) {
    if (!selecting) {
      setPendingFrom(day);
      setPendingTo(null);
      setSelecting(true);
      return;
    }
    setPendingTo(day);
    setSelecting(false);
  }

  const rangeStart = pendingFrom;
  const rangeEnd = pendingTo ?? (selecting ? hoverDay : pendingTo) ?? pendingFrom;
  const [lo, hi] = rangeStart <= (rangeEnd ?? rangeStart) ? [rangeStart, rangeEnd ?? rangeStart] : [rangeEnd ?? rangeStart, rangeStart];

  const weeks = useMemo(() => {
    const year = viewMonth.getFullYear();
    const month = viewMonth.getMonth();
    const first = new Date(year, month, 1);
    const startOffset = first.getDay();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const cells: (string | null)[] = Array.from({ length: startOffset }, () => null);
    for (let d = 1; d <= daysInMonth; d++) cells.push(toYMD(new Date(year, month, d)));
    while (cells.length % 7 !== 0) cells.push(null);
    const rows: (string | null)[][] = [];
    for (let i = 0; i < cells.length; i += 7) rows.push(cells.slice(i, i + 7));
    return rows;
  }, [viewMonth]);

  return (
    <div className="relative">
      <button
        type="button"
        onClick={() => (open ? setOpen(false) : openPicker())}
        className="flex items-center gap-2 rounded-xl border border-border bg-card px-3.5 py-2.5 text-[13px] font-bold"
      >
        <CalendarRange className="size-4 text-brand" />
        {prettyDate(from)} – {prettyDate(to)}
      </button>

      {open && (
        <>
          <div className="fixed inset-0 z-20" onClick={() => setOpen(false)} />
          <div className="absolute right-0 z-30 mt-2 flex w-[300px] flex-col gap-3 rounded-[20px] border border-border bg-card p-4 shadow-xl animate-[panel-fade_0.15s_ease-out] sm:w-[340px]">
            <div className="flex flex-wrap gap-1.5">
              {presets.map((p) => (
                <button
                  key={p.label}
                  type="button"
                  onClick={() => {
                    const r = p.range();
                    apply(r.from, r.to);
                  }}
                  className="rounded-full border border-border px-2.5 py-1.5 text-[11.5px] font-semibold text-muted-foreground transition-colors hover:border-brand hover:text-brand"
                >
                  {p.label}
                </button>
              ))}
            </div>

            <div className="flex items-center justify-between">
              <button
                type="button"
                aria-label="Previous month"
                onClick={() => setViewMonth((m) => new Date(m.getFullYear(), m.getMonth() - 1, 1))}
                className="grid size-7 place-items-center rounded-lg border border-border"
              >
                <ChevronLeft className="size-3.5" />
              </button>
              <span className="font-display text-[13px] font-bold">
                {viewMonth.toLocaleDateString("en-GB", { month: "long", year: "numeric" })}
              </span>
              <button
                type="button"
                aria-label="Next month"
                onClick={() => setViewMonth((m) => new Date(m.getFullYear(), m.getMonth() + 1, 1))}
                className="grid size-7 place-items-center rounded-lg border border-border"
              >
                <ChevronRight className="size-3.5" />
              </button>
            </div>

            <div>
              <div className="grid grid-cols-7 gap-1 text-center text-[10px] font-bold uppercase text-muted-foreground">
                {["S", "M", "T", "W", "T", "F", "S"].map((d, i) => (
                  <span key={i}>{d}</span>
                ))}
              </div>
              <div className="mt-1 flex flex-col gap-1">
                {weeks.map((week, wi) => (
                  <div key={wi} className="grid grid-cols-7 gap-1">
                    {week.map((day, di) => {
                      if (!day) return <span key={di} />;
                      const isFuture = day > today;
                      const inRange = day >= lo && day <= hi;
                      const isEndpoint = day === pendingFrom || day === pendingTo;
                      return (
                        <button
                          key={di}
                          type="button"
                          disabled={isFuture}
                          onClick={() => pickDay(day)}
                          onMouseEnter={() => setHoverDay(day)}
                          className={`num relative grid h-8 place-items-center rounded-lg text-[12px] font-semibold transition-colors disabled:opacity-25 ${
                            isEndpoint
                              ? "bg-brand text-on-brand"
                              : inRange
                                ? "bg-brand/15 text-brand"
                                : "text-foreground hover:bg-muted"
                          }`}
                        >
                          {parseYMD(day).getDate()}
                        </button>
                      );
                    })}
                  </div>
                ))}
              </div>
            </div>

            <div className="flex items-center justify-between border-t border-border pt-3 text-[11.5px] text-muted-foreground">
              <span>
                {selecting ? "Pick the end date…" : `${prettyDate(pendingFrom)} – ${pendingTo ? prettyDate(pendingTo) : "?"}`}
              </span>
              {pendingTo && (
                <button
                  type="button"
                  onClick={() => apply(pendingFrom, pendingTo)}
                  className="flex items-center gap-1 font-bold text-brand"
                >
                  <Check className="size-3.5" /> Apply
                </button>
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
