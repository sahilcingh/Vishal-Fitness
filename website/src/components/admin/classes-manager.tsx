"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import {
  Search,
  X,
  Plus,
  Pencil,
  Trash2,
  Loader2,
  CalendarDays,
  CalendarClock,
  Users,
  Type,
  UserRound,
  Tag,
  Timer,
  Gauge,
  Clock,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Modal } from "@/components/admin/modal";
import { Pagination, paginate } from "@/components/admin/pagination";
import type { ClassRow } from "@/app/admin/classes/page";

const PAGE_SIZE = 12;

const INTENSITIES = ["low", "medium", "high"] as const;

function toYMD(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
function parseYMD(s: string) {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}
function addDays(s: string, days: number) {
  const d = parseYMD(s);
  d.setDate(d.getDate() + days);
  return toYMD(d);
}
function toHM(d: Date) {
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}
// Mirrors DateTime(...).toIso8601String() on a *local* (non-UTC) DateTime in
// the Flutter screen - a naive "YYYY-MM-DDTHH:mm:00" string with no timezone
// suffix. Deliberately NOT using Date#toISOString() here, which would convert
// to UTC and shift the wall-clock time the admin actually picked.
function toLocalNaiveISOString(dateStr: string, timeStr: string) {
  return `${dateStr}T${timeStr}:00`;
}
// item['start_time'] has no timezone suffix, so `new Date(...)` parses it as
// local wall-clock time - matching Dart's DateTime.parse() behavior on a
// naive string. Do not swap this for a UTC-aware parse.
function prettyDateTime(raw: string) {
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return raw;
  const datePart = d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
  const timePart = d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit", hour12: true });
  return `${datePart} • ${timePart}`;
}
function parseIntOr(v: string, fallback: number) {
  const n = parseInt(v, 10);
  return Number.isNaN(n) ? fallback : n;
}

const CHIP_TONE = {
  // text-aqua-onlight is a darkened aqua that clears WCAG AA contrast on the
  // light-mode card background; dark:text-aqua restores the brighter token
  // for dark mode, where it already has enough contrast.
  aqua: "border-aqua/20 bg-aqua/10 text-aqua-onlight dark:text-aqua",
  muted: "border-border bg-muted text-muted-foreground",
  pulse: "border-pulse/20 bg-pulse/10 text-pulse",
} as const;

function Chip({ tone, children }: { tone: keyof typeof CHIP_TONE; children: React.ReactNode }) {
  return (
    <span className={`rounded-md border px-2 py-1 text-[10px] font-semibold uppercase tracking-wide ${CHIP_TONE[tone]}`}>
      {children}
    </span>
  );
}

export function ClassesManager({ classes }: { classes: ClassRow[] }) {
  const router = useRouter();
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [formOpen, setFormOpen] = useState(false);
  const [editingClass, setEditingClass] = useState<ClassRow | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [listError, setListError] = useState<string | null>(null);
  const [justAdded, setJustAdded] = useState(false);

  const query = search.trim().toLowerCase();
  const filtered = query
    ? classes.filter(
        (c) => (c.title ?? "").toLowerCase().includes(query) || (c.trainer_name ?? "").toLowerCase().includes(query),
      )
    : classes;
  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const pageItems = paginate(filtered, page, PAGE_SIZE);

  function openAdd() {
    setEditingClass(null);
    setFormOpen(true);
  }
  function openEdit(c: ClassRow) {
    setEditingClass(c);
    setFormOpen(true);
  }

  function handleSaved() {
    // editingClass is null only for the "add" flow (openAdd), so this
    // distinguishes a fresh class from an edit without threading extra
    // state through the form.
    const wasAdd = editingClass === null;
    router.refresh();
    if (wasAdd) {
      setSearch("");
      setPage(1);
      setJustAdded(true);
      setTimeout(() => setJustAdded(false), 2500);
    }
  }

  async function handleDelete(c: ClassRow) {
    if (!window.confirm(`Delete "${c.title}"? This cannot be undone.`)) return;
    setDeletingId(c.id);
    setListError(null);
    const supabase = createClient();
    try {
      const { error } = await supabase.from("classes").delete().eq("id", c.id);
      if (error) {
        setListError("Could not delete this class. Please try again.");
        return;
      }
      router.refresh();
    } catch {
      setListError("Could not delete this class. Please try again.");
    } finally {
      setDeletingId(null);
    }
  }

  return (
    <>
      <div className="mb-5 flex flex-wrap items-center gap-3">
        <div className="relative min-w-[240px] flex-1">
          <Search className="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <input
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPage(1);
            }}
            placeholder="Search by title or instructor..."
            className="w-full rounded-xl border border-border bg-card py-2.5 pl-10 pr-9 text-[13.5px] outline-none focus:border-brand"
          />
          {search && (
            <button
              onClick={() => {
                setSearch("");
                setPage(1);
              }}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground"
              aria-label="Clear search"
            >
              <X className="size-4" />
            </button>
          )}
        </div>
        <button
          onClick={openAdd}
          className="btn-shine flex shrink-0 items-center gap-2 rounded-xl bg-brand px-4 py-2.5 text-[13px] font-bold text-on-brand"
        >
          <Plus className="size-4" />
          Add Class
        </button>
      </div>

      {listError && (
        <div className="mb-4 rounded-xl bg-danger/10 px-3.5 py-3 text-[13px] text-danger">{listError}</div>
      )}

      {justAdded && (
        <div className="mb-4 rounded-xl bg-brand/10 px-3.5 py-3 text-[13px] text-brand-onlight dark:text-brand">
          Class added.
        </div>
      )}

      {filtered.length === 0 ? (
        <div className="flex flex-col items-center gap-3 rounded-[20px] border border-border bg-card px-6 py-16 text-center">
          <CalendarClock className="size-9 text-muted-foreground" />
          <p className="text-[13px] text-muted-foreground">
            {query ? `No results for "${query}".` : "No classes scheduled."}
          </p>
        </div>
      ) : (
        <div className="grid items-start grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {pageItems.map((c) => (
            <div key={c.id} className="card-hover rounded-[20px] border border-border bg-card p-5 shadow-sm">
              <div className="flex items-start justify-between gap-2">
                <h3 className="font-display text-[17px] font-bold leading-snug">{c.title}</h3>
                <div className="flex shrink-0 items-center gap-2">
                  <button
                    onClick={() => openEdit(c)}
                    className="grid size-8 place-items-center rounded-lg text-brand hover:bg-brand/10"
                    aria-label="Edit class"
                  >
                    <Pencil className="size-4" />
                  </button>
                  <button
                    onClick={() => handleDelete(c)}
                    disabled={deletingId === c.id}
                    className="grid size-8 place-items-center rounded-lg text-danger hover:bg-danger/10 disabled:opacity-50"
                    aria-label="Delete class"
                  >
                    {deletingId === c.id ? <Loader2 className="size-4 animate-spin" /> : <Trash2 className="size-4" />}
                  </button>
                </div>
              </div>
              <p className="mt-1 text-[13px] text-muted-foreground">Instructor: {c.trainer_name}</p>

              <div className="mt-3 flex flex-wrap gap-2">
                <Chip tone="aqua">{c.category}</Chip>
                <Chip tone="muted">{c.duration_minutes} min</Chip>
                <Chip tone="pulse">{(c.intensity_level ?? "").toUpperCase()}</Chip>
              </div>

              <div className="mt-4 flex items-center justify-between border-t border-border pt-3 text-[13px] text-muted-foreground">
                <span className="flex items-center gap-1.5">
                  <CalendarDays className="size-3.5" />
                  {prettyDateTime(c.start_time)}
                </span>
                <span className="flex items-center gap-1.5">
                  <Users className="size-3.5" />
                  Cap: {c.total_capacity}
                </span>
              </div>
            </div>
          ))}
        </div>
      )}

      <Pagination page={page} totalPages={totalPages} onPageChange={setPage} />

      <Modal open={formOpen} onClose={() => setFormOpen(false)} maxWidthClass="max-w-[480px]">
        <ClassForm existingClass={editingClass} onClose={() => setFormOpen(false)} onSaved={handleSaved} />
      </Modal>
    </>
  );
}

function ClassForm({
  existingClass,
  onClose,
  onSaved,
}: {
  existingClass: ClassRow | null;
  onClose: () => void;
  onSaved: () => void;
}) {
  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const initial = existingClass ? new Date(existingClass.start_time) : tomorrow;

  const [title, setTitle] = useState(existingClass?.title ?? "");
  const [instructor, setInstructor] = useState(existingClass?.trainer_name ?? "");
  const [category, setCategory] = useState(existingClass?.category ?? "HIIT");
  const [duration, setDuration] = useState(existingClass?.duration_minutes?.toString() ?? "45");
  const [capacity, setCapacity] = useState(existingClass?.total_capacity?.toString() ?? "20");
  const [intensity, setIntensity] = useState(existingClass?.intensity_level ?? "medium");
  const [date, setDate] = useState(toYMD(initial));
  const [time, setTime] = useState(existingClass ? toHM(initial) : toHM(now));

  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const todayYMD = toYMD(now);
  const maxYMD = addDays(todayYMD, 365);

  async function handleSave() {
    // Mirrors the empty-field guard in _showClassForm()'s Save handler.
    if (!title.trim() || !instructor.trim()) {
      setError("Title and instructor are required.");
      return;
    }
    const durationNum = parseIntOr(duration, 45);
    const capacityNum = parseIntOr(capacity, 20);
    // Flutter's int.tryParse(...) ?? fallback lets 0 slip through silently -
    // a 0-minute or 0-capacity class is never bookable, so guard against it here.
    if (durationNum < 1) {
      setError("Duration must be at least 1 minute.");
      return;
    }
    if (capacityNum < 1) {
      setError("Capacity must be at least 1.");
      return;
    }
    // The date input already blocks picking a past date (min={todayYMD}), but
    // "today" + an already-passed time still slips through since the time
    // input has no such guard - check it here at submit time.
    const submitNow = new Date();
    if (date === toYMD(submitNow) && time <= toHM(submitNow)) {
      setError("That time has already passed today. Please choose a later time.");
      return;
    }
    setError(null);
    setSaving(true);
    const supabase = createClient();
    // durationNum/capacityNum are already guarded to be >= 1 above.
    // NOTE: only client-side validated; add a CHECK constraint on
    // classes.duration_minutes / classes.total_capacity at the DB level for a
    // real backstop against a client that bypasses this form entirely.
    const payload = {
      title: title.trim(),
      trainer_name: instructor.trim(),
      category: category.trim().toUpperCase(),
      duration_minutes: durationNum,
      total_capacity: capacityNum,
      intensity_level: intensity,
      start_time: toLocalNaiveISOString(date, time),
    };
    try {
      const { error: dbError } = existingClass
        ? await supabase.from("classes").update(payload).eq("id", existingClass.id)
        : await supabase.from("classes").insert(payload);
      if (dbError) throw dbError;
      onSaved();
      onClose();
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      setError(`Could not save this class: ${detail}`);
    } finally {
      setSaving(false);
    }
  }

  return (
    <>
      <div className="text-[17px] font-bold">{existingClass ? "Edit Class" : "Add New Class"}</div>

      <div className="mt-4 flex flex-col gap-3">
        <FormField icon={Type} label="Title" value={title} onChange={setTitle} />
        <FormField icon={UserRound} label="Instructor" value={instructor} onChange={setInstructor} />
        <FormField
          icon={Tag}
          label="Category (e.g., HIIT, YOGA)"
          value={category}
          onChange={setCategory}
          inputClassName="uppercase"
        />

        <div className="grid grid-cols-2 gap-3">
          <FormField
            icon={Timer}
            label="Duration (min)"
            value={duration}
            onChange={(v) => setDuration(v.replace(/\D/g, ""))}
            inputMode="numeric"
          />
          <FormField
            icon={Users}
            label="Capacity"
            value={capacity}
            onChange={(v) => setCapacity(v.replace(/\D/g, ""))}
            inputMode="numeric"
          />
        </div>

        <FormSelect
          icon={Gauge}
          label="Intensity"
          value={intensity}
          onChange={setIntensity}
          options={INTENSITIES.map((i) => ({ value: i, label: i.charAt(0).toUpperCase() + i.slice(1) }))}
        />

        <div className="grid grid-cols-2 gap-3">
          <label className="flex items-center gap-2.5 rounded-xl border border-border bg-card px-3.5 py-2.5">
            <CalendarDays className="size-4 shrink-0 text-muted-foreground" />
            <div className="min-w-0 flex-1">
              <div className="text-[11px] text-muted-foreground">Date</div>
              <input
                type="date"
                value={date}
                min={todayYMD}
                max={maxYMD}
                onChange={(e) => setDate(e.target.value)}
                className="mt-0.5 w-full bg-transparent text-[14px] font-medium outline-none"
              />
            </div>
          </label>
          <label className="flex items-center gap-2.5 rounded-xl border border-border bg-card px-3.5 py-2.5">
            <Clock className="size-4 shrink-0 text-muted-foreground" />
            <div className="min-w-0 flex-1">
              <div className="text-[11px] text-muted-foreground">Time</div>
              <input
                type="time"
                value={time}
                onChange={(e) => setTime(e.target.value)}
                className="mt-0.5 w-full bg-transparent text-[14px] font-medium outline-none"
              />
            </div>
          </label>
        </div>
      </div>

      {error && <div className="mt-4 rounded-xl bg-danger/10 px-3.5 py-3 text-[13px] text-danger">{error}</div>}

      <div className="mt-5 flex gap-2.5">
        <button
          type="button"
          onClick={onClose}
          className="flex-1 rounded-xl border border-border py-2.5 text-[14px] font-semibold text-muted-foreground"
        >
          Cancel
        </button>
        <button
          type="button"
          onClick={handleSave}
          disabled={saving}
          className="flex-1 rounded-xl bg-brand py-2.5 text-[14px] font-bold text-on-brand disabled:opacity-50"
        >
          {saving ? "Saving…" : "Save"}
        </button>
      </div>
    </>
  );
}

function FormField({
  icon: Icon,
  label,
  value,
  onChange,
  inputMode,
  inputClassName,
}: {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: string;
  onChange: (v: string) => void;
  inputMode?: React.HTMLAttributes<HTMLInputElement>["inputMode"];
  inputClassName?: string;
}) {
  return (
    <label className="flex items-center gap-2.5 rounded-xl border border-border bg-card px-3.5 py-2.5">
      <Icon className="size-4 shrink-0 text-muted-foreground" />
      <div className="min-w-0 flex-1">
        <div className="text-[11px] text-muted-foreground">{label}</div>
        <input
          value={value}
          onChange={(e) => onChange(e.target.value)}
          inputMode={inputMode}
          className={`mt-0.5 w-full bg-transparent text-[14px] font-medium outline-none ${inputClassName ?? ""}`}
        />
      </div>
    </label>
  );
}

function FormSelect({
  icon: Icon,
  label,
  value,
  onChange,
  options,
}: {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: string;
  onChange: (v: string) => void;
  options: { value: string; label: string }[];
}) {
  return (
    <label className="flex items-center gap-2.5 rounded-xl border border-border bg-card px-3.5 py-2.5">
      <Icon className="size-4 shrink-0 text-muted-foreground" />
      <div className="min-w-0 flex-1">
        <div className="text-[11px] text-muted-foreground">{label}</div>
        <select
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className="mt-0.5 w-full bg-transparent text-[14px] font-medium outline-none"
        >
          {options.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
      </div>
    </label>
  );
}
