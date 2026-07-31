"use client";

import { useState } from "react";
import { Download, Loader2 } from "lucide-react";
import type { ExpiryRow } from "@/components/admin/expiry-table";
import { csvValue, csvForceText, downloadCsv } from "@/lib/csv-export";

// Mirrors the statusLabel switch in _exportCsv() (admin_expiry_screen.dart).
const STATUS_WORD: Record<ExpiryRow["category"], string> = {
  expired: "Expired",
  critical: "Critical",
  expiring: "Expiring",
  healthy: "Active",
};

export function ExpiryExportButton({ rows }: { rows: ExpiryRow[] }) {
  const [exporting, setExporting] = useState(false);

  async function handleExport() {
    setExporting(true);
    // Without a real await between setExporting(true) and the (synchronous)
    // CSV build below, React batches both state changes into one commit and
    // the spinner never gets a chance to paint. This tick gives it one.
    await new Promise((r) => setTimeout(r, 50));
    try {
      const lines = ["Name,Phone,Pass,Status,Start Date,Expiry Date,Days Remaining"];
      for (const r of rows) {
        const daysLabel = r.days < 0 ? `Expired ${-r.days}d ago` : `${r.days} days left`;
        lines.push(
          [
            csvValue(r.name),
            csvForceText(r.phone),
            csvValue(r.passName),
            csvValue(STATUS_WORD[r.category]),
            csvValue(r.startDate),
            csvValue(r.endDate),
            csvValue(daysLabel),
          ].join(","),
        );
      }
      const now = new Date();
      const stamp = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, "0")}${String(now.getDate()).padStart(2, "0")}`;
      downloadCsv(lines.join("\n"), `member_report_${stamp}.csv`);
    } finally {
      setExporting(false);
    }
  }

  return (
    <button
      type="button"
      onClick={handleExport}
      disabled={exporting || rows.length === 0}
      className="flex items-center gap-2 rounded-xl bg-brand px-4 py-2.5 text-[13px] font-bold text-on-brand disabled:opacity-50"
    >
      {exporting ? <Loader2 className="size-[15px] animate-spin" /> : <Download className="size-[15px]" />}
      Export CSV
    </button>
  );
}
