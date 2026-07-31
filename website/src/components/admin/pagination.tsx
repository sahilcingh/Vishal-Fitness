"use client";

import { ChevronLeft, ChevronRight } from "lucide-react";

export function paginate<T>(items: T[], page: number, pageSize: number): T[] {
  const start = (page - 1) * pageSize;
  return items.slice(start, start + pageSize);
}

export function Pagination({
  page,
  totalPages,
  onPageChange,
}: {
  page: number;
  totalPages: number;
  onPageChange: (page: number) => void;
}) {
  if (totalPages <= 1) return null;
  // Clamp defensively — a filtered list can shrink out from under a
  // previously-valid page number (e.g. narrowing a search query).
  const current = Math.min(Math.max(page, 1), totalPages);

  return (
    <div className="mt-4 flex items-center justify-center gap-3">
      <button
        type="button"
        onClick={() => onPageChange(current - 1)}
        disabled={current <= 1}
        className="grid size-8 shrink-0 place-items-center rounded-lg border border-border disabled:opacity-40"
        aria-label="Previous page"
      >
        <ChevronLeft className="size-4" />
      </button>
      <span className="num text-[12px] font-semibold text-muted-foreground">
        Page {current} of {totalPages}
      </span>
      <button
        type="button"
        onClick={() => onPageChange(current + 1)}
        disabled={current >= totalPages}
        className="grid size-8 shrink-0 place-items-center rounded-lg border border-border disabled:opacity-40"
        aria-label="Next page"
      >
        <ChevronRight className="size-4" />
      </button>
    </div>
  );
}
