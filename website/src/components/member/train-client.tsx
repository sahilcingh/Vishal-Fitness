"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Play,
  Timer as TimerIcon,
  X,
  Pencil,
  Plus,
  Trash2,
  Check,
  Users,
  Zap,
  History,
  CalendarX2,
  Info,
  PartyPopper,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Modal } from "@/components/admin/modal";
import { ExercisePickerModal } from "@/components/member/exercise-picker-modal";
import { categoryGradientClass } from "@/lib/exercises";
import { cn } from "@/lib/utils";
import type { ClassRow, SessionRow } from "@/app/member/train/page";

// ── Local workout-in-progress model - never persisted until Finish Workout ──

type ActiveSet = { weightKg: number | null; reps: number | null; isDone: boolean; isWarmup: boolean };
type ActiveExercise = { name: string; category: string; sets: ActiveSet[]; previousBest: string | null };

function formatTimer(totalSeconds: number) {
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;
  const mm = String(m).padStart(2, "0");
  const ss = String(s).padStart(2, "0");
  return h > 0 ? `${String(h).padStart(2, "0")}:${mm}:${ss}` : `${mm}:${ss}`;
}

// classes.start_time is a naive local (IST) string with no timezone suffix
// (see naiveISO() in train/page.tsx) - append the IST offset explicitly so it
// parses as the correct real instant, rather than reading it back through
// plain new Date(iso).getHours(), which reflects the *viewer's own* local
// timezone instead of the gym's IST convention.
function parseNaiveIstDate(iso: string): Date {
  return new Date(`${iso}+05:30`);
}

const IST_TIME_FMT = new Intl.DateTimeFormat("en-GB", {
  timeZone: "Asia/Kolkata",
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
});
const IST_DAY_FMT = new Intl.DateTimeFormat("en-US", {
  timeZone: "Asia/Kolkata",
  weekday: "short",
  day: "numeric",
  month: "short",
});

function formatClassTime(iso: string) {
  const d = parseNaiveIstDate(iso);
  if (Number.isNaN(d.getTime())) return "-";
  return IST_TIME_FMT.format(d);
}

function formatClassDay(iso: string) {
  const d = parseNaiveIstDate(iso);
  if (Number.isNaN(d.getTime())) return "-";
  return IST_DAY_FMT.format(d);
}

function formatSessionDay(iso: string) {
  // workout_sessions.started_at is a real timestamptz (set via
  // .toISOString() on insert below), so it already carries a real offset -
  // format it directly through the same IST timezone for display.
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "-";
  return IST_DAY_FMT.format(d);
}

export function TrainClient({
  initialClasses,
  initialSessions,
  userId,
}: {
  initialClasses: ClassRow[];
  initialSessions: SessionRow[];
  userId: string;
}) {
  const router = useRouter();
  const [tab, setTab] = useState<"classes" | "workouts">("classes");

  // Reserve-a-spot info dialog (no DB write - same as the mobile app, which
  // only points members to the front desk to reserve).
  const [reserveClass, setReserveClass] = useState<ClassRow | null>(null);

  // Active workout state
  const [isWorkoutActive, setIsWorkoutActive] = useState(false);
  const [workoutName, setWorkoutName] = useState("Workout");
  const [workoutStart, setWorkoutStart] = useState<Date | null>(null);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [exercises, setExercises] = useState<ActiveExercise[]>([]);

  const [pickerOpen, setPickerOpen] = useState(false);
  const [renameOpen, setRenameOpen] = useState(false);
  const [renameValue, setRenameValue] = useState("");
  const [cancelConfirmOpen, setCancelConfirmOpen] = useState(false);

  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [summary, setSummary] = useState<{ name: string; durationSec: number; setCount: number; volume: number } | null>(null);

  // Tracks progress through the 3-step Finish Workout write so a retry after
  // a partial failure resumes from where it left off instead of re-inserting
  // a duplicate workout_sessions row (or duplicate workout_sets rows).
  const [savedSessionId, setSavedSessionId] = useState<string | null>(null);
  const [setsSaved, setSetsSaved] = useState(false);

  useEffect(() => {
    if (!isWorkoutActive) return;
    const id = setInterval(() => setElapsedSeconds((s) => s + 1), 1000);
    return () => clearInterval(id);
  }, [isWorkoutActive]);

  function startWorkout() {
    setWorkoutName("Workout");
    setWorkoutStart(new Date());
    setElapsedSeconds(0);
    setExercises([]);
    setSaveError(null);
    setSavedSessionId(null);
    setSetsSaved(false);
    setIsWorkoutActive(true);
  }

  function discardWorkout() {
    setIsWorkoutActive(false);
    setExercises([]);
    setSaveError(null);
    setSavedSessionId(null);
    setSetsSaved(false);
    setCancelConfirmOpen(false);
  }

  async function fetchPreviousBest(name: string): Promise<string | null> {
    const supabase = createClient();
    const { data, error } = await supabase
      .from("workout_sets")
      .select("weight_kg, reps, workout_sessions!inner(user_id)")
      .eq("exercise_name", name)
      .eq("workout_sessions.user_id", userId)
      .eq("is_warmup", false)
      .not("weight_kg", "is", null)
      .not("reps", "is", null)
      .order("weight_kg", { ascending: false })
      .limit(1);
    if (error || !data || data.length === 0) return null;
    const row = data[0] as { weight_kg: number | null; reps: number | null };
    if (row.weight_kg == null || row.reps == null) return null;
    const w = row.weight_kg;
    const wLabel = Number.isInteger(w) ? String(w) : w.toFixed(1);
    return `${wLabel} kg × ${row.reps}`;
  }

  function addExercise(name: string, category: string) {
    setExercises((prev) => [...prev, { name, category, sets: [{ weightKg: null, reps: null, isDone: false, isWarmup: false }], previousBest: null }]);
    fetchPreviousBest(name).then((best) => {
      if (!best) return;
      setExercises((prev) => prev.map((e) => (e.name === name && e.previousBest === null ? { ...e, previousBest: best } : e)));
    });
  }

  function removeExercise(idx: number) {
    setExercises((prev) => prev.filter((_, i) => i !== idx));
  }

  function addSet(exerciseIdx: number) {
    setExercises((prev) =>
      prev.map((ex, i) => {
        if (i !== exerciseIdx) return ex;
        const last = ex.sets[ex.sets.length - 1];
        return { ...ex, sets: [...ex.sets, { weightKg: last?.weightKg ?? null, reps: last?.reps ?? null, isDone: false, isWarmup: false }] };
      }),
    );
  }

  function updateSet(exerciseIdx: number, setIdx: number, patch: Partial<ActiveSet>) {
    setExercises((prev) =>
      prev.map((ex, i) => {
        if (i !== exerciseIdx) return ex;
        return { ...ex, sets: ex.sets.map((s, si) => (si === setIdx ? { ...s, ...patch } : s)) };
      }),
    );
  }

  function saveRename() {
    if (renameValue.trim()) setWorkoutName(renameValue.trim());
    setRenameOpen(false);
  }

  async function finishWorkout() {
    const doneSets = exercises.flatMap((e) => e.sets).filter((s) => s.isDone);
    if (doneSets.length === 0) {
      setSaveError("Mark at least one set as done before finishing.");
      return;
    }
    if (!workoutStart) return;

    setSaving(true);
    setSaveError(null);
    const supabase = createClient();
    const finishedAt = new Date();
    const durationSeconds = Math.round((finishedAt.getTime() - workoutStart.getTime()) / 1000);

    // Step 1: workout_sessions. Reuse the session id from a prior attempt
    // (if this is a retry after step 2/3 failed) instead of inserting a
    // second session row for the same workout.
    let sessionId = savedSessionId;
    if (!sessionId) {
      const { data: sessionRow, error: sessionErr } = await supabase
        .from("workout_sessions")
        .insert({
          user_id: userId,
          name: workoutName,
          started_at: workoutStart.toISOString(),
          finished_at: finishedAt.toISOString(),
          duration_seconds: durationSeconds,
        })
        .select("id")
        .single();

      if (sessionErr || !sessionRow) {
        setSaveError(`Failed to save workout: ${sessionErr?.message ?? "unknown error"}`);
        setSaving(false);
        return;
      }
      sessionId = (sessionRow as { id: string }).id;
      setSavedSessionId(sessionId);
    }

    const setsToInsert = exercises.flatMap((exercise) =>
      exercise.sets
        .map((set, idx) => ({ set, setNumber: idx + 1 }))
        .filter(({ set }) => set.isDone)
        .map(({ set, setNumber }) => ({
          session_id: sessionId as string,
          exercise_name: exercise.name,
          set_number: setNumber,
          weight_kg: set.weightKg,
          reps: set.reps,
          is_warmup: set.isWarmup,
        })),
    );

    // Step 2: workout_sets. Skip if a prior attempt already got these saved
    // (a retry here would only be reachable because step 3 failed).
    if (!setsSaved) {
      if (setsToInsert.length > 0) {
        const { error: setsErr } = await supabase.from("workout_sets").insert(setsToInsert);
        if (setsErr) {
          setSaveError(`Workout was saved but the sets failed to save: ${setsErr.message}`);
          setSaving(false);
          return;
        }
      }
      setSetsSaved(true);
    }

    const totalVolume = setsToInsert.reduce((sum, s) => sum + (s.weight_kg ?? 0) * (s.reps ?? 0), 0);

    const { error: logErr } = await supabase.from("workout_logs").insert({
      user_id: userId,
      name: workoutName,
      performed_at: workoutStart.toISOString(),
      volume_kg: totalVolume,
      duration_min: Math.round(durationSeconds / 60),
    });
    if (logErr) {
      setSaveError(`Workout saved, but progress tracking failed to update: ${logErr.message}`);
      setSaving(false);
      return;
    }

    setSaving(false);
    setIsWorkoutActive(false);
    setExercises([]);
    setSavedSessionId(null);
    setSetsSaved(false);
    setSummary({ name: workoutName, durationSec: durationSeconds, setCount: doneSets.length, volume: totalVolume });
    router.refresh();
  }

  const doneSetCount = exercises.flatMap((e) => e.sets).filter((s) => s.isDone).length;

  return (
    <div>
      {!isWorkoutActive && (
        <div className="flex h-12 rounded-2xl bg-muted p-1">
          <button
            onClick={() => setTab("classes")}
            className={cn(
              "flex-1 rounded-xl text-[14px] font-semibold transition-colors",
              tab === "classes" ? "bg-gradient-to-r from-brand to-aqua text-on-brand" : "text-muted-foreground",
            )}
          >
            Classes
          </button>
          <button
            onClick={() => setTab("workouts")}
            className={cn(
              "flex-1 rounded-xl text-[14px] font-semibold transition-colors",
              tab === "workouts" ? "bg-gradient-to-r from-brand to-aqua text-on-brand" : "text-muted-foreground",
            )}
          >
            Workouts
          </button>
        </div>
      )}

      {isWorkoutActive ? (
        <div className="mt-5">
          {/* Workout header */}
          <div className="flex items-center gap-3 rounded-[20px] border border-border bg-card px-5 py-4">
            <button
              onClick={() => {
                setRenameValue(workoutName);
                setRenameOpen(true);
              }}
              className="flex min-w-0 items-center gap-1.5"
            >
              <span className="min-w-0 font-display truncate text-[17px] font-bold">{workoutName}</span>
              <Pencil className="size-3.5 shrink-0 text-muted-foreground" />
            </button>
            <div className="ml-auto flex items-center gap-1.5 rounded-full bg-brand/10 px-3 py-1.5">
              <TimerIcon className="size-3.5 text-brand" />
              <span className="num text-[13px] font-bold text-brand">{formatTimer(elapsedSeconds)}</span>
            </div>
            <button
              onClick={() => setCancelConfirmOpen(true)}
              aria-label="Cancel workout"
              className="grid size-8 shrink-0 place-items-center rounded-full border border-border text-muted-foreground"
            >
              <X className="size-4" />
            </button>
          </div>

          {/* Exercises */}
          <div className="mt-4 flex flex-col gap-4">
            {exercises.map((exercise, exerciseIdx) => (
              <div key={exerciseIdx} className="rounded-[20px] border border-border bg-card">
                <div className="flex items-start gap-3 px-4 pb-2.5 pt-4">
                  <span className={cn("grid size-8 shrink-0 place-items-center rounded-lg bg-gradient-to-br text-white", categoryGradientClass(exercise.category))}>
                    <Zap className="size-4" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[15px] font-bold">{exercise.name}</div>
                    {exercise.previousBest && (
                      <div className="text-[10px] font-bold uppercase tracking-wide text-brand">Previous best: {exercise.previousBest}</div>
                    )}
                  </div>
                  <button onClick={() => removeExercise(exerciseIdx)} aria-label={`Remove ${exercise.name}`} className="text-muted-foreground">
                    <Trash2 className="size-4" />
                  </button>
                </div>

                <div className="px-4">
                  <div className="flex items-center gap-2 pb-1.5 text-[9px] font-bold uppercase tracking-wide text-muted-foreground">
                    <span className="w-7">Set</span>
                    <span className="flex-1">Kg</span>
                    <span className="flex-1">Reps</span>
                    <span className="w-8" />
                  </div>
                </div>

                <div className="flex flex-col px-2 pb-1">
                  {exercise.sets.map((set, setIdx) => (
                    <div
                      key={setIdx}
                      className={cn("flex items-center gap-2 rounded-xl px-2 py-1", set.isDone && "bg-brand/[0.07]")}
                    >
                      <button
                        onClick={() => updateSet(exerciseIdx, setIdx, { isWarmup: !set.isWarmup })}
                        aria-label={`Mark set ${setIdx + 1} as warmup`}
                        aria-pressed={set.isWarmup}
                        className="grid w-7 shrink-0 place-items-center"
                      >
                        {set.isWarmup ? (
                          <span className="text-[11px] font-black text-aqua">W</span>
                        ) : (
                          <span className="num text-[13px] font-bold text-muted-foreground">{setIdx + 1}</span>
                        )}
                      </button>
                      <input
                        inputMode="decimal"
                        placeholder="0"
                        aria-label={`Set ${setIdx + 1} weight (kg)`}
                        value={set.weightKg ?? ""}
                        onChange={(e) => {
                          const raw = e.target.value.replace(/[^0-9.]/g, "");
                          updateSet(exerciseIdx, setIdx, { weightKg: raw === "" ? null : Number(raw) });
                        }}
                        className={cn(
                          "num h-[38px] flex-1 rounded-lg border text-center text-[14px] font-bold outline-none",
                          set.isDone ? "border-brand/30 bg-brand/10 text-brand" : "border-border/60 bg-background text-foreground",
                        )}
                      />
                      <input
                        inputMode="numeric"
                        placeholder="0"
                        aria-label={`Set ${setIdx + 1} reps`}
                        value={set.reps ?? ""}
                        onChange={(e) => {
                          const raw = e.target.value.replace(/[^0-9]/g, "");
                          updateSet(exerciseIdx, setIdx, { reps: raw === "" ? null : Number(raw) });
                        }}
                        className={cn(
                          "num h-[38px] flex-1 rounded-lg border text-center text-[14px] font-bold outline-none",
                          set.isDone ? "border-brand/30 bg-brand/10 text-brand" : "border-border/60 bg-background text-foreground",
                        )}
                      />
                      <button
                        onClick={() => updateSet(exerciseIdx, setIdx, { isDone: !set.isDone })}
                        aria-label={set.isDone ? "Mark set not done" : "Mark set done"}
                        className={cn(
                          "grid size-8 shrink-0 place-items-center rounded-full border-[1.5px]",
                          set.isDone ? "border-brand bg-brand text-white" : "border-border text-transparent",
                        )}
                      >
                        <Check className="size-4" />
                      </button>
                    </div>
                  ))}
                </div>

                <div className="px-4 pb-4 pt-1">
                  <button onClick={() => addSet(exerciseIdx)} className="flex items-center gap-1.5 text-[13px] font-bold text-brand">
                    <Plus className="size-3.5" />
                    Add Set
                  </button>
                </div>
              </div>
            ))}

            <button
              onClick={() => setPickerOpen(true)}
              className="flex items-center justify-center gap-2 rounded-[20px] border-[1.5px] border-brand/40 bg-card py-4 text-[14px] font-bold text-brand"
            >
              <Plus className="size-4" />
              Add Exercise
            </button>
          </div>

          {saveError && <div className="mt-4 rounded-xl bg-danger/10 px-3.5 py-3 text-[13px] text-danger">{saveError}</div>}

          {/* Finish bar */}
          <div className="sticky bottom-0 mt-6 flex items-center gap-4 rounded-[20px] border border-border bg-card px-5 py-4">
            <div className="min-w-0">
              <div className="text-[13px] font-semibold">
                {doneSetCount} set{doneSetCount === 1 ? "" : "s"} done
              </div>
              <div className="num text-[13px] font-bold text-brand">{formatTimer(elapsedSeconds)}</div>
            </div>
            <button
              onClick={finishWorkout}
              disabled={saving}
              className="ml-auto flex-1 rounded-xl bg-brand py-3.5 text-[14px] font-bold text-on-brand disabled:opacity-50"
            >
              {saving ? "Saving…" : "Finish Workout"}
            </button>
          </div>
        </div>
      ) : tab === "classes" ? (
        <div className="mt-5">
          <div className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">Upcoming</div>
          <div className="mt-3 flex flex-col gap-3">
            {initialClasses.length === 0 ? (
              <EmptyState icon={CalendarX2} title="No upcoming classes" subtitle="Check back later. New classes are added by the gym admin regularly." />
            ) : (
              initialClasses.map((cls) => (
                <div key={cls.id} className="card-hover flex overflow-hidden rounded-[20px] border border-border bg-card">
                  <div className="flex flex-col items-center justify-center gap-0.5 px-4 py-4">
                    <span className="num font-display text-[19px] font-bold">{formatClassTime(cls.start_time)}</span>
                    <span className="text-[9px] font-bold uppercase tracking-wide text-muted-foreground">{cls.duration_minutes ?? 0}MIN</span>
                  </div>
                  <div className="w-px bg-border/60" />
                  <div className="flex-1 px-4 py-4">
                    <div className="flex items-start justify-between gap-2">
                      <span className="text-[15px] font-semibold">{cls.title ?? "Class"}</span>
                      {cls.category && (
                        <span className={cn("shrink-0 rounded-full bg-gradient-to-r px-2.5 py-1 text-[9px] font-bold uppercase text-white", categoryGradientClass(cls.category))}>
                          {cls.category}
                        </span>
                      )}
                    </div>
                    <div className="mt-0.5 text-[11px] text-muted-foreground">{formatClassDay(cls.start_time)}</div>
                    {cls.trainer_name && <div className="mt-1 text-[12px] text-muted-foreground">{cls.trainer_name}</div>}
                    <div className="mt-2.5 flex items-center justify-between gap-2">
                      <div className="flex items-center gap-3 text-[12px] text-muted-foreground">
                        {cls.total_capacity != null && (
                          <span className="flex items-center gap-1">
                            <Users className="size-3.5" />
                            {cls.total_capacity} spots
                          </span>
                        )}
                        {cls.intensity_level && (
                          <span className="flex items-center gap-1">
                            <Zap className="size-3.5" />
                            {cls.intensity_level}
                          </span>
                        )}
                      </div>
                      <button
                        onClick={() => setReserveClass(cls)}
                        className={cn("flex items-center gap-1 rounded-full bg-gradient-to-r px-3.5 py-1.5 text-[12px] font-bold text-white", categoryGradientClass(cls.category))}
                      >
                        <Plus className="size-3.5" />
                        Reserve
                      </button>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      ) : (
        <div className="mt-5">
          <button
            onClick={startWorkout}
            className="w-full rounded-[20px] bg-gradient-to-br from-brand to-aqua p-6 text-left shadow-lg shadow-brand/20"
          >
            <span className="grid size-11 place-items-center rounded-xl bg-white/20">
              <Play className="size-5 fill-white text-white" />
            </span>
            <div className="font-display mt-4 text-[22px] font-bold text-white">Start Workout</div>
            <div className="mt-1 text-[13px] font-medium text-white/80">Tap to begin logging your session</div>
          </button>

          <div className="mt-7 text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">Recent Workouts</div>
          <div className="mt-3 flex flex-col gap-2.5">
            {initialSessions.length === 0 ? (
              <EmptyState icon={History} title="No workouts yet" subtitle="Your completed workouts will appear here." />
            ) : (
              initialSessions.map((s) => {
                const mins = Math.floor((s.duration_seconds ?? 0) / 60);
                return (
                  <div key={s.id} className="card-hover flex items-center gap-3.5 rounded-[14px] border border-border bg-card px-4 py-3.5">
                    <span className="grid size-9 shrink-0 place-items-center rounded-[10px] bg-brand/10 text-brand">
                      <History className="size-4" />
                    </span>
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-[14px] font-bold">{s.name ?? "Workout"}</div>
                      <div className="text-[12px] text-muted-foreground">{formatSessionDay(s.started_at)}</div>
                    </div>
                    <span className="num text-[13px] font-semibold text-muted-foreground">{mins > 0 ? `${mins}m` : "-"}</span>
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}

      {/* ── Modals ── */}

      <ExercisePickerModal open={pickerOpen} onClose={() => setPickerOpen(false)} onPick={addExercise} />

      <Modal open={renameOpen} onClose={() => setRenameOpen(false)} maxWidthClass="max-w-[360px]">
        <div className="text-[17px] font-bold">Workout Name</div>
        <input
          autoFocus
          value={renameValue}
          onChange={(e) => setRenameValue(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && saveRename()}
          className="mt-4 h-[46px] w-full rounded-xl border border-border bg-card px-4 text-[14px] outline-none focus:border-brand"
        />
        <div className="mt-4 flex justify-end gap-3">
          <button onClick={() => setRenameOpen(false)} className="text-[13px] font-semibold text-muted-foreground">
            Cancel
          </button>
          <button onClick={saveRename} className="rounded-lg bg-brand px-4 py-2 text-[13px] font-bold text-on-brand">
            Save
          </button>
        </div>
      </Modal>

      <Modal open={cancelConfirmOpen} onClose={() => setCancelConfirmOpen(false)} maxWidthClass="max-w-[360px]">
        <div className="text-[17px] font-bold">Discard Workout?</div>
        <p className="mt-2 text-[13px] text-muted-foreground">All progress will be lost.</p>
        <div className="mt-5 flex justify-end gap-3">
          <button onClick={() => setCancelConfirmOpen(false)} className="text-[13px] font-semibold text-brand">
            Keep Going
          </button>
          <button onClick={discardWorkout} className="rounded-lg bg-danger px-4 py-2 text-[13px] font-bold text-white">
            Discard
          </button>
        </div>
      </Modal>

      <Modal open={reserveClass !== null} onClose={() => setReserveClass(null)} maxWidthClass="max-w-[400px]">
        {reserveClass && (
          <>
            <div className="text-[17px] font-bold">Reserve a Spot</div>
            <div className="mt-3 text-[15px] font-bold">{reserveClass.title ?? "Class"}</div>
            <div className="mt-0.5 text-[13px] text-muted-foreground">
              {formatClassDay(reserveClass.start_time)} · {formatClassTime(reserveClass.start_time)}
            </div>
            <div className="mt-4 flex items-start gap-2.5 rounded-xl border border-brand/20 bg-brand/8 p-3">
              <Info className="mt-0.5 size-4 shrink-0 text-brand" />
              <span className="text-[12.5px] font-medium text-brand">Visit the front desk or contact staff to reserve your spot.</span>
            </div>
            <div className="mt-5 flex justify-end">
              <button onClick={() => setReserveClass(null)} className="text-[13px] font-semibold text-muted-foreground">
                Close
              </button>
            </div>
          </>
        )}
      </Modal>

      <Modal open={summary !== null} onClose={() => setSummary(null)} maxWidthClass="max-w-[380px]">
        {summary && (
          <>
            <div className="flex items-center gap-3">
              <span className="grid size-9 place-items-center rounded-full bg-brand/12 text-brand">
                <PartyPopper className="size-5" />
              </span>
              <div className="font-display text-[19px] font-bold">Workout Done!</div>
            </div>
            <div className="mt-1 text-[13px] text-muted-foreground">{summary.name}</div>
            <div className="mt-5 flex justify-around text-center">
              <SummaryStat label="Duration" value={formatTimer(summary.durationSec)} />
              <SummaryStat label="Sets" value={String(summary.setCount)} />
              <SummaryStat label="Volume" value={`${Math.round(summary.volume).toLocaleString("en-IN")} kg`} />
            </div>
            <button onClick={() => setSummary(null)} className="mt-6 w-full rounded-xl bg-brand py-3 text-[14px] font-bold text-on-brand">
              Nice!
            </button>
          </>
        )}
      </Modal>
    </div>
  );
}

function EmptyState({ icon: Icon, title, subtitle }: { icon: React.ComponentType<{ className?: string }>; title: string; subtitle: string }) {
  return (
    <div className="flex flex-col items-center rounded-[20px] border border-border bg-card px-8 py-10 text-center">
      <span className="grid size-14 place-items-center rounded-full bg-brand/10 text-brand">
        <Icon className="size-6" />
      </span>
      <div className="mt-4 text-[15px] font-bold">{title}</div>
      <p className="mt-1.5 text-[13px] text-muted-foreground">{subtitle}</p>
    </div>
  );
}

function SummaryStat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="num font-display text-[18px] font-bold">{value}</div>
      <div className="mt-0.5 text-[9px] font-bold uppercase tracking-wide text-muted-foreground">{label}</div>
    </div>
  );
}
