"use client";

import { useMemo, useState } from "react";
import { Wallet } from "lucide-react";
import { formatINR } from "@/lib/format";
import { Pagination, paginate } from "@/components/admin/pagination";

const PAGE_SIZE = 20;

export type LedgerRow = {
  id: string;
  date: string;
  description: string;
  debit: number;
  credit: number;
  balance: number;
};

// Date-only values ("YYYY-MM-DD") must be parsed via explicit y/m/d
// components, not `new Date("YYYY-MM-DD")` - the latter is spec'd to parse
// as UTC midnight, which a negative-UTC-offset viewer's browser can then
// render as the previous calendar day.
function formatDate(dateStr: string) {
  if (dateStr.includes("T")) {
    return new Date(dateStr).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
  }
  const [y, m, d] = dateStr.split("-").map(Number);
  return new Date(y, m - 1, d).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
}

// Standard sales-ledger convention: a positive balance is money still owed
// BY the member (a debit balance), a negative one means they've overpaid /
// have credit sitting with the gym.
function BalanceTag({ amount, bold = false }: { amount: number; bold?: boolean }) {
  if (amount === 0) return <span className={bold ? "font-bold" : ""}>0</span>;
  if (amount > 0) return <span className={`text-energy ${bold ? "font-bold" : ""}`}>{formatINR(amount)} Dr</span>;
  return <span className={`text-aqua ${bold ? "font-bold" : ""}`}>{formatINR(-amount)} Cr</span>;
}

export function MemberDetailTables({ rows, openingDate }: { rows: LedgerRow[]; openingDate: string }) {
  const [page, setPage] = useState(1);
  const totalPages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
  const pageItems = useMemo(() => paginate(rows, page, PAGE_SIZE), [rows, page]);
  // `rows` is already sorted oldest-first - Opening should always show
  // whatever the earliest real ledger entry is, not the account's
  // login-creation date (a subscription's Date can be backdated earlier).
  const effectiveOpeningDate = rows[0]?.date ?? openingDate;

  const totalDebit = useMemo(() => rows.reduce((sum, r) => sum + r.debit, 0), [rows]);
  const totalCredit = useMemo(() => rows.reduce((sum, r) => sum + r.credit, 0), [rows]);
  const closingBalance = totalDebit - totalCredit;

  return (
    <div>
      <h2 className="mb-2.5 flex items-center gap-2 font-display text-[16px] font-bold">
        <Wallet className="size-4 text-brand" />
        Membership &amp; Payments
        <span className="num rounded-full bg-muted px-2 py-0.5 text-[11px] font-bold text-muted-foreground">{rows.length}</span>
      </h2>

      <div className="rounded-[20px] border border-border bg-card shadow-sm">
        <div className="overflow-x-auto">
          <table className="w-full min-w-[720px] text-left text-[13px]">
            <thead>
              <tr className="border-b border-border text-[10.5px] font-semibold uppercase tracking-wide text-muted-foreground">
                <th className="px-5 py-3 font-semibold">Date</th>
                <th className="px-3 py-3 font-semibold">Description</th>
                <th className="px-3 py-3 text-right font-semibold">Debit</th>
                <th className="px-3 py-3 text-right font-semibold">Credit</th>
                <th className="px-5 py-3 text-right font-semibold">Balance</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              <tr className="bg-muted/30 text-muted-foreground">
                <td className="px-5 py-2.5">{formatDate(effectiveOpeningDate)}</td>
                <td className="px-3 py-2.5 italic">Opening</td>
                <td className="px-3 py-2.5 text-right">-</td>
                <td className="px-3 py-2.5 text-right">-</td>
                <td className="num px-5 py-2.5 text-right">
                  <BalanceTag amount={0} />
                </td>
              </tr>
              {pageItems.map((r) => (
                <tr key={r.id}>
                  <td className="px-5 py-2.5 whitespace-nowrap">{formatDate(r.date)}</td>
                  <td className="px-3 py-2.5">{r.description}</td>
                  <td className="num px-3 py-2.5 text-right font-semibold text-energy">{r.debit > 0 ? formatINR(r.debit) : "-"}</td>
                  <td className="num px-3 py-2.5 text-right font-semibold text-brand">{r.credit > 0 ? formatINR(r.credit) : "-"}</td>
                  <td className="num px-5 py-2.5 text-right">
                    <BalanceTag amount={r.balance} />
                  </td>
                </tr>
              ))}
            </tbody>
            <tfoot>
              <tr className="border-t-2 border-border font-bold">
                <td className="px-5 py-3" colSpan={2}>
                  Closing Balance
                </td>
                <td className="num px-3 py-3 text-right text-energy">{formatINR(totalDebit)}</td>
                <td className="num px-3 py-3 text-right text-brand">{formatINR(totalCredit)}</td>
                <td className="num px-5 py-3 text-right">
                  <BalanceTag amount={closingBalance} bold />
                </td>
              </tr>
            </tfoot>
          </table>
        </div>
        <div className="px-5 pb-3">
          <Pagination page={page} totalPages={totalPages} onPageChange={setPage} />
        </div>
      </div>
    </div>
  );
}
