import type { Metadata } from "next";
import { Sparkles, Flame, TrendingUp, CalendarDays, CalendarCheck } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { nowInIST, istDayKey } from "@/lib/ist-time";

export const metadata: Metadata = { title: "Today" };
export const dynamic = "force-dynamic";

async function safeSelect<T>(promise: PromiseLike<{ data: T[] | null; error: unknown }>) {
  try {
    const { data, error } = await promise;
    if (error) {
      console.error("member/today/page: query failed:", error);
      return [] as T[];
    }
    return data ?? ([] as T[]);
  } catch (err) {
    console.error("member/today/page: query threw:", err);
    return [] as T[];
  }
}

function toYMD(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

// Mirrors _computeStreak() in dashboard_screen.dart — consecutive IST
// calendar days with a check-in, counting back from today (or yesterday, if
// today's check-in hasn't happened yet so an existing streak isn't wiped
// out mid-day).
function computeStreak(checkInDates: Set<string>, now: Date) {
  if (checkInDates.size === 0) return 0;
  const todayKey = toYMD(now);
  const start = new Date(now);
  if (!checkInDates.has(todayKey)) start.setDate(start.getDate() - 1);

  let streak = 0;
  const cursor = new Date(start);
  while (checkInDates.has(toYMD(cursor))) {
    streak++;
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
}

// classes.start_time is a naive local (IST) string with no timezone suffix
// (matches the admin Classes page's own storage convention) — compare
// against the same naive shape, not a real UTC instant.
function naiveISO(d: Date) {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

function greeting(hour: number) {
  if (hour >= 4 && hour < 12) return "Good morning,";
  if (hour >= 12 && hour < 17) return "Good afternoon,";
  return "Good evening,";
}

export default async function TodayPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const nowReal = new Date();
  const now = nowInIST();
  const sevenDaysAgoIso = new Date(nowReal.getTime() - 7 * 86_400_000).toISOString();
  const sixtyDaysAgoIso = new Date(nowReal.getTime() - 60 * 86_400_000).toISOString();

  const [profile, checkIns, weekLogs, upcomingClasses] = await Promise.all([
    supabase.from("profiles").select("full_name").eq("id", user.id).maybeSingle(),
    safeSelect<{ checked_in_at: string }>(
      supabase.from("check_ins").select("checked_in_at").eq("user_id", user.id).gte("checked_in_at", sixtyDaysAgoIso),
    ),
    safeSelect<{ volume_kg: number }>(
      supabase.from("workout_logs").select("volume_kg").eq("user_id", user.id).gte("performed_at", sevenDaysAgoIso),
    ),
    safeSelect<{ title: string | null; start_time: string }>(
      supabase.from("classes").select("title, start_time").gt("start_time", naiveISO(now)).order("start_time", { ascending: true }).limit(2),
    ),
  ]);

  const fullName = profile.data?.full_name;
  const displayName = fullName?.trim()
    ? fullName.trim()
    : (() => {
        const prefix = (user.email ?? "athlete").split("@")[0];
        return prefix.charAt(0).toUpperCase() + prefix.slice(1);
      })();

  const checkInDates = new Set(checkIns.map((c) => istDayKey(c.checked_in_at)));
  const streak = computeStreak(checkInDates, now);
  const weekVolume = weekLogs.reduce((sum, l) => sum + (l.volume_kg ?? 0), 0);
  const weekSessions = weekLogs.length;

  const streakText =
    streak === 0
      ? "Start your streak with today's check-in."
      : streak === 1
        ? "Great start! Come back tomorrow to keep it going."
        : "You're on fire! Keep the streak alive.";

  const dateStr = now.toLocaleDateString("en-US", { weekday: "short", day: "numeric", month: "short" }).toUpperCase();

  return (
    <div className="mx-auto max-w-[820px]">
      <div className="flex items-center gap-2">
        <Sparkles className="size-4 text-energy" />
        <span className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">{dateStr}</span>
      </div>

      <h1 className="mt-6 font-display text-[32px] font-bold leading-[1.1]">
        <span className="block">{greeting(now.getHours())}</span>
        <span className="block bg-gradient-to-r from-sun via-energy to-pulse bg-clip-text text-transparent">{displayName}.</span>
      </h1>

      <div className="mt-8 grid grid-cols-1 gap-4 lg:grid-cols-[1.4fr_1fr] lg:items-stretch">
        <div className="relative overflow-hidden rounded-[20px] bg-[linear-gradient(135deg,#0f0f0f,#252525)] p-6 shadow-lg">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Flame className="size-4 text-sun" />
              <span className="text-[11px] font-bold uppercase tracking-[0.14em] text-white/90">Current Streak</span>
            </div>
            <div className="grid size-9 place-items-center rounded-full bg-black/30">
              <div className="grid size-8 place-items-center rounded-full bg-gradient-to-br from-energy to-pulse">
                <Flame className="size-4 text-white" />
              </div>
            </div>
          </div>
          <div className="mt-2 flex items-baseline gap-3">
            <span className="num font-display bg-gradient-to-br from-energy to-pulse bg-clip-text text-[56px] font-bold leading-none text-transparent">
              {streak}
            </span>
            <span className="text-[16px] font-semibold text-white">days on fire</span>
          </div>
          <div className="mt-5 flex gap-1">
            {Array.from({ length: 12 }, (_, i) => (
              <div key={i} className={`h-1 flex-1 rounded-full ${i < Math.min(streak, 12) ? "bg-white/85" : "bg-white/15"}`} />
            ))}
          </div>
          <p className="mt-4 text-[13px] font-medium text-white/70">{streakText}</p>
        </div>

        <div className="grid grid-cols-2 gap-4 lg:grid-cols-1">
          <StatCard label="Week Volume" value={`${Math.round(weekVolume).toLocaleString("en-IN")} kg`} icon={TrendingUp} color="bg-aqua" />
          <StatCard label="Sessions / 7d" value={String(weekSessions)} icon={CalendarDays} color="bg-pulse" />
        </div>
      </div>

      <div className="mt-8">
        <div className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">Up Next This Week</div>
        <div className="mt-4">
          {upcomingClasses.length === 0 ? (
            <div className="flex items-center gap-3 rounded-[20px] border border-border/50 bg-card px-5 py-5">
              <CalendarCheck className="size-5 text-muted-foreground" />
              <span className="text-[14px] text-muted-foreground">No classes scheduled yet.</span>
            </div>
          ) : (
            <div className="flex flex-col gap-3">
              {upcomingClasses.map((c, i) => {
                const start = new Date(c.start_time);
                return (
                  <div key={i} className="flex overflow-hidden rounded-[20px] border border-border/50 bg-card">
                    <div className="w-1 shrink-0 bg-gradient-to-b from-brand to-aqua" />
                    <div className="flex flex-col items-center justify-center px-4 py-4">
                      <span className="font-display text-[20px] font-bold">
                        {String(start.getHours()).padStart(2, "0")}:{String(start.getMinutes()).padStart(2, "0")}
                      </span>
                      <span className="text-[9px] font-bold uppercase tracking-wide text-muted-foreground">
                        {start.toLocaleDateString("en-US", { weekday: "short", day: "numeric" }).toUpperCase()}
                      </span>
                    </div>
                    <div className="w-px bg-border/60" />
                    <div className="flex flex-1 items-center px-4 py-4">
                      <span className="text-[15px] font-semibold">{c.title ?? "Class"}</span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      <div className="mt-12 pb-8 text-center">
        <a href="https://qyroxis.com" target="_blank" rel="noopener noreferrer" className="text-[11px] font-bold uppercase tracking-[0.14em] text-foreground/50">
          App made by <span className="text-brand underline">Qyroxis</span>
        </a>
      </div>
    </div>
  );
}

function StatCard({
  label,
  value,
  icon: Icon,
  color,
}: {
  label: string;
  value: string;
  icon: React.ComponentType<{ className?: string }>;
  color: string;
}) {
  return (
    <div className="relative overflow-hidden rounded-[20px] border border-border bg-card p-5 shadow-sm">
      <div className="flex items-start justify-between">
        <span className="text-[10px] font-semibold uppercase leading-tight tracking-wide text-muted-foreground">{label}</span>
        <span className={`grid size-7 shrink-0 place-items-center rounded-full ${color}`}>
          <Icon className="size-3.5 text-black" />
        </span>
      </div>
      <div className="num mt-4 font-display text-[24px] font-bold">{value}</div>
    </div>
  );
}
