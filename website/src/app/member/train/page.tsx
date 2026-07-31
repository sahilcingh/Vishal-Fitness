import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { nowInIST } from "@/lib/ist-time";
import { TrainClient } from "@/components/member/train-client";

export const metadata: Metadata = { title: "Train" };
export const dynamic = "force-dynamic";

async function safeSelect<T>(promise: PromiseLike<{ data: T[] | null; error: unknown }>) {
  try {
    const { data, error } = await promise;
    if (error) {
      console.error("member/train/page: query failed:", error);
      return [] as T[];
    }
    return data ?? ([] as T[]);
  } catch (err) {
    console.error("member/train/page: query threw:", err);
    return [] as T[];
  }
}

// classes.start_time is a naive local (IST) string with no timezone suffix
// (same convention established in member/today/page.tsx) — compare against
// the same naive shape, not a real UTC instant.
function naiveISO(d: Date) {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`;
}

export type ClassRow = {
  id: string;
  title: string | null;
  start_time: string;
  duration_minutes: number | null;
  category: string | null;
  trainer_name: string | null;
  total_capacity: number | null;
  intensity_level: string | null;
};

export type SessionRow = {
  id: string;
  name: string | null;
  started_at: string;
  finished_at: string | null;
  duration_seconds: number | null;
};

export default async function TrainPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const now = nowInIST();

  const [classes, sessions] = await Promise.all([
    safeSelect<ClassRow>(
      supabase
        .from("classes")
        .select("id, title, start_time, duration_minutes, category, trainer_name, total_capacity, intensity_level")
        .gt("start_time", naiveISO(now))
        .order("start_time", { ascending: true })
        .limit(10),
    ),
    safeSelect<SessionRow>(
      supabase
        .from("workout_sessions")
        .select("id, name, started_at, finished_at, duration_seconds")
        .eq("user_id", user.id)
        .not("finished_at", "is", null)
        .order("started_at", { ascending: false })
        .limit(5),
    ),
  ]);

  return (
    <div className="mx-auto max-w-[820px]">
      <div className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">Workouts &amp; Classes</div>
      <h1 className="font-display mt-1 text-[28px] font-bold">Train</h1>

      <div className="mt-6">
        <TrainClient initialClasses={classes} initialSessions={sessions} userId={user.id} />
      </div>

      <div className="mt-12 pb-8 text-center">
        <a href="https://qyroxis.com" target="_blank" rel="noopener noreferrer" className="text-[11px] font-bold uppercase tracking-[0.14em] text-foreground/50">
          App made by <span className="text-brand underline">Qyroxis</span>
        </a>
      </div>
    </div>
  );
}
