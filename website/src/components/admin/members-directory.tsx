"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Search, ChevronRight } from "lucide-react";
import { initials } from "@/lib/utils";
import { formatINR } from "@/lib/format";
import { Pagination, paginate } from "@/components/admin/pagination";

const PAGE_SIZE = 15;

export type MemberRow = {
  id: string;
  full_name: string | null;
  phone: string | null;
  photo_url: string | null;
  created_at: string;
  // Debit = total ever charged (fees minus discounts). Credit = total ever
  // paid. Both are independent running totals, always shown side by side.
  debit: number;
  credit: number;
  // balance = debit - credit. Positive = member still owes this much.
  // Negative = member has overpaid and the gym owes them this much back.
  balance: number;
};

function DebitCell({ debit, bold = false }: { debit: number; bold?: boolean }) {
  return debit > 0 ? (
    <span className={`text-energy ${bold ? "font-bold" : "font-semibold"}`}>{formatINR(debit)}</span>
  ) : (
    <span className={`text-muted-foreground ${bold ? "font-bold" : "font-semibold"}`}>-</span>
  );
}

function CreditCell({ credit, bold = false }: { credit: number; bold?: boolean }) {
  return credit > 0 ? (
    <span className={`text-aqua ${bold ? "font-bold" : "font-semibold"}`}>{formatINR(credit)}</span>
  ) : (
    <span className={`text-muted-foreground ${bold ? "font-bold" : "font-semibold"}`}>-</span>
  );
}

// Same convention as the individual member ledger's Closing Balance tag.
function BalanceCell({ balance, bold = false }: { balance: number; bold?: boolean }) {
  if (balance === 0) return <span className={bold ? "font-bold" : "font-semibold"}>0</span>;
  if (balance > 0)
    return <span className={`text-energy ${bold ? "font-bold" : "font-semibold"}`}>{formatINR(balance)} Dr</span>;
  return <span className={`text-aqua ${bold ? "font-bold" : "font-semibold"}`}>{formatINR(-balance)} Cr</span>;
}

function membershipNo(userId: string) {
  return `MBR-${userId.replace(/-/g, "").slice(0, 6).toUpperCase()}`;
}

type BalanceFilter = "all" | "debit" | "credit";
const BALANCE_FILTERS: { key: BalanceFilter; label: string }[] = [
  { key: "all", label: "All" },
  { key: "debit", label: "Debit" },
  { key: "credit", label: "Credit" },
];

export function MembersDirectory({ members }: { members: MemberRow[] }) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  // Search + filter + page live in the URL (not just component state) so
  // that navigating into a member's ledger and clicking Back returns to the
  // same filtered page instead of resetting to page 1 - React state doesn't
  // survive this component unmounting for the detail route and remounting.
  const [search, setSearch] = useState(() => searchParams.get("search") ?? "");
  const [balanceFilter, setBalanceFilter] = useState<BalanceFilter>(() => {
    const f = searchParams.get("balance");
    return f === "debit" || f === "credit" ? f : "all";
  });
  const [page, setPage] = useState(() => Number(searchParams.get("page")) || 1);

  function syncUrl(nextSearch: string, nextFilter: BalanceFilter, nextPage: number) {
    const params = new URLSearchParams();
    if (nextSearch) params.set("search", nextSearch);
    if (nextFilter !== "all") params.set("balance", nextFilter);
    if (nextPage > 1) params.set("page", String(nextPage));
    const qs = params.toString();
    router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
  }

  function handleSearchChange(value: string) {
    setSearch(value);
    setPage(1);
    syncUrl(value, balanceFilter, 1);
  }

  function handleFilterChange(next: BalanceFilter) {
    setBalanceFilter(next);
    setPage(1);
    syncUrl(search, next, 1);
  }

  function handlePageChange(nextPage: number) {
    setPage(nextPage);
    syncUrl(search, balanceFilter, nextPage);
  }

  const searched = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return members;
    return members.filter((m) => {
      const name = (m.full_name ?? "").toLowerCase();
      const phone = (m.phone ?? "").toLowerCase();
      return name.includes(q) || phone.includes(q) || membershipNo(m.id).toLowerCase().includes(q);
    });
  }, [members, search]);

  const balanceCounts = useMemo(
    () => ({
      debit: members.filter((m) => m.balance > 0).length,
      credit: members.filter((m) => m.balance < 0).length,
    }),
    [members],
  );

  const filtered = useMemo(() => {
    if (balanceFilter === "debit") return searched.filter((m) => m.balance > 0);
    if (balanceFilter === "credit") return searched.filter((m) => m.balance < 0);
    return searched;
  }, [searched, balanceFilter]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const pageItems = useMemo(() => paginate(filtered, page, PAGE_SIZE), [filtered, page]);
  const currentPage = Math.min(Math.max(page, 1), totalPages);
  const serialOffset = (currentPage - 1) * PAGE_SIZE;

  const isLastPage = currentPage === totalPages;

  // Grand total across every filtered member, not just this page - only
  // shown once, at the bottom of the last page.
  const grandTotals = useMemo(
    () =>
      filtered.reduce(
        (acc, m) => ({ debit: acc.debit + m.debit, credit: acc.credit + m.credit }),
        { debit: 0, credit: 0 },
      ),
    [filtered],
  );

  return (
    <div>
      <div className="relative mb-3">
        <Search className="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <input
          value={search}
          onChange={(e) => handleSearchChange(e.target.value)}
          placeholder="Search by name, phone or MBR..."
          className="w-full rounded-xl border border-border bg-card py-2.5 pl-10 pr-4 text-[14px] outline-none focus:border-brand"
        />
      </div>

      <div className="mb-4 flex flex-wrap gap-2">
        {BALANCE_FILTERS.map((f) => {
          const isActive = balanceFilter === f.key;
          const count = f.key === "all" ? members.length : balanceCounts[f.key];
          return (
            <button
              key={f.key}
              type="button"
              onClick={() => handleFilterChange(f.key)}
              className={`flex items-center gap-1.5 rounded-full border px-3.5 py-2 text-[12px] font-semibold transition-colors ${
                isActive ? "border-brand bg-brand text-white" : "border-border bg-card text-muted-foreground"
              }`}
            >
              {f.label}
              <span className={`rounded-full px-1.5 py-0.5 text-[10px] font-bold ${isActive ? "bg-black/15" : "bg-muted-foreground/12"}`}>
                {count}
              </span>
            </button>
          );
        })}
      </div>

      {filtered.length === 0 ? (
        <p className="py-16 text-center text-[13px] text-muted-foreground">
          {search && balanceFilter !== "all"
            ? `No ${balanceFilter} members match "${search}".`
            : search
              ? `No members match "${search}".`
              : balanceFilter !== "all"
                ? `No members with a ${balanceFilter} balance.`
                : "No members yet."}
        </p>
      ) : (
        <div className="flex flex-col gap-2">
          <div className="hidden items-center gap-3 px-4 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground sm:flex">
            <div className="w-6 shrink-0 text-center">#</div>
            <div className="size-10 shrink-0" />
            <div className="min-w-0 flex-1" />
            <div className="flex shrink-0 items-center gap-3">
              <div className="w-[85px] text-right">Debit</div>
              <div className="w-[85px] text-right">Credit</div>
              <div className="w-[85px] text-right">Balance</div>
              <div className="w-[62px]" />
            </div>
          </div>
          {pageItems.map((m, i) => {
            const name = m.full_name ?? "Member";
            return (
              <Link
                key={m.id}
                href={`/admin/members/${m.id}`}
                className="flex flex-wrap items-center gap-3 rounded-[20px] border border-border bg-card px-4 py-3.5 transition-colors hover:border-brand/40"
              >
                {/* Name/MBR/phone always keeps its own full-width line - it
                    never competes for space with the Debit/Credit/View block,
                    which is why long names/phone numbers were truncating on
                    narrow phones (that block used to sit beside this one in
                    a single row, squeezing it down to almost nothing). */}
                <div className="flex min-w-0 flex-1 items-center gap-3">
                  <span className="num w-6 shrink-0 text-center text-[12px] font-bold text-muted-foreground">
                    {serialOffset + i + 1}
                  </span>
                  <span className="grid size-10 shrink-0 place-items-center overflow-hidden rounded-full bg-brand/12 text-[12px] font-bold text-brand">
                    {m.photo_url ? (
                      <Image src={m.photo_url} alt="" width={40} height={40} className="size-full object-cover" />
                    ) : (
                      initials(name)
                    )}
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[14px] font-bold">{name}</div>
                    <div className="mt-0.5 flex items-center gap-1.5">
                      <span className="shrink-0 rounded bg-brand/8 px-1.5 py-0.5 text-[9px] font-bold text-brand">
                        {membershipNo(m.id)}
                      </span>
                      <span className="truncate text-[11px] text-muted-foreground">{m.phone || "-"}</span>
                    </div>
                  </div>
                </div>

                {/* On narrow screens this block doesn't fit next to the name
                    above, so it wraps onto its own full-width line instead of
                    squeezing the name column. On sm+ it fits inline as before. */}
                <div className="flex w-full items-center gap-4 border-t border-border pt-3 sm:w-auto sm:gap-3 sm:border-t-0 sm:pt-0">
                  <div className="flex-1 text-[13px] sm:w-[85px] sm:flex-none sm:text-right">
                    <div className="text-[9px] font-semibold uppercase tracking-wide text-muted-foreground sm:hidden">Debit</div>
                    <DebitCell debit={m.debit} />
                  </div>
                  <div className="flex-1 text-[13px] sm:w-[85px] sm:flex-none sm:text-right">
                    <div className="text-[9px] font-semibold uppercase tracking-wide text-muted-foreground sm:hidden">Credit</div>
                    <CreditCell credit={m.credit} />
                  </div>
                  <div className="flex-1 text-[13px] sm:w-[85px] sm:flex-none sm:text-right">
                    <div className="text-[9px] font-semibold uppercase tracking-wide text-muted-foreground sm:hidden">Balance</div>
                    <BalanceCell balance={m.balance} />
                  </div>
                  <span className="flex shrink-0 items-center gap-1 text-[12px] font-semibold text-muted-foreground sm:w-[62px] sm:justify-end">
                    View
                    <ChevronRight className="size-3.5" />
                  </span>
                </div>
              </Link>
            );
          })}

          {/* Grand total across every filtered member - shown once, only on
              the last page, not repeated per page. */}
          {isLastPage && (
          <div className="flex flex-wrap items-center gap-3 rounded-[20px] border-2 border-border bg-muted/40 px-4 py-3.5">
            <div className="flex min-w-0 flex-1 items-center gap-3">
              <span className="w-6 shrink-0" />
              <span className="grid size-10 shrink-0 place-items-center rounded-full bg-muted text-[13px] font-bold text-muted-foreground">
                &Sigma;
              </span>
              <div className="min-w-0 flex-1 text-[13px] font-bold">Grand Total</div>
            </div>
            <div className="flex w-full items-center gap-4 pt-3 sm:w-auto sm:gap-3 sm:border-t-0 sm:pt-0">
              <div className="flex-1 text-[13px] sm:w-[85px] sm:flex-none sm:text-right">
                <div className="text-[9px] font-semibold uppercase tracking-wide text-muted-foreground sm:hidden">Debit</div>
                <DebitCell debit={grandTotals.debit} bold />
              </div>
              <div className="flex-1 text-[13px] sm:w-[85px] sm:flex-none sm:text-right">
                <div className="text-[9px] font-semibold uppercase tracking-wide text-muted-foreground sm:hidden">Credit</div>
                <CreditCell credit={grandTotals.credit} bold />
              </div>
              <div className="flex-1 text-[13px] sm:w-[85px] sm:flex-none sm:text-right">
                <div className="text-[9px] font-semibold uppercase tracking-wide text-muted-foreground sm:hidden">Balance</div>
                <BalanceCell balance={grandTotals.debit - grandTotals.credit} bold />
              </div>
              <span className="shrink-0 sm:w-[62px]" />
            </div>
          </div>
          )}
        </div>
      )}

      <Pagination page={page} totalPages={totalPages} onPageChange={handlePageChange} />
    </div>
  );
}
