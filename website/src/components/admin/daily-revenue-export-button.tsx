"use client";

import { useState } from "react";
import { Download, Loader2 } from "lucide-react";

type Txn = {
  name: string;
  phone: string;
  passType: string;
  packageAmount: number;
  discount: number;
  paymentMethod: string;
  paidAmount: number;
  balanceAmount: number;
};

function csvValue(val: string) {
  return `"${val.replace(/"/g, '""')}"`;
}

// Wraps a value in an Excel "force text" formula so leading zeros / long
// digit strings (dates, phone numbers) aren't mangled by autoformatting.
function csvForceText(val: string) {
  return `"=""${val}"""`;
}

function downloadCsv(content: string, filename: string) {
  // BOM so Excel reads the file as UTF-8 (otherwise ₹ gets mangled).
  const blob = new Blob(["﻿" + content], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

export function DailyRevenueExportButton({
  txns,
  dateStr,
  fileDateStr,
  totalRevenue,
}: {
  txns: Txn[];
  dateStr: string;
  fileDateStr: string;
  totalRevenue: number;
}) {
  const [exporting, setExporting] = useState(false);

  function handleExport() {
    setExporting(true);
    try {
      const lines = [
        "S.No,Date,Member Name,Mobile Number,Subscription Type,Package Amount (₹),Discount (₹),Mode of Payment,Paid Amount (₹),Balance Amount (₹)",
      ];
      txns.forEach((t, i) => {
        lines.push(
          [
            (i + 1).toString(),
            csvForceText(dateStr),
            csvValue(t.name),
            csvForceText(t.phone),
            csvValue(t.passType),
            t.packageAmount.toFixed(0),
            t.discount.toFixed(0),
            csvValue(t.paymentMethod),
            t.paidAmount.toFixed(0),
            t.balanceAmount.toFixed(0),
          ].join(","),
        );
      });
      lines.push("");
      lines.push(`,,,,,,,,TOTAL REVENUE (₹),${totalRevenue.toFixed(0)}`);

      downloadCsv(lines.join("\n"), `daily_revenue_${fileDateStr}.csv`);
    } finally {
      setExporting(false);
    }
  }

  return (
    <button
      onClick={handleExport}
      disabled={exporting || txns.length === 0}
      className="flex items-center gap-2 rounded-xl border border-border bg-card px-4 py-2.5 text-[13px] font-bold text-foreground disabled:opacity-50"
    >
      {exporting ? <Loader2 className="size-[15px] animate-spin" /> : <Download className="size-[15px]" />}
      Download CSV
    </button>
  );
}
