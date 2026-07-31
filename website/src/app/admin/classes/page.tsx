import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { ClassesManager } from "@/components/admin/classes-manager";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Classes - Vishal Fitness Admin",
};

// Mirrors the try/catch around supabase.from('classes').select() in
// admin_classes_screen.dart's _fetchClasses() - one failing query never
// takes down the whole page. Errors are still logged (not just swallowed)
// so a genuine query failure is distinguishable from real zero rows in
// server logs, even though the UI shows the same empty state either way.
async function safeSelect<T>(promise: PromiseLike<{ data: T[] | null; error: unknown }>) {
  try {
    const { data, error } = await promise;
    if (error) {
      console.error("classes/page: query failed:", error);
      return [] as T[];
    }
    return data ?? ([] as T[]);
  } catch (err) {
    console.error("classes/page: query threw:", err);
    return [] as T[];
  }
}

export type ClassRow = {
  id: string;
  title: string;
  trainer_name: string;
  category: string;
  duration_minutes: number;
  total_capacity: number;
  intensity_level: string;
  start_time: string;
};

export default async function ClassesPage() {
  const supabase = await createClient();

  const classes = await safeSelect<ClassRow>(
    supabase
      .from("classes")
      .select("id, title, trainer_name, category, duration_minutes, total_capacity, intensity_level, start_time")
      .order("start_time", { ascending: true }),
  );

  return (
    <div>
      <div className="mb-6 flex items-center gap-3">
        <Link href="/admin" className="grid size-9 place-items-center rounded-xl border border-border bg-card" aria-label="Back">
          <ArrowLeft className="size-4" />
        </Link>
        <h1 className="font-display text-[26px] font-bold leading-none">Classes</h1>
      </div>

      <ClassesManager classes={classes} />
    </div>
  );
}
