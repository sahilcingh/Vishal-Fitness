"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { Search, ChevronRight } from "lucide-react";
import { initials } from "@/lib/utils";
import { Pagination, paginate } from "@/components/admin/pagination";

const PAGE_SIZE = 15;

export type MemberRow = {
  id: string;
  full_name: string | null;
  phone: string | null;
  photo_url: string | null;
  created_at: string;
};

function membershipNo(userId: string) {
  return `MBR-${userId.replace(/-/g, "").slice(0, 6).toUpperCase()}`;
}

export function MembersDirectory({ members }: { members: MemberRow[] }) {
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);

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
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
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
                <span className="flex shrink-0 items-center gap-1 text-[12px] font-semibold text-muted-foreground">
                  View
                  <ChevronRight className="size-3.5" />
                </span>
              </Link>
            );
          })}
        </div>
      )}

      <Pagination page={page} totalPages={totalPages} onPageChange={setPage} />
    </div>
  );
}
