import type { Metadata } from "next";
import { createClient } from "@/lib/supabase/server";
import { MembersDirectory, type MemberRow } from "@/components/admin/members-directory";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Ledger - Vishal Fitness Admin",
};

export default async function MembersLedgerPage() {
  const supabase = await createClient();
  const { data } = await supabase
    .from("profiles")
    .select("id, full_name, phone, photo_url, created_at")
    .neq("role", "admin")
    .order("full_name", { ascending: true })
    .returns<MemberRow[]>();

  return (
    <div>
      <div className="mb-6">
        <h1 className="font-display text-[26px] font-bold leading-none">Ledger</h1>
        <p className="mt-1.5 text-[13px] text-muted-foreground">
          Search any member to see their full history - membership, payments, visits, and changes.
        </p>
      </div>
      <MembersDirectory members={data ?? []} />
    </div>
  );
}
