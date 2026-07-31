import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { NewAnnouncementButton } from "@/components/admin/new-announcement-button";
import { AnnouncementsList, type AnnouncementRow } from "@/components/admin/announcements-list";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Announcements - Vishal Fitness Admin",
};

// Mirrors safeSelect() on the other admin pages (classes/passes/expiry/reports)
// - one failing query never takes down the whole page, and the real error is
// still logged so a genuine query failure is distinguishable from real zero
// rows in server logs.
async function safeSelect<T>(promise: PromiseLike<{ data: T[] | null; error: unknown }>) {
  try {
    const { data, error } = await promise;
    if (error) {
      console.error("announcements/page: query failed:", error);
      return [] as T[];
    }
    return data ?? ([] as T[]);
  } catch (err) {
    console.error("announcements/page: query threw:", err);
    return [] as T[];
  }
}

export default async function AnnouncementsPage() {
  const supabase = await createClient();

  const [
    {
      data: { user },
    },
    announcements,
  ] = await Promise.all([
    supabase.auth.getUser(),
    safeSelect<AnnouncementRow>(
      supabase
        .from("announcements")
        .select("id, title, message, is_active, created_at")
        .order("created_at", { ascending: false })
        .returns<AnnouncementRow[]>(),
    ),
  ]);

  return (
    <div>
      <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <Link
            href="/admin"
            className="grid size-9 place-items-center rounded-xl border border-border bg-card"
            aria-label="Back"
          >
            <ArrowLeft className="size-4" />
          </Link>
          <h1 className="font-display text-[26px] font-bold leading-none">Announcements</h1>
        </div>
        <NewAnnouncementButton createdBy={user?.id ?? null} />
      </div>

      <AnnouncementsList announcements={announcements} />
    </div>
  );
}
