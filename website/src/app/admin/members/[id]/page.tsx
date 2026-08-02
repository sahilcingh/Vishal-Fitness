import type { Metadata } from "next";
import Image from "next/image";
import { notFound } from "next/navigation";
import { User } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { formatINR } from "@/lib/format";
import { initials } from "@/lib/utils";
import { MemberDetailTables } from "@/components/admin/member-ledger";
import { BackButton } from "@/components/admin/back-button";
import { buildLedgerRows } from "@/lib/member-ledger-rows";

export const dynamic = "force-dynamic";

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params;
  return { title: `Member Ledger - Vishal Fitness Admin`, description: id };
}

function membershipNo(userId: string) {
  return `MBR-${userId.replace(/-/g, "").slice(0, 6).toUpperCase()}`;
}

type ProfileRow = {
  id: string;
  full_name: string | null;
  phone: string | null;
  photo_url: string | null;
  created_at: string;
};

type SubRow = {
  id: string;
  pass_id: string | null;
  start_date: string;
  end_date: string;
  status: string;
  discount_amount: number | null;
  created_at: string;
  gym_passes: { name: string | null; price: number | null; duration_days: number | null } | null;
};

type PaymentRow = {
  id: string;
  amount: number;
  payment_method: string | null;
  payment_date: string;
  notes: string | null;
  subscription_id: string | null;
};

export default async function MemberLedgerPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, full_name, phone, photo_url, created_at")
    .eq("id", id)
    .maybeSingle<ProfileRow>();
  if (!profile) notFound();

  const [subsRes, paymentsRes, checkInsCountRes] = await Promise.all([
    supabase
      .from("subscriptions")
      .select("id, pass_id, start_date, end_date, status, discount_amount, created_at, gym_passes:pass_id ( name, price, duration_days )")
      .eq("user_id", id)
      .order("created_at", { ascending: true })
      .returns<SubRow[]>(),
    supabase
      .from("payments")
      .select("id, amount, payment_method, payment_date, notes, subscription_id")
      .eq("user_id", id)
      .order("payment_date", { ascending: true })
      .returns<PaymentRow[]>(),
    supabase.from("check_ins").select("id", { count: "exact", head: true }).eq("user_id", id),
  ]);

  const subscriptions = subsRes.data ?? [];
  const payments = paymentsRes.data ?? [];
  const totalVisits = checkInsCountRes.count ?? 0;

  const ledgerRows = buildLedgerRows(subscriptions, payments);
  const totalPaid = payments.reduce((sum, p) => sum + (p.amount ?? 0), 0);
  const latestSub = [...subscriptions].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())[0];
  const currentStatus = latestSub ? latestSub.status.charAt(0).toUpperCase() + latestSub.status.slice(1) : "No subscription";

  const name = profile.full_name ?? "Member";

  return (
    <div>
      <div className="mb-6 flex items-center gap-3">
        <BackButton fallbackHref="/admin/members" />
        <span className="grid size-12 shrink-0 place-items-center overflow-hidden rounded-full border border-border bg-brand/12 text-[15px] font-bold text-brand">
          {profile.photo_url ? (
            <Image src={profile.photo_url} alt="" width={48} height={48} className="size-full object-cover" />
          ) : (
            initials(name)
          )}
        </span>
        <div className="min-w-0">
          <h1 className="truncate font-display text-[22px] font-bold leading-tight">{name}</h1>
          <div className="flex flex-wrap items-center gap-1.5 text-[12px] text-muted-foreground">
            <span className="rounded bg-brand/8 px-1.5 py-0.5 text-[10px] font-bold text-brand">{membershipNo(id)}</span>
            {profile.phone && <span>{profile.phone}</span>}
          </div>
        </div>
      </div>

      <div className="mb-5 grid grid-cols-2 gap-3.5 sm:grid-cols-4">
        <StatTile label="Member Since" value={new Date(profile.created_at).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" })} />
        <StatTile label="Total Paid" value={formatINR(totalPaid)} valueClass="text-brand" />
        <StatTile label="Visits" value={String(totalVisits)} />
        <StatTile label="Status" value={currentStatus} />
      </div>

      {ledgerRows.length === 0 ? (
        <div className="flex flex-col items-center gap-3 rounded-[20px] border border-border bg-card px-6 py-16 text-center">
          <User className="size-9 text-muted-foreground" />
          <p className="text-[13px] text-muted-foreground">No activity recorded for this member yet.</p>
        </div>
      ) : (
        <MemberDetailTables rows={ledgerRows} openingDate={profile.created_at} />
      )}
    </div>
  );
}

function StatTile({ label, value, valueClass }: { label: string; value: string; valueClass?: string }) {
  return (
    <div className="rounded-[20px] border border-border bg-card p-4">
      <div className="text-[10px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">{label}</div>
      <div className={`num mt-2 font-display text-[18px] font-bold ${valueClass ?? ""}`}>{value}</div>
    </div>
  );
}
