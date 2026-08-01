"use client";

import { useState } from "react";
import { Receipt, UserPlus } from "lucide-react";
import { formatINR } from "@/lib/format";
import { Pagination, paginate } from "@/components/admin/pagination";

const PAGE_SIZE = 15;

export type DayActivityRow = {
  key: string;
  name: string;
  phone: string;
  passType: string;
  paymentMethod: string;
  packageAmount: number;
  discount: number;
  paidAmount: number;
  balanceAmount: number;
  isNewMember: boolean;
};

// A single day's members-added and payments-received used to be two separate
// lists; merged here into one paginated table with a "New" badge marking
// which rows are same-day signups, so an admin isn't scanning two views for
// one day's activity.
export function DayActivityTable({ rows }: { rows: DayActivityRow[] }) {
  const [page, setPage] = useState(1);
  const totalPages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
  const pageItems = paginate(rows, page, PAGE_SIZE);
  const newCount = rows.filter((r) => r.isNewMember).length;

  return (
    <div className="rounded-[20px] border border-border bg-card shadow-sm">
      <div className="flex flex-wrap items-center gap-3 px-5 pt-4">
        <h3 className="flex items-center gap-2 font-display text-[17px] font-bold">
          <Receipt className="size-4 text-brand" /> Day Activity
        </h3>
        <span className="num rounded-full bg-muted px-2 py-0.5 text-[11px] font-bold text-muted-foreground">
          {rows.length} total
        </span>
        {newCount > 0 && (
          <span className="num flex items-center gap-1 rounded-full bg-brand/10 px-2 py-0.5 text-[11px] font-bold text-brand">
            <UserPlus className="size-3" /> {newCount} new
          </span>
        )}
      </div>

      {rows.length === 0 ? (
        <div className="flex flex-col items-center gap-3 px-6 py-16 text-center">
          <Receipt className="size-9 text-muted-foreground" />
          <p className="text-[13px] text-muted-foreground">No members or payments recorded on this day.</p>
        </div>
      ) : (
        <>
          <div className="mt-3 overflow-x-auto">
            <table className="w-full min-w-[900px] text-left text-[13px]">
              <thead>
                <tr className="border-b border-border text-[10.5px] font-semibold uppercase tracking-wide text-muted-foreground">
                  <th className="px-5 py-3 font-semibold">Member</th>
                  <th className="px-3 py-3 font-semibold">Subscription</th>
                  <th className="px-3 py-3 font-semibold">Mode</th>
                  <th className="px-3 py-3 text-right font-semibold">Package</th>
                  <th className="px-3 py-3 text-right font-semibold">Discount</th>
                  <th className="px-3 py-3 text-right font-semibold">Paid</th>
                  <th className="px-5 py-3 text-right font-semibold">Balance</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {pageItems.map((r) => (
                  <tr key={r.key} className={r.isNewMember ? "bg-brand/[0.03]" : undefined}>
                    <td className="px-5 py-3.5">
                      <div className="flex items-center gap-2">
                        <div>
                          <div className="font-bold">{r.name}</div>
                          {r.phone && <div className="text-[11.5px] text-muted-foreground">{r.phone}</div>}
                        </div>
                        {r.isNewMember && (
                          <span className="shrink-0 rounded-full bg-brand/12 px-1.5 py-0.5 text-[9px] font-extrabold uppercase tracking-wide text-brand">
                            New
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="px-3 py-3.5">
                      <span className="rounded-md bg-aqua/12 px-2 py-1 text-[11px] font-semibold text-aqua">{r.passType}</span>
                    </td>
                    <td className="px-3 py-3.5">
                      <span className="rounded-md bg-muted px-2 py-1 text-[11px] font-semibold text-muted-foreground">
                        {r.paymentMethod || "-"}
                      </span>
                    </td>
                    <td className="num px-3 py-3.5 text-right">{formatINR(r.packageAmount)}</td>
                    <td className="num px-3 py-3.5 text-right text-energy">{r.discount > 0 ? formatINR(r.discount) : "-"}</td>
                    <td className="num px-3 py-3.5 text-right font-bold text-brand">{formatINR(r.paidAmount)}</td>
                    <td className="num px-5 py-3.5 text-right font-semibold">
                      {r.balanceAmount > 0 ? (
                        <span className="text-energy">{formatINR(r.balanceAmount)}</span>
                      ) : (
                        <span className="font-semibold text-brand">Fully Paid</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="px-5 pb-4">
            <Pagination page={page} totalPages={totalPages} onPageChange={setPage} />
          </div>
        </>
      )}
    </div>
  );
}
