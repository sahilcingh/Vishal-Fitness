"use client";

import { useState } from "react";
import { Download, Eye, EyeOff, Loader2 } from "lucide-react";
import { formatINR } from "@/lib/format";
import { Pagination, paginate } from "@/components/admin/pagination";
import { csvValue, csvForceText, downloadCsv } from "@/lib/csv-export";

const PAGE_SIZE = 25;

// Cell kinds drive both CSV formatting (matching the daily-revenue-export-button
// conventions) and inline table display:
//  - "text"     -> quoted CSV string, left-aligned
//  - "phone"    -> Excel "force text" trick so numbers/leading zeros survive, left-aligned
//  - "date"     -> same force-text trick (dates/times), left-aligned
//  - "number"   -> raw digits in CSV (so Excel can sum them), right-aligned, tabular
//  - "currency" -> raw digits in CSV, but displayed inline via formatINR()
export type CellKind = "text" | "phone" | "date" | "number" | "currency";
export type ReportColumn = { header: string; kind: CellKind };
export type ReportRow = string[];

// text-*-onlight are darkened variants that clear WCAG AA contrast on the
// light-mode card background; dark:text-* restores the brighter raw token
// for dark mode, where it already has enough contrast (see globals.css).
const TONE_CLASSES = {
  brand: "bg-brand/12 text-brand-onlight dark:text-brand",
  energy: "bg-energy/12 text-energy-onlight dark:text-energy",
  aqua: "bg-aqua/12 text-aqua-onlight dark:text-aqua",
  pulse: "bg-pulse/12 text-pulse",
} as const;

export function ReportCard({
  title,
  subtitle,
  tone,
  columns,
  rows,
  csvFileName,
  csvFooterLines,
}: {
  title: string;
  subtitle: string;
  tone: keyof typeof TONE_CLASSES;
  columns: ReportColumn[];
  rows: ReportRow[];
  csvFileName: string;
  csvFooterLines?: string[];
}) {
  const [open, setOpen] = useState(false);
  const [page, setPage] = useState(1);
  const [exporting, setExporting] = useState(false);
  const totalPages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
  const pageRows = paginate(rows, page, PAGE_SIZE);

  async function handleExport() {
    setExporting(true);
    // Without a real await between setExporting(true) and the (synchronous)
    // CSV build below, React batches both state changes into one commit and
    // the spinner never gets a chance to paint. This tick gives it one.
    await new Promise((r) => setTimeout(r, 50));
    try {
      const lines = [columns.map((c) => c.header).join(",")];
      for (const row of rows) {
        lines.push(
          row
            .map((cell, i) => {
              const kind = columns[i]?.kind ?? "text";
              if (kind === "number" || kind === "currency") return cell;
              if (kind === "phone" || kind === "date") return csvForceText(cell);
              return csvValue(cell);
            })
            .join(","),
        );
      }
      if (csvFooterLines?.length) lines.push(...csvFooterLines);
      downloadCsv(lines.join("\n"), csvFileName);
    } finally {
      setExporting(false);
    }
  }

  return (
    <div className="flex flex-col rounded-[20px] border border-border bg-card p-4 shadow-sm">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="text-[13.5px] font-bold leading-snug">{title}</div>
          <div className="mt-0.5 text-[11.5px] text-muted-foreground">{subtitle}</div>
        </div>
        <span className={`num shrink-0 rounded-full px-2.5 py-1 text-[10.5px] font-bold ${TONE_CLASSES[tone]}`}>
          {rows.length}
        </span>
      </div>

      <div className="mt-3.5 flex items-center gap-2">
        <button
          type="button"
          onClick={() => {
            const next = !open;
            setOpen(next);
            // Only reset to page 1 when opening - collapsing and reopening
            // within the same session should keep the reader's place.
            if (next) setPage(1);
          }}
          className="flex flex-1 items-center justify-center gap-1.5 rounded-lg border border-border px-3 py-2 text-[12px] font-bold text-foreground"
        >
          {open ? <EyeOff className="size-3.5" /> : <Eye className="size-3.5" />}
          {open ? "Hide" : "View"}
        </button>
        <button
          type="button"
          onClick={handleExport}
          disabled={exporting || rows.length === 0}
          className="flex flex-1 items-center justify-center gap-1.5 rounded-lg bg-brand px-3 py-2 text-[12px] font-bold text-on-brand disabled:opacity-50"
        >
          {exporting ? <Loader2 className="size-3.5 animate-spin" /> : <Download className="size-3.5" />}
          CSV
        </button>
      </div>

      {open && (
        <div className="mt-3.5 max-h-[320px] overflow-auto rounded-xl border border-border">
          {rows.length === 0 ? (
            <div className="px-4 py-8 text-center text-[12px] text-muted-foreground">No records found.</div>
          ) : (
            <table className="w-full min-w-max text-left text-[12px]">
              <thead className="sticky top-0 bg-card">
                <tr className="border-b border-border text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">
                  {columns.map((c) => (
                    <th
                      key={c.header}
                      className={`whitespace-nowrap px-3 py-2 font-semibold ${
                        c.kind === "number" || c.kind === "currency" ? "text-right" : ""
                      }`}
                    >
                      {c.header}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {pageRows.map((row, i) => (
                  <tr key={i}>
                    {row.map((cell, j) => {
                      const kind = columns[j]?.kind ?? "text";
                      const isNum = kind === "number" || kind === "currency";
                      const display = cell === "" ? "-" : kind === "currency" ? formatINR(Number(cell)) : cell;
                      return (
                        <td
                          key={j}
                          className={`whitespace-nowrap px-3 py-2 ${isNum ? "num text-right font-semibold" : ""}`}
                        >
                          {display}
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {open && <Pagination page={page} totalPages={totalPages} onPageChange={setPage} />}
    </div>
  );
}
