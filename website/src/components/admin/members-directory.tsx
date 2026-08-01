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
  // Positive = member still owes this much (Debit). Negative = member has
  // overpaid and the gym owes them this much back (Credit). Zero = settled.
  balance: number;
};

// Debit and Credit are always both shown, side by side - whichever doesn't
// apply just reads "-".
function DebitCell({ balance }: { balance: number }) {
  return balance > 0 ? (
    <span className="font-bold text-energy">{formatINR(balance)}</span>
  ) : (
    <span className="font-semibold text-muted-foreground">-</span>
  );
}

function CreditCell({ balance }: { balance: number }) {
  return balance < 0 ? (
    <span className="font-bold text-aqua">{formatINR(-balance)}</span>
  ) : (
    <span className="font-semibold text-muted-foreground">-</span>
  );
}

function membershipNo(userId: string) {
  return `MBR-${userId.replace(/-/g, "").slice(0, 6).toUpperCase()}`;
}

export function MembersDirectory({ members }: { members: MemberRow[] }) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  // Search + page live in the URL (not just component state) so that
  // navigating into a member's ledger and clicking Back returns to the same
  // filtered page instead of resetting to page 1 - React state doesn't
  // survive this component unmounting for the detail route and remounting.
  const [search, setSearch] = useState(() => searchParams.get("search") ?? "");
  const [page, setPage] = useState(() => Number(searchParams.get("page")) || 1);

  function syncUrl(nextSearch: string, nextPage: number) {
    const params = new URLSearchParams();
    if (nextSearch) params.set("search", nextSearch);
    if (nextPage > 1) params.set("page", String(nextPage));
    const qs = params.toString();
    router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
  }

  function handleSearchChange(value: string) {
    setSearch(value);
    setPage(1);
    syncUrl(value, 1);
  }

  function handlePageChange(nextPage: number) {
    setPage(nextPage);
    syncUrl(search, nextPage);
  }

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return members;
    return members.filter((m) => {
      const name = (m.full_name ?? "").toLowerCase();
      const phone = (m.phone ?? "").toLowerCase();
      return name.includes(q) || phone.includes(q) || membershipNo(m.id).toLowerCase().includes(q);
    });
  }, [members, search]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const pageItems = useMemo(() => paginate(filtered, page, PAGE_SIZE), [filtered, page]);

  return (
    <div>
      <div className="relative mb-4">
        <Search className="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <input
          value={search}
          onChange={(e) => handleSearchChange(e.target.value)}
          placeholder="Search by name, phone or MBR..."
          className="w-full rounded-xl border border-border bg-card py-2.5 pl-10 pr-4 text-[14px] outline-none focus:border-brand"
        />
      </div>

      {filtered.length === 0 ? (
        <p className="py-16 text-center text-[13px] text-muted-foreground">
          {search ? `No members match "${search}".` : "No members yet."}
        </p>
      ) : (
        <div className="flex flex-col gap-2">
          <div className="hidden items-center gap-3 px-4 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground sm:flex">
            <div className="size-10 shrink-0" />
            <div className="min-w-0 flex-1" />
            <div className="flex shrink-0 items-center gap-3">
              <div className="w-[85px] text-right">Debit</div>
              <div className="w-[85px] text-right">Credit</div>
              <div className="w-[62px]" />
            </div>
          </div>
          {pageItems.map((m) => {
            const name = m.full_name ?? "Member";
            return (
              <Link
                key={m.id}
                href={`/admin/members/${m.id}`}
                className="flex items-center gap-3 rounded-[20px] border border-border bg-card px-4 py-3.5 transition-colors hover:border-brand/40"
              >
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
                    <span className="rounded bg-brand/8 px-1.5 py-0.5 text-[9px] font-bold text-brand">
                      {membershipNo(m.id)}
                    </span>
                    <span className="truncate text-[11px] text-muted-foreground">{m.phone || "-"}</span>
                  </div>
                </div>
                <div className="flex shrink-0 items-center gap-3">
                  <div className="w-[85px] text-right text-[13px]">
                    <DebitCell balance={m.balance} />
                  </div>
                  <div className="w-[85px] text-right text-[13px]">
                    <CreditCell balance={m.balance} />
                  </div>
                  <span className="flex w-[62px] shrink-0 items-center justify-end gap-1 text-[12px] font-semibold text-muted-foreground">
                    View
                    <ChevronRight className="size-3.5" />
                  </span>
                </div>
              </Link>
            );
          })}
        </div>
      )}

      <Pagination page={page} totalPages={totalPages} onPageChange={handlePageChange} />
    </div>
  );
}
