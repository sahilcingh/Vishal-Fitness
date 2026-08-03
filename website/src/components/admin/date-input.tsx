"use client";

import { useMemo, useState } from "react";
import { CalendarDays, ChevronLeft, ChevronRight } from "lucide-react";

function toYMD(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
function parseYMD(s: string) {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}
function isValidYMD(s: string) {
  return /^\d{4}-\d{2}-\d{2}$/.test(s);
}
function prettyDMY(s: string) {
  const d = parseYMD(s);
  return `${String(d.getDate()).padStart(2, "0")}-${String(d.getMonth() + 1).padStart(2, "0")}-${d.getFullYear()}`;
}

// Native `<input type="date">` renders its displayed format (dd/mm vs mm/dd)
// according to the visiting admin's own OS/browser regional settings - there
// is no reliable page-level override (confirmed: `lang="en-GB"` on the input
// made no difference in a simulated different-locale browser). This never
// delegates rendering to the native control, so the format is always
// dd-mm-yyyy for every admin regardless of their machine's settings.
export function DateInput({
  value,
  onChange,
  min,
  max,
  className,
  placeholder = "dd-mm-yyyy",
  showIcon = true,
}: {
  value: string;
  onChange: (v: string) => void;
  min?: string;
  max?: string;
  className?: string;
  placeholder?: string;
  showIcon?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [viewMonth, setViewMonth] = useState(() => {
    const base = isValidYMD(value) ? parseYMD(value) : new Date();
    return new Date(base.getFullYear(), base.getMonth(), 1);
  });

  function openPicker() {
    const base = isValidYMD(value) ? parseYMD(value) : new Date();
    setViewMonth(new Date(base.getFullYear(), base.getMonth(), 1));
    setOpen(true);
  }

  function pickDay(day: string) {
    onChange(day);
    setOpen(false);
  }

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
        className={`${className ?? ""} flex items-center justify-between gap-2`}
      >
        <span className={isValidYMD(value) ? "" : "font-normal text-muted-foreground/60"}>
          {isValidYMD(value) ? prettyDMY(value) : placeholder}
        </span>
        {showIcon && <CalendarDays className="size-4 shrink-0 text-muted-foreground" />}
      </button>

      {open && (
        <>
          <div className="fixed inset-0 z-20" onClick={() => setOpen(false)} />
          <div className="absolute left-0 z-30 mt-2 flex w-[280px] flex-col gap-3 rounded-[20px] border border-border bg-card p-4 shadow-xl animate-[panel-fade_0.15s_ease-out]">
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
                      const isDisabled = (!!max && day > max) || (!!min && day < min);
                      const isSelected = day === value;
                      return (
                        <button
                          key={di}
                          type="button"
                          disabled={isDisabled}
                          onClick={() => pickDay(day)}
                          className={`num relative grid h-8 place-items-center rounded-lg text-[12px] font-semibold transition-colors disabled:opacity-25 ${
                            isSelected ? "bg-brand text-on-brand" : "text-foreground hover:bg-muted"
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
          </div>
        </>
      )}
    </div>
  );
}
