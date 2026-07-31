// Shared CSV-export helpers used by every admin CSV download/report button
// (daily-revenue-export-button, expiry-export-button, report-card). These
// were previously copy-pasted per-file and had drifted — daily-revenue's
// csvValue() was missing the formula-injection escape below. Consolidated
// here so the escape can't silently go missing from one export again.

// A leading =, +, -, or @ makes some spreadsheet apps (notably Excel) treat
// the cell as a formula instead of literal text — a classic CSV/Excel
// formula-injection vector when the value comes from user-editable data
// (e.g. profiles.full_name). Prefixing with a single quote forces text mode.
export function csvValue(val: string): string {
  const safe = /^[=+\-@]/.test(val) ? `'${val}` : val;
  return `"${safe.replace(/"/g, '""')}"`;
}

// Wraps a value in an Excel "force text" formula so leading zeros / long
// digit strings (dates, phone numbers) aren't mangled by autoformatting.
export function csvForceText(val: string): string {
  return `"=""${val}"""`;
}

export function downloadCsv(content: string, filename: string): void {
  // BOM so Excel reads the file as UTF-8 (otherwise ₹ gets mangled).
  const blob = new Blob(["﻿" + content], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
