"use client";

import { useMemo, useState } from "react";
import { Search, X, PlusCircle } from "lucide-react";
import { Modal } from "@/components/admin/modal";
import { EXERCISE_CATEGORIES, ALL_EXERCISES, categoryColor } from "@/lib/exercises";
import { cn } from "@/lib/utils";

export function ExercisePickerModal({
  open,
  onClose,
  onPick,
}: {
  open: boolean;
  onClose: () => void;
  onPick: (name: string, category: string) => void;
}) {
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState<string | null>(null);

  const filtered = useMemo(() => {
    const base = category ? ALL_EXERCISES.filter((e) => e.category === category) : ALL_EXERCISES;
    if (!query.trim()) return base;
    const q = query.trim().toLowerCase();
    return base.filter((e) => e.name.toLowerCase().includes(q));
  }, [query, category]);

  function handlePick(name: string, cat: string) {
    onPick(name, cat);
    setQuery("");
    setCategory(null);
    onClose();
  }

  return (
    <Modal open={open} onClose={onClose} maxWidthClass="max-w-[480px]">
      <div className="text-[17px] font-bold">Add Exercise</div>

      <div className="relative mt-4">
        <Search className="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-brand" />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search exercises…"
          className="h-[46px] w-full rounded-xl border border-transparent bg-muted pl-10 pr-9 text-[14px] outline-none focus:border-brand"
        />
        {query && (
          <button
            onClick={() => setQuery("")}
            aria-label="Clear search"
            className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground"
          >
            <X className="size-4" />
          </button>
        )}
      </div>

      {!query && (
        <div className="mt-3 -mx-1 flex gap-2 overflow-x-auto px-1 pb-1">
          <CategoryChip label="All" active={category === null} onClick={() => setCategory(null)} />
          {EXERCISE_CATEGORIES.map((c) => (
            <CategoryChip key={c.name} label={c.name} active={category === c.name} onClick={() => setCategory(c.name)} />
          ))}
        </div>
      )}

      <div className="mt-3 max-h-[380px] overflow-y-auto">
        {filtered.length === 0 ? (
          <p className="py-8 text-center text-[13px] text-muted-foreground">No exercises match your search.</p>
        ) : (
          <ul className="flex flex-col divide-y divide-border/60">
            {filtered.map((ex) => {
              const color = categoryColor(ex.category);
              return (
                <li key={`${ex.category}-${ex.name}`}>
                  <button
                    onClick={() => handlePick(ex.name, ex.category)}
                    className="flex w-full items-center gap-3 py-2.5 text-left"
                  >
                    <span
                      className={cn("grid size-8 shrink-0 place-items-center rounded-lg", {
                        "bg-energy/12 text-energy": color === "energy",
                        "bg-brand/12 text-brand": color === "brand",
                        "bg-aqua/12 text-aqua": color === "aqua",
                        "bg-pulse/12 text-pulse": color === "pulse",
                        "bg-sun/12 text-sun": color === "sun",
                      })}
                    >
                      <span className="size-2 rounded-full bg-current" />
                    </span>
                    <span className="flex-1">
                      <div className="text-[14px] font-semibold">{ex.name}</div>
                      <div className="text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">{ex.category}</div>
                    </span>
                    <PlusCircle className="size-5 shrink-0 text-brand" />
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </div>
    </Modal>
  );
}

function CategoryChip({ label, active, onClick }: { label: string; active: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "shrink-0 whitespace-nowrap rounded-full border px-3.5 py-1.5 text-[12px] font-semibold transition-colors",
        active ? "border-brand bg-brand text-on-brand" : "border-border text-foreground hover:bg-muted",
      )}
    >
      {label}
    </button>
  );
}
