import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { AddMemberForm } from "@/components/admin/add-member-form";
import { RecentAdditions } from "@/components/admin/recent-additions";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Add Member - Vishal Fitness Admin",
};

type RecentMemberRow = {
  id: string;
  full_name: string | null;
  phone: string | null;
  created_at: string;
  subscriptions: {
    id: string;
    pass_id: string | null;
    status: string;
    start_date: string;
    pass: { name: string | null } | null;
  }[];
};

export default async function AddMemberPage() {
  const supabase = await createClient();

  const [{ data: passes }, { data: recentMembers }] = await Promise.all([
    supabase.from("gym_passes").select("id, name, price, duration_days").eq("is_active", true).order("duration_days", { ascending: true }),
    supabase
      .from("profiles")
      .select("id, full_name, phone, created_at, subscriptions(id, pass_id, status, start_date, pass:gym_passes(name))")
      .neq("role", "admin")
      .order("created_at", { ascending: false })
      .order("created_at", { ascending: false, foreignTable: "subscriptions" })
      .limit(1, { foreignTable: "subscriptions" })
      .limit(8)
      .returns<RecentMemberRow[]>(),
  ]);

  return (
    <div>
      <div className="mb-6 flex items-center gap-3">
        <Link href="/admin" className="grid size-9 place-items-center rounded-xl border border-border bg-card" aria-label="Back">
          <ArrowLeft className="size-4" />
        </Link>
        <h1 className="font-display text-[26px] font-bold leading-none">Add Member</h1>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-[1fr_360px]">
        <AddMemberForm passes={passes ?? []} />
        <RecentAdditions members={recentMembers ?? []} passes={passes ?? []} />
      </div>
    </div>
  );
}
