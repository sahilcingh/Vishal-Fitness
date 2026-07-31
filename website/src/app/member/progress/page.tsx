import type { Metadata } from "next";
import { Sparkles, Activity, Clock, Trophy, History, Dumbbell } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { nowInIST, istDayKey } from "@/lib/ist-time";
import { VolumeChart, type VolumeDay } from "@/components/member/volume-chart";

export const metadata: Metadata = { title: "Progress" };
export const dynamic = "force-dynamic";

async function safeSelect<T>(promise: PromiseLike<{ data: T[] | null; error: unknown }>) {
  try {
    const { data, error } = await promise;
    if (error) {
      console.error("member/progress/page: query failed:", error);
      return [] as T[];
    }
    return data ?? ([] as T[]);
  } catch (err) {
    console.error("member/progress/page: query threw:", err);
    return [] as T[];
  }
}

const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// workout_sessions.started_at / workout_logs.performed_at are real instants
// (timestamptz). Mirrors nowInIST() in ist-time.ts but for an arbitrary given
// instant rather than "now" — needed to render calendar/clock text for a row
// as the gym's IST wall-clock would read it, regardless of the server host's
// own timezone (see ist-time.ts doc comment for why plain local getters on a
// Date built from a real timestamp are unsafe once deployed to a UTC host).
function toIstWallClock(iso: string): Date {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Kolkata",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).formatToParts(new Date(iso));
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? "0");
  const hour = get("hour") % 24;
  return new Date(get("year"), get("month") - 1, get("day"), hour, get("minute"), get("second"));
}

// Matches the Flutter screen's `DateFormat('EEE, d MMM yyyy')`.
function fmtDateLong(iso: string) {
  const d = toIstWallClock(iso);
  return `${WEEKDAYS[d.getDay()]}, ${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
}

// Matches the Flutter screen's `DateFormat('EEE d MMM · HH:mm')`.
function fmtDateTime(iso: string) {
  const d = toIstWallClock(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${WEEKDAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]} · ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function fmtNum(n: number) {
  return Math.round(n).toLocaleString("en-IN");
}

function fmtWeight(kg: number) {
  return Number.isInteger(kg) ? `${kg} kg` : `${kg.toFixed(1)} kg`;
}

type WorkoutLog = { performed_at: string; volume_kg: number | null; duration_min: number | null; name: string | null };
type WorkoutSession = { id: string; name: string | null; started_at: string | null; duration_seconds: number | null };
type WorkoutSet = { exercise_name: string | null; weight_kg: number | null; reps: number | null };

const SESSION_DOT_COLORS = ["bg-brand", "bg-energy", "bg-pulse", "bg-aqua", "bg-sun"];

export default async function ProgressPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const nowReal = new Date();
  const thirtyDaysAgoIso = new Date(nowReal.getTime() - 30 * 86_400_000).toISOString();

  // Mirrors ProgressScreen._fetchLogs() in the Flutter app: workout_logs for
  // the volume chart/totals, workout_sessions for the history list, and
  // workout_sets (joined to workout_sessions for the user_id filter) for
  // personal-record computation. Each read is independently safe via
  // safeSelect — if workout_sessions/workout_sets don't exist yet on this
  // Supabase project, those sections degrade to empty rather than the whole
  // page failing (same effect as the Flutter screen's try/catch fallback,
  // achieved here through the existing per-query safeSelect convention).
  const [logs, sessions, sets] = await Promise.all([
    safeSelect<WorkoutLog>(
      supabase
        .from("workout_logs")
        .select("performed_at, volume_kg, duration_min, name")
        .eq("user_id", user.id)
        .gte("performed_at", thirtyDaysAgoIso)
        .order("performed_at", { ascending: false }),
    ),
    safeSelect<WorkoutSession>(
      supabase
        .from("workout_sessions")
        .select("id, name, started_at, duration_seconds")
        .eq("user_id", user.id)
        .not("finished_at", "is", null)
        .order("started_at", { ascending: false })
        .limit(20),
    ),
    safeSelect<WorkoutSet>(
      supabase
        .from("workout_sets")
        .select("exercise_name, weight_kg, reps, workout_sessions!inner(user_id)")
        .eq("workout_sessions.user_id", user.id)
        .eq("is_warmup", false)
        .not("weight_kg", "is", null)
        .not("reps", "is", null)
        .returns<WorkoutSet[]>(),
    ),
  ]);

  // ── Personal records: heaviest set per exercise ──
  const prMap = new Map<string, { exercise: string; weight: number; reps: number }>();
  for (const s of sets) {
    const name = s.exercise_name?.trim();
    if (!name) continue;
    const weight = s.weight_kg ?? 0;
    const reps = s.reps ?? 0;
    const existing = prMap.get(name);
    if (!existing || weight > existing.weight) prMap.set(name, { exercise: name, weight, reps });
  }
  const personalRecords = Array.from(prMap.values()).sort((a, b) => b.weight - a.weight);

  // ── 14-day daily volume chart, bucketed by IST calendar day ──
  const dayVolumes = new Map<string, number>();
  for (const l of logs) {
    const key = istDayKey(l.performed_at);
    dayVolumes.set(key, (dayVolumes.get(key) ?? 0) + (l.volume_kg ?? 0));
  }
  const today = nowInIST();
  const chartDays: VolumeDay[] = [];
  for (let i = 13; i >= 0; i--) {
    const d = new Date(today.getFullYear(), today.getMonth(), today.getDate() - i);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    chartDays.push({
      short: WEEKDAYS[d.getDay()].charAt(0),
      full: `${WEEKDAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]}`,
      volume: dayVolumes.get(key) ?? 0,
    });
  }

  const totalVolume = logs.reduce((sum, l) => sum + (l.volume_kg ?? 0), 0);
  const totalMinutes = logs.reduce((sum, l) => sum + (l.duration_min ?? 0), 0);
  const sessionCount = logs.length;
  const bestDay = Math.max(0, ...chartDays.map((d) => d.volume));
  const recentLogs = logs.slice(0, 10);

  return (
    <div className="w-full">
      <div className="flex items-center gap-2">
        <Sparkles className="size-4 text-pulse" />
        <span className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">Last 30 Days</span>
      </div>
      <h1 className="mt-2 font-display text-[32px] font-bold leading-[1.1]">
        Progress<span className="text-aqua">.</span>
      </h1>

      <div className="mt-8 grid grid-cols-1 gap-4 lg:grid-cols-[1fr_260px]">
        <div className="relative overflow-hidden rounded-[20px] border border-border bg-card p-6 shadow-sm">
          <div className="pointer-events-none absolute -right-12 -top-12 size-[200px] rounded-full bg-brand/10 dark:bg-brand/5" />
          <div className="pointer-events-none absolute -bottom-5 -left-12 size-[150px] rounded-full bg-aqua/10 dark:bg-aqua/5" />
          <div className="relative">
            <div className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">Total Volume</div>
            <div className="mt-2 flex items-baseline gap-2">
              <span className="num font-display text-[42px] font-bold leading-none text-brand">{fmtNum(totalVolume)}</span>
              <span className="text-[15px] text-muted-foreground">kg lifted</span>
            </div>
            <div className="mt-8">
              <VolumeChart days={chartDays} />
            </div>
          </div>
        </div>

        <div className="grid grid-cols-3 gap-3 lg:grid-cols-1">
          <StatTile icon={Activity} label="Sessions" value={String(sessionCount)} accent="bg-brand/12 text-brand" />
          <StatTile icon={Clock} label="Minutes" value={String(Math.round(totalMinutes))} accent="bg-pulse/12 text-pulse" />
          <StatTile icon={Trophy} label="Best Day" value={bestDay > 0 ? fmtNum(bestDay) : "—"} accent="bg-energy/12 text-energy" />
        </div>
      </div>

      <div className="mt-8 grid grid-cols-1 gap-5 lg:grid-cols-3">
        <ListSection icon={Trophy} iconColor="text-sun" title="Personal Records">
          {personalRecords.length === 0 ? (
            <EmptyRow text="No personal records yet." />
          ) : (
            personalRecords.map((pr) => (
              <div key={pr.exercise} className="flex items-center gap-3 px-4 py-3">
                <span className="grid size-8 shrink-0 place-items-center rounded-lg bg-sun/15 text-sun">
                  <Trophy className="size-[15px]" />
                </span>
                <span className="min-w-0 flex-1 truncate text-[14px] font-semibold">{pr.exercise}</span>
                <span className="shrink-0 text-right">
                  <div className="num text-[13px] font-extrabold text-brand">{fmtWeight(pr.weight)}</div>
                  <div className="text-[9px] font-semibold uppercase text-muted-foreground">× {pr.reps} reps</div>
                </span>
              </div>
            ))
          )}
        </ListSection>

        <ListSection icon={History} iconColor="text-aqua" title="Workout History">
          {sessions.length === 0 ? (
            <EmptyRow text="No completed sessions yet." />
          ) : (
            sessions.map((s) => {
              const mins = Math.floor((s.duration_seconds ?? 0) / 60);
              return (
                <div key={s.id} className="flex items-center gap-3 px-4 py-3">
                  <span className="grid size-8 shrink-0 place-items-center rounded-lg bg-aqua/15 text-aqua">
                    <Dumbbell className="size-[15px]" />
                  </span>
                  <span className="min-w-0 flex-1">
                    <div className="truncate text-[14px] font-semibold">{s.name ?? "Workout"}</div>
                    {s.started_at && <div className="text-[11px] text-muted-foreground">{fmtDateLong(s.started_at)}</div>}
                  </span>
                  {mins > 0 && <span className="num shrink-0 text-[13px] font-semibold text-muted-foreground">{mins}m</span>}
                </div>
              );
            })
          )}
        </ListSection>

        <ListSection icon={Clock} iconColor="text-muted-foreground" title="Recent Sessions">
          {recentLogs.length === 0 ? (
            <EmptyRow text="No sessions logged in the last 30 days." />
          ) : (
            recentLogs.map((l, i) => (
              <div key={i} className="flex items-start gap-3 px-4 py-3">
                <span className={`mt-1.5 size-2 shrink-0 rounded-full ${SESSION_DOT_COLORS[i % SESSION_DOT_COLORS.length]}`} />
                <span className="min-w-0 flex-1">
                  <div className="truncate text-[14px] font-semibold">{l.name ?? "Workout"}</div>
                  <div className="text-[12px] text-muted-foreground">{fmtDateTime(l.performed_at)}</div>
                </span>
                <span className="shrink-0 text-right">
                  <div className="num text-[14px] font-semibold">{fmtNum(l.volume_kg ?? 0)} kg</div>
                  <div className="text-[12px] text-muted-foreground">{l.duration_min ?? 0} min</div>
                </span>
              </div>
            ))
          )}
        </ListSection>
      </div>

      <div className="mt-12 pb-8 text-center">
        <a href="https://qyroxis.com" target="_blank" rel="noopener noreferrer" className="text-[11px] font-bold uppercase tracking-[0.14em] text-foreground/50">
          App made by <span className="text-brand underline">Qyroxis</span>
        </a>
      </div>
    </div>
  );
}

function StatTile({
  icon: Icon,
  label,
  value,
  accent,
}: {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: string;
  accent: string;
}) {
  return (
    <div className="relative overflow-hidden rounded-[20px] border border-border bg-card p-4 shadow-sm">
      <span className={`grid size-7 place-items-center rounded-full ${accent}`}>
        <Icon className="size-3.5" />
      </span>
      <div className="num mt-4 font-display text-[20px] font-bold">{value}</div>
      <div className="mt-0.5 text-[9px] font-semibold uppercase tracking-wide text-muted-foreground">{label}</div>
    </div>
  );
}

function ListSection({
  icon: Icon,
  iconColor,
  title,
  children,
}: {
  icon: React.ComponentType<{ className?: string }>;
  iconColor: string;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div>
      <div className="flex items-center gap-2">
        <Icon className={`size-4 ${iconColor}`} />
        <span className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">{title}</span>
      </div>
      <div className="mt-3 divide-y divide-border/30 rounded-[20px] border border-border bg-card">{children}</div>
    </div>
  );
}

function EmptyRow({ text }: { text: string }) {
  return <div className="px-4 py-6 text-center text-[13px] text-muted-foreground">{text}</div>;
}
