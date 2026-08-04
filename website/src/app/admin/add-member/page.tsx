import type { Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { AddMemberForm } from "@/components/admin/add-member-form";
import type { PickerMember } from "@/components/admin/members-picker-panel";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Add Member - Vishal Fitness Admin",
};

export default async function AddMemberPage({
  searchParams,
}: {
  searchParams: Promise<{ phone?: string }>;
}) {
  const { phone: initialPhone } = await searchParams;
  const supabase = await createClient();

  const [{ data: passes }, { data: allMembers }] = await Promise.all([
    supabase.from("gym_passes").select("id, name, price, duration_days").eq("is_active", true).order("duration_days", { ascending: true }),
    supabase
      .from("profiles")
      .select("id, full_name, phone, subscriptions(end_date, status, pass:gym_passes(name))")
      .neq("role", "admin")
      .is("archived_at", null)
      .order("full_name", { ascending: true })
      .order("created_at", { ascending: false, foreignTable: "subscriptions" })
      .limit(1, { foreignTable: "subscriptions" })
      .returns<PickerMember[]>(),
  ]);

  return (
    <div>
      <div className="mb-6 flex items-center gap-3">
        <Link href="/admin" className="grid size-9 place-items-center rounded-xl border border-border bg-card" aria-label="Back">
          <ArrowLeft className="size-4" />
        </Link>
        <h1 className="font-display text-[26px] font-bold leading-none">Add Member</h1>
      </div>

      <AddMemberForm passes={passes ?? []} initialPhone={initialPhone} members={allMembers ?? []} />
    </div>
  );
}
