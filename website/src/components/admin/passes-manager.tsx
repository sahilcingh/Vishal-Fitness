"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Plus, Search, X, Pencil, Check } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { formatINR } from "@/lib/format";
import { PassFormModal } from "@/components/admin/pass-form-modal";
import { Pagination, paginate } from "@/components/admin/pagination";

const PAGE_SIZE = 12;

export type GymPass = {
  id: string;
  name: string;
  price: number;
  duration_days: number;
  features: string[] | null;
  is_active: boolean;
};

export function PassesManager({ passes }: { passes: GymPass[] }) {
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [formPass, setFormPass] = useState<GymPass | "new" | null>(null);
  const [togglingId, setTogglingId] = useState<string | null>(null);
  const [listError, setListError] = useState<string | null>(null);
  const [justAdded, setJustAdded] = useState(false);

  const normalizedQuery = query.trim().toLowerCase();
  const filtered = normalizedQuery
    ? passes.filter((p) => p.name.toLowerCase().includes(normalizedQuery))
    : passes;
  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const pageItems = paginate(filtered, page, PAGE_SIZE);

  async function toggleActive(pass: GymPass) {
    setTogglingId(pass.id);
    setListError(null);
    const supabase = createClient();
    try {
      const { error } = await supabase.from("gym_passes").update({ is_active: !pass.is_active }).eq("id", pass.id);
      if (error) {
        setListError("Could not update this pass. Please try again.");
        return;
      }
      router.refresh();
    } catch {
      setListError("Could not update this pass. Please try again.");
    } finally {
      setTogglingId(null);
    }
  }

  return (
    <>
      <div className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <label className="flex max-w-sm flex-1 items-center gap-2.5 rounded-xl border border-border bg-card px-3.5 py-2.5">
          <Search className="size-4 shrink-0 text-muted-foreground" />
          <input
            value={query}
            onChange={(e) => {
              setQuery(e.target.value);
              setPage(1);
            }}
            placeholder="Search passes..."
            className="w-full bg-transparent text-[13.5px] outline-none placeholder:text-muted-foreground"
          />
          {query && (
            <button
              type="button"
              onClick={() => {
                setQuery("");
                setPage(1);
              }}
              aria-label="Clear search"
            >
              <X className="size-4 text-muted-foreground" />
            </button>
          )}
        </label>
        <button
          type="button"
          onClick={() => setFormPass("new")}
          className="btn-shine flex items-center justify-center gap-2 rounded-xl bg-brand px-4 py-2.5 text-[13px] font-bold text-on-brand"
        >
          <Plus className="size-[15px]" />
          Add Pass
        </button>
      </div>

      {listError && (
        <div className="mb-4 rounded-xl bg-danger/10 px-3.5 py-3 text-[13px] text-danger">{listError}</div>
      )}

      {justAdded && (
        <div className="mb-4 rounded-xl bg-brand/10 px-3.5 py-3 text-[13px] text-brand-onlight dark:text-brand">
          Pass added.
        </div>
      )}

      {filtered.length === 0 ? (
        <div className="rounded-[20px] border border-border bg-card p-16 text-center text-[13px] text-muted-foreground shadow-sm">
          {normalizedQuery ? `No results for "${query.trim()}".` : "No passes configured."}
        </div>
      ) : (
        <div className="grid items-start grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {pageItems.map((pass) => (
            <PassCard
              key={pass.id}
              pass={pass}
              busy={togglingId === pass.id}
              onToggle={() => toggleActive(pass)}
              onEdit={() => setFormPass(pass)}
            />
          ))}
        </div>
      )}

      <Pagination page={page} totalPages={totalPages} onPageChange={setPage} />

      <PassFormModal
        pass={formPass === "new" ? null : formPass}
        open={formPass !== null}
        onClose={() => setFormPass(null)}
        onSaved={() => {
          const wasAdd = formPass === "new";
          setFormPass(null);
          router.refresh();
          if (wasAdd) {
            setQuery("");
            setPage(1);
            setJustAdded(true);
            setTimeout(() => setJustAdded(false), 2500);
          }
        }}
      />
    </>
  );
}

function PassCard({
  pass,
  busy,
  onToggle,
  onEdit,
}: {
  pass: GymPass;
  busy: boolean;
  onToggle: () => void;
  onEdit: () => void;
}) {
  const features = pass.features ?? [];
  return (
    <div className={`card-hover rounded-[20px] border border-border bg-card p-5 shadow-sm ${pass.is_active ? "" : "opacity-60"}`}>
      <div className="flex items-start justify-between gap-3">
        <h3 className="min-w-0 truncate font-display text-[20px] font-bold leading-tight">{pass.name}</h3>
        <div className="flex shrink-0 items-center gap-3">
          <ToggleSwitch
            checked={pass.is_active}
            disabled={busy}
            onChange={onToggle}
            label={pass.is_active ? `Deactivate ${pass.name}` : `Activate ${pass.name}`}
          />
          <button
            type="button"
            onClick={onEdit}
            aria-label={`Edit ${pass.name}`}
            className="grid size-8 shrink-0 place-items-center rounded-lg border border-border text-brand"
          >
            <Pencil className="size-[15px]" />
          </button>
        </div>
      </div>

      <div className="mt-1.5 flex items-baseline gap-2">
        <span className="num font-display text-[24px] font-bold">{formatINR(pass.price)}</span>
        <span className="text-[13px] text-muted-foreground">/ {pass.duration_days} days</span>
      </div>

      {!pass.is_active && (
        <span className="mt-2 inline-block rounded-md bg-muted px-2 py-0.5 text-[10.5px] font-semibold uppercase tracking-wide text-muted-foreground">
          Inactive
        </span>
      )}

      <div className="mt-3.5 border-t border-border pt-3.5">
        <div className="text-[10.5px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">Includes</div>
        {features.length === 0 ? (
          <p className="mt-2 text-[13px] text-muted-foreground">No features listed.</p>
        ) : (
          <ul className="mt-2 flex flex-col gap-1.5">
            {features.map((f, i) => (
              <li key={i} className="flex items-start gap-2 text-[13px]">
                <Check className="mt-0.5 size-3.5 shrink-0 text-brand" />
                <span>{f}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

function ToggleSwitch({
  checked,
  disabled,
  onChange,
  label,
}: {
  checked: boolean;
  disabled: boolean;
  onChange: () => void;
  label: string;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={onChange}
      className={`relative h-[22px] w-[38px] shrink-0 rounded-full transition-colors disabled:opacity-50 ${
        checked ? "bg-brand" : "bg-muted"
      }`}
    >
      <span
        className={`absolute top-[2px] left-[2px] size-[18px] rounded-full bg-white shadow transition-transform ${
          checked ? "translate-x-[18px]" : "translate-x-0"
        }`}
      />
    </button>
  );
}
