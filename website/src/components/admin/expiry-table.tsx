"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Search, X, AlertTriangle, Timer, Clock, CheckCircle2, Pencil } from "lucide-react";
import { formatINR } from "@/lib/format";
import { initials } from "@/lib/utils";
import { EditMemberModal, type EditableMember } from "@/components/admin/edit-member-modal";
import { Pagination, paginate } from "@/components/admin/pagination";

const PAGE_SIZE = 15;

export type ExpiryCategory = "expired" | "critical" | "expiring" | "healthy";

export type ExpiryRow = {
  subscriptionId: string;
  userId: string | null;
  name: string;
  phone: string;
  passName: string;
  passPrice: number | null;
  startDate: string;
  endDate: string;
  formattedStart: string;
  formattedEnd: string;
  days: number;
  category: ExpiryCategory;
  statusLabel: string;
};

type Pass = { id: string; name: string; price: number; duration_days: number };
// "soon" is a synthetic bucket (critical + expiring) for the Overview page's
// "Expiring Soon" card deep link - it has no chip of its own, it just narrows
// the initial view; the existing per-category chips still work normally.
export type ExpiryFilter = "all" | ExpiryCategory | "soon";
type Filter = ExpiryFilter;

// Mirrors the _Filter enum order in admin_expiry_screen.dart. "soon" has no
// chip (see note above), so this list is intentionally narrower than Filter.
const FILTERS: { key: "all" | ExpiryCategory; label: string }[] = [
  { key: "all", label: "All" },
  { key: "expired", label: "Expired" },
  { key: "critical", label: "Critical" },
  { key: "expiring", label: "Expiring" },
  { key: "healthy", label: "Active" },
];

// text-*-onlight are darkened variants that clear WCAG AA contrast on the
// light-mode card background; dark:text-* restores the brighter raw token
// for dark mode, where it already has enough contrast (see globals.css).
const CATEGORY_STYLE: Record<
  ExpiryCategory,
  {
    badge: string;
    icon: React.ComponentType<{ className?: string }>;
    chipActive: string;
  }
> = {
  expired: {
    badge: "border-danger/35 bg-danger/12 text-danger-onlight dark:text-danger",
    icon: AlertTriangle,
    chipActive: "border-danger bg-danger/10 text-danger-onlight dark:text-danger",
  },
  critical: {
    badge: "border-energy/35 bg-energy/12 text-energy-onlight dark:text-energy",
    icon: Timer,
    chipActive: "border-energy bg-energy/10 text-energy-onlight dark:text-energy",
  },
  expiring: {
    badge: "border-sun/40 bg-sun/[0.18] text-sun-onlight dark:text-sun",
    icon: Clock,
    chipActive: "border-sun bg-sun/10 text-sun-onlight dark:text-sun",
  },
  healthy: {
    badge: "border-brand/35 bg-brand/12 text-brand-onlight dark:text-brand",
    icon: CheckCircle2,
    chipActive: "border-brand bg-brand/10 text-brand-onlight dark:text-brand",
  },
};

// Mirrors the avatarColors list in _buildMemberCard (aqua, pulse, brand, energy, sun),
// keyed the same way: name.length % colors.length.
const AVATAR_COLORS = [
  "border-aqua/30 bg-aqua/15 text-aqua-onlight dark:text-aqua",
  "border-pulse/30 bg-pulse/15 text-pulse",
  "border-brand/30 bg-brand/15 text-brand-onlight dark:text-brand",
  "border-energy/30 bg-energy/15 text-energy-onlight dark:text-energy",
  "border-sun/30 bg-sun/15 text-sun-onlight dark:text-sun",
];

export function ExpiryTable({
  rows,
  passes,
  initialFilter = "all",
}: {
  rows: ExpiryRow[];
  passes: Pass[];
  initialFilter?: Filter;
}) {
  const router = useRouter();
  const [filter, setFilter] = useState<Filter>(initialFilter);
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [editing, setEditing] = useState<ExpiryRow | null>(null);

  const counts = useMemo(() => {
    const c: Record<ExpiryCategory, number> = { expired: 0, critical: 0, expiring: 0, healthy: 0 };
    for (const r of rows) c[r.category]++;
    return c;
  }, [rows]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return rows.filter((r) => {
      if (filter === "soon" ? r.category !== "critical" && r.category !== "expiring" : filter !== "all" && r.category !== filter) {
        return false;
      }
      if (!q) return true;
      return r.name.toLowerCase().includes(q) || r.phone.toLowerCase().includes(q);
    });
  }, [rows, filter, search]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const pageItems = useMemo(() => paginate(filtered, page, PAGE_SIZE), [filtered, page]);

  const editingMember: EditableMember | null = editing?.userId
    ? { id: editing.userId, full_name: editing.name, phone: editing.phone }
    : null;

  return (
    <>
      <div className="mb-5 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <SummaryTile count={counts.expired} label="Expired" tone="danger" />
        <SummaryTile count={counts.critical} label="≤ 7 Days" tone="energy" />
        <SummaryTile count={counts.expiring} label="≤ 30 Days" tone="sun" />
        <SummaryTile count={counts.healthy} label="Active" tone="brand" />
      </div>

      {filter === "soon" && (
        <div className="mb-3 flex items-center gap-2 text-[12.5px] font-semibold text-muted-foreground">
          Showing members expiring within 30 days.
          <button type="button" onClick={() => setFilter("all")} className="font-bold text-brand">
            Clear filter
          </button>
        </div>
      )}

      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="flex flex-wrap gap-2">
          {FILTERS.map((f) => {
            const isActive = filter === f.key;
            const count = f.key === "all" ? rows.length : counts[f.key];
            const activeClass = f.key === "all" ? "border-foreground bg-muted text-foreground" : CATEGORY_STYLE[f.key].chipActive;
            return (
              <button
                key={f.key}
                type="button"
                onClick={() => {
                  setFilter(f.key);
                  setPage(1);
                }}
                className={`flex items-center gap-1.5 rounded-full border px-3.5 py-2 text-[12px] font-semibold transition-colors ${
                  isActive ? activeClass : "border-border bg-card text-muted-foreground"
                }`}
              >
                {f.label}
                <span
                  className={`rounded-full px-1.5 py-0.5 text-[10px] font-bold ${
                    isActive ? "bg-black/10 dark:bg-white/15" : "bg-muted-foreground/12"
                  }`}
                >
                  {count}
                </span>
              </button>
            );
          })}
        </div>

        <div className="relative ml-auto w-full max-w-[280px]">
          <Search className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <input
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
            placeholder="Search by name or phone..."
            className="w-full rounded-xl border border-border bg-card py-2.5 pl-9 pr-8 text-[13px] outline-none placeholder:text-muted-foreground"
          />
          {search && (
            <button
              type="button"
              onClick={() => {
                setSearch("");
                setPage(1);
              }}
              className="absolute right-2.5 top-1/2 -translate-y-1/2 text-muted-foreground"
              aria-label="Clear search"
            >
              <X className="size-4" />
            </button>
          )}
        </div>
      </div>

      <div className="rounded-[20px] border border-border bg-card shadow-sm">
        {filtered.length === 0 ? (
          <div className="flex flex-col items-center gap-3 px-6 py-16 text-center">
            <CheckCircle2 className="size-9 text-brand" />
            <p className="font-display text-[16px] font-bold">All clear!</p>
            <p className="text-[13px] text-muted-foreground">No members in this category.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[880px] text-left text-[13px]">
              <thead>
                <tr className="border-b border-border text-[10.5px] font-semibold uppercase tracking-wide text-muted-foreground">
                  <th className="px-5 py-3 font-semibold">Member</th>
                  <th className="px-3 py-3 font-semibold">Pass</th>
                  <th className="px-3 py-3 font-semibold">Start Date</th>
                  <th className="px-3 py-3 font-semibold">Expiry Date</th>
                  <th className="px-3 py-3 font-semibold">Status</th>
                  <th className="px-5 py-3 text-right font-semibold">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {pageItems.map((r) => {
                  const style = CATEGORY_STYLE[r.category];
                  const Icon = style.icon;
                  const avatarClass = AVATAR_COLORS[r.name.length % AVATAR_COLORS.length];
                  return (
                    <tr key={r.subscriptionId} className={r.category === "expired" ? "bg-danger/[0.03]" : undefined}>
                      <td className="px-5 py-3.5">
                        <div className="flex items-center gap-3">
                          <span
                            className={`grid size-9 shrink-0 place-items-center rounded-full border text-[11px] font-bold ${avatarClass}`}
                          >
                            {initials(r.name)}
                          </span>
                          <div className="min-w-0">
                            <div className="truncate font-bold">{r.name}</div>
                            <div className="truncate text-[11.5px] text-muted-foreground">{r.phone || "-"}</div>
                          </div>
                        </div>
                      </td>
                      <td className="px-3 py-3.5">
                        <div>{r.passName}</div>
                        {r.passPrice != null && (
                          <div className="text-[11.5px] text-muted-foreground">{formatINR(r.passPrice)}</div>
                        )}
                      </td>
                      <td className="px-3 py-3.5 text-muted-foreground">{r.formattedStart}</td>
                      <td className="px-3 py-3.5 font-semibold">{r.formattedEnd}</td>
                      <td className="px-3 py-3.5">
                        <span className={`inline-flex items-center gap-1.5 rounded-md border px-2 py-1 text-[11px] font-bold ${style.badge}`}>
                          <Icon className="size-3" />
                          {r.statusLabel}
                        </span>
                      </td>
                      <td className="px-5 py-3.5 text-right">
                        <button
                          type="button"
                          onClick={() => setEditing(r)}
                          disabled={!r.userId}
                          className="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-1.5 text-[12px] font-semibold text-foreground disabled:opacity-40"
                        >
                          <Pencil className="size-3.5" />
                          Renew
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <Pagination page={page} totalPages={totalPages} onPageChange={setPage} />

      <EditMemberModal
        member={editingMember}
        passes={passes}
        onClose={() => setEditing(null)}
        onSaved={() => router.refresh()}
      />
    </>
  );
}

const TONE_CLASSES = {
  danger: "bg-danger/10 text-danger-onlight dark:text-danger",
  energy: "bg-energy/12 text-energy-onlight dark:text-energy",
  sun: "bg-sun/[0.18] text-sun-onlight dark:text-sun",
  brand: "bg-brand/10 text-brand-onlight dark:text-brand",
} as const;

function SummaryTile({ count, label, tone }: { count: number; label: string; tone: keyof typeof TONE_CLASSES }) {
  return (
    <div className={`rounded-[20px] px-4 py-4 text-center ${TONE_CLASSES[tone]}`}>
      <div className="num font-display text-[26px] font-bold">{count}</div>
      <div className="mt-1 text-[10.5px] font-bold uppercase tracking-wide">{label}</div>
    </div>
  );
}
