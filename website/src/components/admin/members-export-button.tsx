"use client";

import { useState } from "react";
import { Download, Loader2 } from "lucide-react";
import { csvValue, csvForceText, downloadCsv } from "@/lib/csv-export";
import type { MemberRow } from "@/components/admin/members-directory";

function membershipNo(userId: string) {
  return `MBR-${userId.replace(/-/g, "").slice(0, 6).toUpperCase()}`;
}

// Same technique as ExpiryExportButton/DailyRevenueExportButton - a CSV that
// Excel/Sheets opens natively, rather than a real binary .xlsx (which would
// need a new dependency this app otherwise has none of).
export function MembersExportButton({ members }: { members: MemberRow[] }) {
  const [exporting, setExporting] = useState(false);

  async function handleExport() {
    setExporting(true);
    await new Promise((r) => setTimeout(r, 50));
    try {
      const lines = ["Name,Phone,Membership No,Member Since,Debit,Credit"];
      for (const m of members) {
        const debit = m.balance > 0 ? m.balance : 0;
        const credit = m.balance < 0 ? -m.balance : 0;
        lines.push(
          [
            csvValue(m.full_name ?? "Member"),
            csvForceText(m.phone ?? ""),
            csvValue(membershipNo(m.id)),
            csvValue(new Date(m.created_at).toLocaleDateString("en-GB")),
            debit.toFixed(0),
            credit.toFixed(0),
          ].join(","),
        );
      }
      const now = new Date();
      const stamp = `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, "0")}${String(now.getDate()).padStart(2, "0")}`;
      downloadCsv(lines.join("\n"), `members_ledger_${stamp}.csv`);
    } finally {
      setExporting(false);
    }
  }

  return (
    <button
      type="button"
      onClick={handleExport}
      disabled={exporting || members.length === 0}
      className="flex items-center gap-2 rounded-xl bg-brand px-4 py-2.5 text-[13px] font-bold text-on-brand disabled:opacity-50"
    >
      {exporting ? <Loader2 className="size-[15px] animate-spin" /> : <Download className="size-[15px]" />}
      Export Excel
    </button>
  );
}
