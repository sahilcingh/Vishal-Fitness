"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { Search, ChevronRight, UserRound } from "lucide-react";
import { initials } from "@/lib/utils";
import { Pagination, paginate } from "@/components/admin/pagination";
import { nowInIST } from "@/lib/ist-time";

const ROW_GAP_PX = 4; // matches the list's gap-1
const FALLBACK_ROW_HEIGHT_PX = 56; // size-9 avatar + py-2.5, used before the first row mounts
const MIN_ROWS = 4;

// On lg: screens this panel is a CSS Grid sibling of the (much taller) add-
// member form, so it gets stretched by the grid's default align-items:
// stretch - that stretched height has nothing to do with window size, so it
// has to be measured on the actual rendered container, not guessed from
// window.innerHeight. On narrower/stacked layouts there's no stretch and
// this just settles on however many rows naturally fit the fallback.
function useFillPageSize(rowCount: number) {
  const containerRef = useRef<HTMLDivElement>(null);
  const rowRef = useRef<HTMLLIElement>(null);
  const [pageSize, setPageSize] = useState(8);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    function recompute() {
      const rowHeight = rowRef.current?.getBoundingClientRect().height || FALLBACK_ROW_HEIGHT_PX;
      const available = container!.clientHeight;
      const rows = Math.floor((available + ROW_GAP_PX) / (rowHeight + ROW_GAP_PX));
      setPageSize(Math.max(MIN_ROWS, rows));
    }

    recompute();
    const ro = new ResizeObserver(recompute);
    ro.observe(container);
    window.addEventListener("resize", recompute);
    return () => {
      ro.disconnect();
      window.removeEventListener("resize", recompute);
    };
    // rowCount: re-measure once the first row actually mounts/unmounts
    // (e.g. going from "no results" to having rows, or vice versa).
  }, [rowCount]);

  return { containerRef, rowRef, pageSize };
}

export type PickerMember = {
  id: string;
  full_name: string | null;
  phone: string | null;
  subscriptions: { end_date: string; status: string; pass: { name: string | null } | null }[];
};

function membershipNo(userId: string) {
  return `MBR-${userId.replace(/-/g, "").slice(0, 6).toUpperCase()}`;
}

function toYMD(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function statusChip(member: PickerMember) {
  const sub = member.subscriptions[0];
  if (!sub) return { label: "New", className: "bg-muted text-muted-foreground" };
  // Date-only comparison against IST "today" - a naive `new Date(end_date)
  // > new Date()` reads a "YYYY-MM-DD" end_date as UTC midnight and compares
  // it to a real instant, which can mark a still-valid membership "Expired"
  // hours before it actually lapses.
  const isActive = sub.status === "active" && sub.end_date.slice(0, 10) >= toYMD(nowInIST());
  return isActive
    ? { label: sub.pass?.name ?? "Active", className: "bg-brand/12 text-brand" }
    : { label: "Expired", className: "bg-energy/10 text-energy" };
}

// The right-hand half of the Add Member workbench - search every member and
// click one to load their full record (profile, membership history, ledger)
// into the form on the left, instead of re-typing details for someone who
// already has a profile (the old source of duplicate accounts).
export function MembersPickerPanel({
  members,
  selectedId,
  onSelect,
}: {
  members: PickerMember[];
  selectedId: string | null;
  onSelect: (member: PickerMember) => void;
}) {
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

  const { containerRef, rowRef, pageSize } = useFillPageSize(filtered.length);

  const totalPages = Math.max(1, Math.ceil(filtered.length / pageSize));
  // Page size can change on resize/orientation change - clamp here so the
  // current page never points past the new total instead of storing it as
  // separate state that needs an effect to stay in sync.
  const clampedPage = Math.min(page, totalPages);
  const pageItems = useMemo(() => paginate(filtered, clampedPage, pageSize), [filtered, clampedPage, pageSize]);

  return (
    <div className="flex h-full flex-col rounded-[20px] border border-border bg-card p-5 shadow-sm">
      <h3 className="font-display text-[16px] font-bold">All Members</h3>
      <p className="mt-0.5 text-[12px] text-muted-foreground">Search and click a member to load them into the form</p>

      <div className="relative mt-3.5">
        <Search className="pointer-events-none absolute left-3 top-1/2 size-3.5 -translate-y-1/2 text-muted-foreground" />
        <input
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
          placeholder="Search by name, phone or MBR..."
          className="w-full rounded-xl border border-border bg-background py-2 pl-8 pr-3 text-[13px] outline-none focus:border-brand"
        />
      </div>

      <div ref={containerRef} className="mt-3.5 min-h-0 flex-1 overflow-hidden">
        {filtered.length === 0 ? (
          <p className="py-8 text-center text-[13px] text-muted-foreground">No members match &quot;{search}&quot;.</p>
        ) : (
          <ul className="flex flex-col gap-1">
            {pageItems.map((m, i) => {
              const chip = statusChip(m);
              const isSelected = m.id === selectedId;
              return (
                <li key={m.id} ref={i === 0 ? rowRef : undefined}>
                  <button
                    type="button"
                    onClick={() => onSelect(m)}
                    aria-pressed={isSelected}
                    className={`group flex w-full items-center gap-2.5 rounded-xl px-2.5 py-2.5 text-left transition-colors ${
                      isSelected ? "bg-brand/8 ring-1 ring-brand/40" : "hover:bg-muted"
                    }`}
                  >
                    <span className="grid size-9 shrink-0 place-items-center rounded-full bg-brand/12 text-[12px] font-bold text-brand">
                      {m.full_name ? initials(m.full_name) : <UserRound className="size-4" />}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-[13px] font-bold">{m.full_name || "Member"}</span>
                      <span className="block truncate text-[11px] text-muted-foreground">{m.phone}</span>
                    </span>
                    <span className={`shrink-0 rounded-full px-1.5 py-0.5 text-[9px] font-bold ${chip.className}`}>{chip.label}</span>
                    <ChevronRight className="size-3.5 shrink-0 text-muted-foreground opacity-0 group-hover:opacity-100" />
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      <div className="mt-2">
        <Pagination page={clampedPage} totalPages={totalPages} onPageChange={setPage} />
      </div>
    </div>
  );
}
