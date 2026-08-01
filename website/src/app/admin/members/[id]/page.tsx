import type { Metadata } from "next";
import Image from "next/image";
import { notFound } from "next/navigation";
import { User } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { formatINR } from "@/lib/format";
import { initials } from "@/lib/utils";
import { MemberLedger, type LedgerEntry } from "@/components/admin/member-ledger";
import { BackButton } from "@/components/admin/back-button";

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
  subscription_id: string | null;
};

type CheckInRow = { id: string; checked_in_at: string };

type EventRow = { id: string; event_type: string; description: string; created_at: string };

export default async function MemberLedgerPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const supabase = await createClient();

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, full_name, phone, photo_url, created_at")
    .eq("id", id)
    .maybeSingle<ProfileRow>();
  if (!profile) notFound();

  const [subsRes, paymentsRes, checkInsRes, eventsRes] = await Promise.all([
    supabase
      .from("subscriptions")
      .select("id, pass_id, start_date, end_date, status, discount_amount, created_at, gym_passes:pass_id ( name, price, duration_days )")
      .eq("user_id", id)
      .order("created_at", { ascending: true })
      .returns<SubRow[]>(),
    supabase
      .from("payments")
      .select("id, amount, payment_method, payment_date, subscription_id")
      .eq("user_id", id)
      .order("payment_date", { ascending: true })
      .returns<PaymentRow[]>(),
    supabase.from("check_ins").select("id, checked_in_at").eq("user_id", id).order("checked_in_at", { ascending: true }).returns<CheckInRow[]>(),
    supabase
      .from("member_events")
      .select("id, event_type, description, created_at")
      .eq("user_id", id)
      .order("created_at", { ascending: true })
      .returns<EventRow[]>(),
  ]);

  const subscriptions = subsRes.data ?? [];
  const payments = paymentsRes.data ?? [];
  const checkIns = checkInsRes.data ?? [];
  const events = eventsRes.data ?? [];

  const passNameBySub = new Map(subscriptions.map((s) => [s.id, s.gym_passes?.name ?? "Pass"]));

  const joinedEntry: LedgerEntry = {
    id: "joined",
    date: profile.created_at,
    category: "joined",
    title: "Joined Vishal Fitness",
  };

  const entries: LedgerEntry[] = [
    joinedEntry,
    ...subscriptions.map((s, i): LedgerEntry => ({
      id: `sub-${s.id}`,
      date: s.created_at,
      category: "membership",
      title: `${i === 0 ? "Subscribed to" : "Renewed to"} ${s.gym_passes?.name ?? "a pass"}`,
      subtitle: `${s.gym_passes?.duration_days ?? "-"} days · ${formatINR(s.gym_passes?.price ?? 0)}${
        s.discount_amount ? ` · ${formatINR(s.discount_amount)} discount` : ""
      }`,
    })),
    ...payments.map((p): LedgerEntry => ({
      id: `pay-${p.id}`,
      date: p.payment_date,
      category: "payment",
      title: `Paid ${formatINR(p.amount)}`,
      subtitle: [p.payment_method?.toUpperCase(), p.subscription_id ? passNameBySub.get(p.subscription_id) : null]
        .filter(Boolean)
        .join(" · "),
    })),
    ...checkIns.map((c): LedgerEntry => ({
      id: `visit-${c.id}`,
      date: c.checked_in_at,
      category: "visit",
      title: "Checked in",
    })),
    ...events.map((e): LedgerEntry => ({
      id: `event-${e.id}`,
      date: e.created_at,
      category: "change",
      title: e.description,
    })),
  ].sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

  const totalPaid = payments.reduce((sum, p) => sum + (p.amount ?? 0), 0);
  const totalVisits = checkIns.length;
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

      {subscriptions.length === 0 && payments.length === 0 && checkIns.length === 0 && events.length === 0 ? (
        <div className="flex flex-col items-center gap-3 rounded-[20px] border border-border bg-card px-6 py-16 text-center">
          <User className="size-9 text-muted-foreground" />
          <p className="text-[13px] text-muted-foreground">No activity recorded for this member yet.</p>
        </div>
      ) : (
        <MemberLedger entries={entries} />
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
