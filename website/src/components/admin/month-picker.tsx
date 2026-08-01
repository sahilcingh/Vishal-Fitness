"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { CalendarDays, ChevronLeft, ChevronRight } from "lucide-react";
import { Modal } from "@/components/admin/modal";

const MONTH_ABBR = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function shiftMonthKey(monthKey: string, delta: number) {
  const [y, m] = monthKey.split("-").map(Number);
  const d = new Date(y, m - 1 + delta, 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

function monthLabel(monthKey: string) {
  const [y, m] = monthKey.split("-").map(Number);
  return new Date(y, m - 1, 1).toLocaleDateString("en-GB", { month: "long", year: "numeric" });
}

export function MonthPicker({
  month,
  currentMonth,
  basePath,
}: {
  month: string;
  currentMonth: string;
  basePath: string;
}) {
  const router = useRouter();
  const isCurrentMonth = month === currentMonth;

  const [open, setOpen] = useState(false);
  const selYear = Number(month.split("-")[0]);
  const selMonth1 = Number(month.split("-")[1]);
  const [year, setYear] = useState(selYear);
  const currentYear = Number(currentMonth.split("-")[0]);
  const currentMonthIndex = Number(currentMonth.split("-")[1]) - 1;

  function go(nextMonthKey: string) {
    router.push(`${basePath}?month=${nextMonthKey}`);
  }

  function openPicker() {
    setYear(selYear);
    setOpen(true);
  }

  function pickMonth(monthIndex0: number) {
    go(`${year}-${String(monthIndex0 + 1).padStart(2, "0")}`);
    setOpen(false);
  }

  return (
    <>
      <div className="flex items-center gap-1">
        <button
          type="button"
          onClick={() => go(shiftMonthKey(month, -1))}
          aria-label="Previous month"
          className="grid size-6 shrink-0 place-items-center rounded-md text-white/70 transition-colors hover:bg-white/10 hover:text-white"
        >
          <ChevronLeft className="size-3.5" />
        </button>

        <button
          type="button"
          onClick={openPicker}
          aria-label={`Change month, currently ${monthLabel(month)}`}
          className="flex items-center gap-1.5 rounded-md border border-white/15 bg-white/5 px-2.5 py-1 text-[11px] font-bold text-white/85 transition-colors hover:border-white/30 hover:bg-white/15"
        >
          <CalendarDays className="size-3.5 text-white/60" />
          {monthLabel(month)}
        </button>

        <button
          type="button"
          onClick={() => go(shiftMonthKey(month, 1))}
          disabled={isCurrentMonth}
          aria-label="Next month"
          className="grid size-6 shrink-0 place-items-center rounded-md text-white/70 transition-colors hover:bg-white/10 hover:text-white disabled:opacity-30 disabled:hover:bg-transparent"
        >
          <ChevronRight className="size-3.5" />
        </button>
      </div>

      {/* A centered modal (the app's existing dialog pattern) rather than an
          anchored dropdown - an absolutely-positioned popover anchored to
          this small inline trigger looked fine on desktop but landed in a
          broken spot on narrow mobile widths, overlapping the card behind it. */}
      <Modal open={open} onClose={() => setOpen(false)} maxWidthClass="max-w-[280px]">
        <div className="mb-3.5 flex items-center justify-between">
          <button
            type="button"
            onClick={() => setYear((y) => y - 1)}
            aria-label="Previous year"
            className="grid size-8 place-items-center rounded-lg border border-border text-muted-foreground"
          >
            <ChevronLeft className="size-4" />
          </button>
          <span className="font-display text-[16px] font-bold">{year}</span>
          <button
            type="button"
            onClick={() => setYear((y) => y + 1)}
            disabled={year >= currentYear}
            aria-label="Next year"
            className="grid size-8 place-items-center rounded-lg border border-border text-muted-foreground disabled:opacity-30"
          >
            <ChevronRight className="size-4" />
          </button>
        </div>
        <div className="grid grid-cols-3 gap-2">
          {MONTH_ABBR.map((label, i) => {
            const disabled = year === currentYear && i > currentMonthIndex;
            const isSelected = year === selYear && i === selMonth1 - 1;
            return (
              <button
                key={label}
                type="button"
                disabled={disabled}
                onClick={() => pickMonth(i)}
                className={`rounded-lg py-2.5 text-[13px] font-semibold transition-colors disabled:opacity-30 ${
                  isSelected ? "bg-brand text-on-brand" : "hover:bg-muted"
                }`}
              >
                {label}
              </button>
            );
          })}
        </div>
      </Modal>
    </>
  );
}
