"use client";

import { useMemo, useState } from "react";
import {
  UserPlus,
  Repeat,
  CreditCard,
  Footprints,
  History,
  Search,
} from "lucide-react";
import { Pagination, paginate } from "@/components/admin/pagination";

const PAGE_SIZE = 20;

export type LedgerCategory = "joined" | "membership" | "payment" | "visit" | "change";

export type LedgerEntry = {
  id: string;
  date: string;
  category: LedgerCategory;
  title: string;
  subtitle?: string;
};

type Filter = "all" | LedgerCategory;

const FILTERS: { key: Filter; label: string }[] = [
  { key: "all", label: "All" },
  { key: "membership", label: "Membership" },
  { key: "payment", label: "Payments" },
  { key: "visit", label: "Visits" },
  { key: "change", label: "Changes" },
];

const CATEGORY_STYLE: Record<LedgerCategory, { icon: React.ComponentType<{ className?: string }>; tone: string }> = {
  joined: { icon: UserPlus, tone: "bg-brand/12 text-brand" },
  membership: { icon: Repeat, tone: "bg-aqua/12 text-aqua" },
  payment: { icon: CreditCard, tone: "bg-brand/12 text-brand" },
  visit: { icon: Footprints, tone: "bg-muted text-muted-foreground" },
  change: { icon: History, tone: "bg-sun/[0.18] text-[#B8930A]" },
};

// Date-only values (e.g. payment_date, "YYYY-MM-DD") must be parsed via
// explicit y/m/d components, not `new Date("YYYY-MM-DD")` - the latter is
// spec'd to parse as UTC midnight, which a negative-UTC-offset viewer's
// browser can then render as the previous calendar day. Matches the
// parseYMD pattern used everywhere else in this app for the same reason.
function formatEntryDate(dateStr: string) {
  const hasTime = dateStr.includes("T");
  const opts: Intl.DateTimeFormatOptions = hasTime
    ? { day: "numeric", month: "short", year: "numeric", hour: "numeric", minute: "2-digit" }
    : { day: "numeric", month: "short", year: "numeric" };
  if (hasTime) return new Date(dateStr).toLocaleDateString("en-GB", opts);
  const [y, m, d] = dateStr.split("-").map(Number);
  return new Date(y, m - 1, d).toLocaleDateString("en-GB", opts);
}

export function MemberLedger({ entries }: { entries: LedgerEntry[] }) {
  const [filter, setFilter] = useState<Filter>("all");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);

  const counts = useMemo(() => {
    const c: Record<LedgerCategory, number> = { joined: 0, membership: 0, payment: 0, visit: 0, change: 0 };
    for (const e of entries) c[e.category]++;
    return c;
  }, [entries]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return entries.filter((e) => {
      if (filter !== "all" && !(e.category === filter || (filter === "membership" && e.category === "joined"))) return false;
      if (!q) return true;
      return e.title.toLowerCase().includes(q) || (e.subtitle ?? "").toLowerCase().includes(q);
    });
  }, [entries, filter, search]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const pageItems = useMemo(() => paginate(filtered, page, PAGE_SIZE), [filtered, page]);

  return (
    <div>
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="flex flex-wrap gap-2">
          {FILTERS.map((f) => {
            const isActive = filter === f.key;
            const count = f.key === "all" ? entries.length : f.key === "membership" ? counts.membership + counts.joined : counts[f.key];
            return (
              <button
                key={f.key}
                type="button"
                onClick={() => {
                  setFilter(f.key);
                  setPage(1);
                }}
                className={`flex items-center gap-1.5 rounded-full border px-3.5 py-2 text-[12px] font-semibold transition-colors ${
                  isActive ? "border-brand bg-brand text-white" : "border-border bg-card text-muted-foreground"
                }`}
              >
                {f.label}
                <span
                  className={`rounded-full px-1.5 py-0.5 text-[10px] font-bold ${
                    isActive ? "bg-black/15" : "bg-muted-foreground/12"
                  }`}
                >
                  {count}
                </span>
              </button>
            );
          })}
        </div>

        <div className="relative ml-auto w-full max-w-[260px]">
          <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <input
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
            placeholder="Search this ledger..."
            className="w-full rounded-xl border border-border bg-card py-2.5 pl-9 pr-3 text-[13px] outline-none placeholder:text-muted-foreground"
          />
        </div>
      </div>

      <div className="rounded-[20px] border border-border bg-card shadow-sm">
        {filtered.length === 0 ? (
          <div className="flex flex-col items-center gap-3 px-6 py-16 text-center">
            <History className="size-9 text-muted-foreground" />
            <p className="text-[13px] text-muted-foreground">Nothing here yet.</p>
          </div>
        ) : (
          <div className="divide-y divide-border">
            {pageItems.map((entry) => {
              const style = CATEGORY_STYLE[entry.category];
              const Icon = style.icon;
              return (
                <div key={entry.id} className="flex items-start gap-3.5 px-5 py-4">
                  <span className={`mt-0.5 grid size-9 shrink-0 place-items-center rounded-full ${style.tone}`}>
                    <Icon className="size-4" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="font-semibold text-foreground">{entry.title}</div>
                    {entry.subtitle && <div className="mt-0.5 text-[12.5px] text-muted-foreground">{entry.subtitle}</div>}
                  </div>
                  <div className="shrink-0 whitespace-nowrap text-[11.5px] text-muted-foreground">
                    {formatEntryDate(entry.date)}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      <Pagination page={page} totalPages={totalPages} onPageChange={setPage} />
    </div>
  );
}
