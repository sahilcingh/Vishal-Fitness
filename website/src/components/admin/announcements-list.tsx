"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Search, X, Trash2, Megaphone } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Pagination, paginate } from "@/components/admin/pagination";

const PAGE_SIZE = 10;

export type AnnouncementRow = {
  id: string;
  title: string;
  message: string;
  is_active: boolean | null;
  created_at: string;
};

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// `created_at` is a timestamptz - Supabase returns a full ISO string, which is
// safe to pass straight into `new Date(...)` (unlike the bare YYYY-MM-DD
// `date` columns used on other admin pages). Mirrors Flutter's
// DateFormat('MMM d, yyyy h:mm a').
function formatAnnouncementDate(iso: string) {
  const d = new Date(iso);
  const hours24 = d.getHours();
  const hours = hours24 % 12 || 12;
  const ampm = hours24 >= 12 ? "PM" : "AM";
  const minutes = String(d.getMinutes()).padStart(2, "0");
  return `${MONTHS[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()} ${hours}:${minutes} ${ampm}`;
}

export function AnnouncementsList({ announcements }: { announcements: AnnouncementRow[] }) {
  const router = useRouter();
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  // A Set (not a single id) because two different rows' toggle/delete calls
  // can be in flight at once - a scalar "pendingId" would have row B's button
  // re-enable early the moment row A's unrelated request finished.
  const [pendingIds, setPendingIds] = useState<Set<string>>(new Set());
  const [rowError, setRowError] = useState<string | null>(null);
  const [justAdded, setJustAdded] = useState(false);
  // Tracks the previous announcement count so a fresh post (which arrives via
  // router.refresh() re-fetching this server-provided prop, not a local
  // action here) can be told apart from a toggle/delete-triggered refresh.
  const prevCountRef = useRef(announcements.length);

  useEffect(() => {
    if (announcements.length > prevCountRef.current) {
      setSearch("");
      setPage(1);
      setJustAdded(true);
      const t = setTimeout(() => setJustAdded(false), 2500);
      prevCountRef.current = announcements.length;
      return () => clearTimeout(t);
    }
    prevCountRef.current = announcements.length;
  }, [announcements.length]);

  function setPending(id: string, pending: boolean) {
    setPendingIds((prev) => {
      const next = new Set(prev);
      if (pending) next.add(id);
      else next.delete(id);
      return next;
    });
  }

  const query = search.trim().toLowerCase();
  const filtered = useMemo(() => {
    if (!query) return announcements;
    return announcements.filter(
      (a) => a.title.toLowerCase().includes(query) || a.message.toLowerCase().includes(query),
    );
  }, [announcements, query]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const pageItems = useMemo(() => paginate(filtered, page, PAGE_SIZE), [filtered, page]);

  async function toggleStatus(a: AnnouncementRow) {
    setPending(a.id, true);
    setRowError(null);
    const supabase = createClient();
    try {
      const { error } = await supabase.from("announcements").update({ is_active: !a.is_active }).eq("id", a.id);
      if (error) throw error;
      router.refresh();
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      setRowError(`Could not update the announcement: ${detail}`);
    } finally {
      setPending(a.id, false);
    }
  }

  async function deleteAnnouncement(id: string, title: string) {
    if (!window.confirm(`Delete "${title}"? This cannot be undone.`)) return;
    setPending(id, true);
    setRowError(null);
    const supabase = createClient();
    try {
      const { error } = await supabase.from("announcements").delete().eq("id", id);
      if (error) throw error;
      router.refresh();
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      setRowError(`Could not delete the announcement: ${detail}`);
    } finally {
      setPending(id, false);
    }
  }

  return (
    <div>
      <div className="mb-4 flex items-center gap-2.5 rounded-xl border border-border bg-card px-4 py-2.5 sm:max-w-[420px]">
        <Search className="size-[18px] shrink-0 text-muted-foreground" />
        <input
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
          placeholder="Search announcements..."
          className="w-full bg-transparent text-[14px] outline-none placeholder:text-muted-foreground"
        />
        {search && (
          <button
            onClick={() => {
              setSearch("");
              setPage(1);
            }}
            aria-label="Clear search"
            className="shrink-0 text-muted-foreground"
          >
            <X className="size-[18px]" />
          </button>
        )}
      </div>

      {rowError && (
        <div className="mb-4 rounded-xl bg-danger/10 px-4 py-3 text-[13px] text-danger">{rowError}</div>
      )}

      {justAdded && (
        <div className="mb-4 rounded-xl bg-brand/10 px-4 py-3 text-[13px] text-brand-onlight dark:text-brand">
          Announcement added.
        </div>
      )}

      {filtered.length === 0 ? (
        <div className="rounded-[20px] border border-border bg-card px-6 py-16 text-center">
          <Megaphone className="mx-auto size-9 text-muted-foreground" />
          <p className="mt-3 text-[13px] text-muted-foreground">
            {query ? `No results for "${query}".` : "No announcements yet."}
          </p>
        </div>
      ) : (
        <div className="grid items-start grid-cols-1 gap-4 lg:grid-cols-2">
          {pageItems.map((a) => {
            const isActive = !!a.is_active;
            const isPending = pendingIds.has(a.id);
            return (
              <div key={a.id} className="card-hover rounded-[20px] border border-border bg-card p-5 shadow-sm">
                <div className="flex items-start justify-between gap-3">
                  <h3 className="min-w-0 flex-1 font-display text-[18px] font-bold leading-snug">{a.title}</h3>
                  <div className="flex shrink-0 items-center gap-3">
                    <button
                      type="button"
                      role="switch"
                      aria-checked={isActive}
                      aria-label={isActive ? "Deactivate announcement" : "Activate announcement"}
                      onClick={() => toggleStatus(a)}
                      disabled={isPending}
                      className={`relative h-[22px] w-[38px] shrink-0 rounded-full transition-colors disabled:opacity-50 ${
                        isActive ? "bg-brand" : "bg-muted"
                      }`}
                    >
                      <span
                        className={`absolute top-[2px] left-[2px] size-[18px] rounded-full bg-white shadow transition-transform ${
                          isActive ? "translate-x-[18px]" : "translate-x-0"
                        }`}
                      />
                    </button>
                    <button
                      type="button"
                      onClick={() => deleteAnnouncement(a.id, a.title)}
                      disabled={isPending}
                      aria-label="Delete announcement"
                      className="grid size-8 shrink-0 place-items-center rounded-lg border border-border text-danger disabled:opacity-50"
                    >
                      <Trash2 className="size-[15px]" />
                    </button>
                  </div>
                </div>

                <div className="mt-1 text-[10px] font-semibold uppercase tracking-[0.1em] text-muted-foreground">
                  {formatAnnouncementDate(a.created_at)}
                </div>

                <p className="mt-3 whitespace-pre-wrap text-[13.5px] leading-relaxed text-foreground">{a.message}</p>

                {!isActive && (
                  <span className="mt-3 inline-block rounded bg-muted-foreground/10 px-2 py-1 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">
                    HIDDEN FROM MEMBERS
                  </span>
                )}
              </div>
            );
          })}
        </div>
      )}

      <Pagination page={page} totalPages={totalPages} onPageChange={setPage} />
    </div>
  );
}
