import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { PassesManager, type GymPass } from "@/components/admin/passes-manager";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Passes — Vishal Fitness Admin",
};

// Mirrors the try/catch around supabase.from('gym_passes').select() in
// admin_passes_screen.dart's _fetchPasses() — one failing query never takes
// down the whole page (see the identical safeSelect in admin/classes/page.tsx).
// Errors are still logged (not just swallowed) so a genuine query failure is
// distinguishable from real zero rows in server logs.
async function safeSelect<T>(promise: PromiseLike<{ data: T[] | null; error: unknown }>) {
  try {
    const { data, error } = await promise;
    if (error) {
      console.error("passes/page: query failed:", error);
      return [] as T[];
    }
    return data ?? ([] as T[]);
  } catch (err) {
    console.error("passes/page: query threw:", err);
    return [] as T[];
  }
}

export default async function PassesPage() {
  const supabase = await createClient();

  const passes = await safeSelect<GymPass>(
    supabase
      .from("gym_passes")
      .select("id, name, price, duration_days, features, is_active")
      .order("duration_days", { ascending: true }),
  );

  return (
    <div>
      <div className="mb-6 flex items-center gap-3">
        <Link href="/admin" className="grid size-9 place-items-center rounded-xl border border-border bg-card" aria-label="Back">
          <ArrowLeft className="size-4" />
        </Link>
        <h1 className="font-display text-[26px] font-bold leading-none">Passes</h1>
      </div>

      <PassesManager passes={passes} />
    </div>
  );
}
