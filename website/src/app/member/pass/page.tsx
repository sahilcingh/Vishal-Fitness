import type { Metadata } from "next";
import { Sparkles, History } from "lucide-react";
import { createClient } from "@/lib/supabase/server";
import { nowInIST, istDayKey } from "@/lib/ist-time";
import { CheckInButton } from "@/components/member/check-in-button";

export const metadata: Metadata = { title: "My Pass" };
export const dynamic = "force-dynamic";

async function safeSelect<T>(promise: PromiseLike<{ data: T[] | null; error: unknown }>) {
  try {
    const { data, error } = await promise;
    if (error) {
      console.error("member/pass/page: query failed:", error);
      return [] as T[];
    }
    return data ?? ([] as T[]);
  } catch (err) {
    console.error("member/pass/page: query threw:", err);
    return [] as T[];
  }
}

type SubscriptionRow = {
  status: string | null;
  end_date: string | null;
  gym_passes: { name: string | null } | null;
};

type CheckInRow = { id: string; checked_in_at: string };

// Same technique as admin/expiry/page.tsx's toYMD/parseYMD/daysLeft: both
// sides of the subtraction are built the same way (local-getter Date at
// midnight), so any server-timezone offset cancels out — the day count comes
// out right on a UTC-deployed Vercel host without needing a real epoch.
// nowInIST() supplies the *correct calendar day* input (see src/lib/ist-time.ts).
function toYMD(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
function parseYMD(s: string) {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}
function isValidYMD(s: string) {
  return /^\d{4}-\d{2}-\d{2}$/.test(s);
}
// Supabase returns `date` columns as "YYYY-MM-DD" but would return a
// timestamp column as a full ISO string — normalize either shape to a bare
// date so a format change is never silently misread.
function normalizeYMD(s: string | null | undefined) {
  if (!s) return "";
  const sliced = s.slice(0, 10);
  return isValidYMD(sliced) ? sliced : "";
}
function daysLeftBetween(endYMD: string, todayYMD: string) {
  return Math.round((parseYMD(endYMD).getTime() - parseYMD(todayYMD).getTime()) / 86_400_000);
}
function prettyExpiry(ymd: string) {
  return parseYMD(ymd).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "2-digit" });
}

function formatVisitDate(iso: string) {
  return new Intl.DateTimeFormat("en-US", { timeZone: "Asia/Kolkata", weekday: "short", day: "numeric", month: "short" }).format(
    new Date(iso),
  );
}
function formatVisitTime(iso: string) {
  return new Intl.DateTimeFormat("en-GB", { timeZone: "Asia/Kolkata", hour: "2-digit", minute: "2-digit", hour12: false }).format(
    new Date(iso),
  );
}

const VISIT_ACCENTS = ["bg-brand", "bg-energy", "bg-pulse", "bg-aqua", "bg-sun"] as const;

// Tiny deterministic PRNG (no crypto needed — purely decorative) so the same
// member always sees the same bar pattern instead of it reshuffling on every
// render/refresh.
function hashSeed(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return h >>> 0;
}
function barWidths(seed: string, count: number) {
  let h = hashSeed(seed) || 1;
  const widths: number[] = [];
  for (let i = 0; i < count; i++) {
    h = (h * 1103515245 + 12345) & 0x7fffffff;
    widths.push(1 + (h % 3));
  }
  return widths;
}

export default async function PassPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const [profileRes, subscriptionRes, checkIns] = await Promise.all([
    supabase.from("profiles").select("full_name").eq("id", user.id).maybeSingle(),
    supabase
      .from("subscriptions")
      .select("status, end_date, gym_passes(name)")
      .eq("user_id", user.id)
      .order("end_date", { ascending: false })
      .limit(1)
      .maybeSingle()
      .returns<SubscriptionRow>(),
    safeSelect<CheckInRow>(
      supabase.from("check_ins").select("id, checked_in_at").eq("user_id", user.id).order("checked_in_at", { ascending: false }).limit(8),
    ),
  ]);

  const fullName = profileRes.data?.full_name?.trim();
  const displayName = fullName
    ? fullName.split(" ")[0]
    : (() => {
        const prefix = (user.email ?? "member").split("@")[0];
        return prefix.charAt(0).toUpperCase() + prefix.slice(1);
      })();

  const subscription = subscriptionRes.data;
  const passName = subscription?.gym_passes?.name ?? "Standard";
  const statusRaw = (subscription?.status ?? "inactive").toUpperCase();
  const isActive = statusRaw === "ACTIVE";
  const memberId = user.id.slice(0, 8).toUpperCase();
  const memberCode = `${memberId.slice(0, 4)}-${memberId.slice(4)}`;

  const endYMD = normalizeYMD(subscription?.end_date);
  const formattedExpiry = endYMD ? prettyExpiry(endYMD) : "—";

  const todayYMD = toYMD(nowInIST());
  const daysLeft = endYMD ? daysLeftBetween(endYMD, todayYMD) : null;

  const bars = barWidths(memberId, 44);

  const todayIstKey = istDayKey(new Date().toISOString());
  const alreadyCheckedInToday = checkIns.some((c) => istDayKey(c.checked_in_at) === todayIstKey);

  return (
    <div className="mx-auto max-w-[900px]">
      <div className="flex items-center gap-2">
        <Sparkles className="size-4 text-sun" />
        <span className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">Membership</span>
      </div>

      <h1 className="mt-2 font-display text-[32px] font-bold leading-[1.1]">
        Your pass<span className="text-sun">.</span>
      </h1>

      <div className="mt-8 grid grid-cols-1 gap-6 lg:grid-cols-[1fr_340px] lg:items-start">
        <div>
          {/* Digital pass card — intentionally a fixed dark card in both light
              and dark site themes, matching the physical-pass aesthetic in the
              Flutter app and the design mockup (both hardcode the same
              near-black). */}
          <div className="relative overflow-hidden rounded-[24px] bg-[#131316] p-6 text-white shadow-lg">
            <div className="pointer-events-none absolute -right-12 -top-16 size-44 rounded-full bg-[#9182F9] opacity-60 blur-3xl" />
            <div className="pointer-events-none absolute -bottom-14 -left-10 size-36 rounded-full bg-[#26B6E8] opacity-60 blur-3xl" />
            <div className="pointer-events-none absolute left-28 top-24 size-28 rounded-full bg-[#FFB03A] opacity-50 blur-3xl" />

            <div className="relative flex items-center justify-between gap-2">
              <div className="flex min-w-0 items-center gap-3">
                <span className="grid size-8 shrink-0 place-items-center rounded-lg bg-gradient-to-br from-sun to-pulse">
                  <History className="size-[18px] text-[#131316]" />
                </span>
                <span className="truncate font-display text-[18px] font-bold tracking-tight bg-gradient-to-br from-sun to-pulse bg-clip-text text-transparent">
                  Vishal Fitness
                </span>
              </div>
              <span
                className={`flex shrink-0 items-center gap-1.5 rounded-full px-2.5 py-1 text-[10px] font-bold tracking-wide ${
                  isActive ? "bg-brand/20 text-brand" : "bg-energy/20 text-energy"
                }`}
              >
                <span className={`size-1.5 rounded-full ${isActive ? "bg-brand" : "bg-energy"}`} />
                {statusRaw}
              </span>
            </div>

            <div className="relative mt-6">
              <div className="text-[10px] font-bold uppercase tracking-[0.15em] text-white/45">Member</div>
              <div className="mt-1 font-display text-[24px] font-semibold">{displayName}</div>
            </div>

            <div className="relative mt-6 flex justify-between gap-2">
              <PassDetail label="Plan" value={passName} />
              <PassDetail label="ID" value={memberId} mono />
              <PassDetail label="Expires" value={formattedExpiry} mono />
            </div>

            <div className="relative mt-6 flex items-center">
              <div className="h-6 w-3 shrink-0 rounded-r-full bg-background" />
              <div className="h-px flex-1 border-t border-dashed border-white/25" />
              <div className="h-6 w-3 shrink-0 rounded-l-full bg-background" />
            </div>

            <div className="relative mt-6 flex flex-col items-center rounded-2xl bg-white p-4">
              <div className="flex h-12 items-end gap-[2px]">
                {bars.map((w, i) => (
                  <div key={i} className="bg-[#131316]" style={{ width: `${w}px`, height: i % 7 === 0 ? "100%" : "70%" }} />
                ))}
              </div>
              <div className="num mt-3 text-[18px] font-bold tracking-[0.2em] text-[#131316]">{memberCode}</div>
              <div className="mt-1 text-center text-[10.5px] font-medium text-black/45">Show this code at the front desk to check in</div>
            </div>
          </div>

          {daysLeft !== null && (
            <div className="mt-4 flex items-center gap-2 px-1">
              <span className={`size-1.5 rounded-full ${daysLeft < 0 ? "bg-energy" : daysLeft <= 7 ? "bg-sun" : "bg-brand"}`} />
              <span className="text-[12.5px] font-medium text-muted-foreground">
                {daysLeft < 0
                  ? `Your pass expired ${Math.abs(daysLeft)} day${Math.abs(daysLeft) === 1 ? "" : "s"} ago — renew at the front desk.`
                  : daysLeft === 0
                    ? "Your pass expires today."
                    : `${daysLeft} day${daysLeft === 1 ? "" : "s"} left on your plan.`}
              </span>
            </div>
          )}

          <div className="mt-6">
            <CheckInButton alreadyCheckedInToday={alreadyCheckedInToday} />
          </div>
        </div>

        <div>
          <div className="text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">Recent Visits</div>
          <div className="mt-4">
            {checkIns.length === 0 ? (
              <div className="rounded-[20px] border border-border/50 bg-card px-5 py-6 text-center text-[13.5px] text-muted-foreground">
                No visits yet. Check in to start your streak.
              </div>
            ) : (
              <div className="flex flex-col rounded-[20px] border border-border/50 bg-card px-5 py-1">
                {checkIns.map((c, i) => (
                  <div key={c.id} className={`flex items-center justify-between py-3 ${i !== 0 ? "border-t border-border/40" : ""}`}>
                    <div className="flex items-center gap-2.5">
                      <span className={`size-2 shrink-0 rounded-full ${VISIT_ACCENTS[i % VISIT_ACCENTS.length]}`} />
                      <span className="text-[13.5px] font-medium">{formatVisitDate(c.checked_in_at)}</span>
                    </div>
                    <span className="num text-[12px] font-semibold text-muted-foreground">{formatVisitTime(c.checked_in_at)}</span>
                  </div>
                ))}
              </div>
            )}
          </div>
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

function PassDetail({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="min-w-0 flex-1">
      <div className="text-[9.5px] font-bold uppercase tracking-[0.12em] text-white/45">{label}</div>
      <div className={`mt-1 truncate text-[13.5px] font-semibold ${mono ? "num" : ""}`}>{value}</div>
    </div>
  );
}
