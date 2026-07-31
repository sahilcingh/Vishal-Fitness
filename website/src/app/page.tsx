import type { Metadata } from "next";
import Link from "next/link";
import Image from "next/image";
import {
  Sparkles,
  ArrowRight,
  CalendarCheck,
  QrCode,
  TrendingUp,
  Users,
  Clock,
  Dumbbell,
  MapPin,
  Star,
  Camera,
  UserPlus,
} from "lucide-react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { formatINR } from "@/lib/format";
import { nowInIST } from "@/lib/ist-time";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Vishal Fitness — Gym Membership & Classes in Unnao",
  description:
    "Join Vishal Fitness in Unnao for expert-led training, 100+ classes a week, and instant digital gym passes. Open Mon–Sat, 6:00 AM – 10:00 PM. Rated 4.9 stars by 200+ members.",
  openGraph: {
    title: "Vishal Fitness — Gym Membership & Classes in Unnao",
    description:
      "Expert trainers, 100+ classes a week, and instant digital gym passes. Open Mon–Sat, 6:00 AM – 10:00 PM in Unnao.",
    type: "website",
  },
};

async function safeSelect<T>(promise: PromiseLike<{ data: T[] | null; error: unknown }>) {
  try {
    const { data, error } = await promise;
    if (error) {
      console.error("safeSelect: query returned an error, falling back to []", error);
      return [] as T[];
    }
    return data ?? ([] as T[]);
  } catch (err) {
    console.error("safeSelect: query threw, falling back to []", err);
    return [] as T[];
  }
}

const PASS_GRADIENTS = [
  "from-brand to-aqua",
  "from-energy to-pulse",
  "from-aqua to-pulse",
  "from-sun via-energy to-pulse",
];

const FEATURE_BADGES = [
  { icon: CalendarCheck, label: "Book Classes" },
  { icon: QrCode, label: "Digital Pass" },
  { icon: TrendingUp, label: "Track Progress" },
  { icon: Users, label: "Community" },
] as const;

type Pass = {
  id: string;
  name: string;
  price: number;
  duration_days: number;
  features: string[] | null;
};

export default async function WelcomePage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (user) {
    const { data: profile } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();
    redirect(profile?.role === "admin" ? "/admin" : "/member/today");
  }

  // twoHoursAgo needs a real instant (compared against a real timestamptz
  // column), so it's derived from the true current time, not nowInIST()'s
  // calendar-correct-but-not-a-real-instant Date — see src/lib/ist-time.ts.
  const nowReal = new Date();
  const twoHoursAgo = new Date(nowReal.getTime() - 2 * 60 * 60 * 1000);

  const [checkIns, passes] = await Promise.all([
    safeSelect<{ id: string }>(
      supabase.from("check_ins").select("id").gte("checked_in_at", twoHoursAgo.toISOString()),
    ),
    safeSelect<Pass>(
      supabase
        .from("gym_passes")
        .select("id, name, price, duration_days, features")
        .eq("is_active", true)
        .order("duration_days", { ascending: true }),
    ),
  ]);

  const liveCount = checkIns.length;

  // Gym open hours: Mon–Sat 6 AM – 10 PM IST — must reflect the gym's actual
  // local time regardless of the server's own OS timezone.
  const nowIST = nowInIST();
  const weekday = nowIST.getDay(); // 0 = Sun
  const isGymOpen = weekday !== 0 && nowIST.getHours() >= 6 && nowIST.getHours() < 22;

  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "Gym",
    name: "Vishal Fitness",
    image: "/logo.jpg",
    address: {
      "@type": "PostalAddress",
      addressLocality: "Unnao",
    },
    openingHoursSpecification: {
      "@type": "OpeningHoursSpecification",
      dayOfWeek: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
      opens: "06:00",
      closes: "22:00",
    },
    aggregateRating: {
      "@type": "AggregateRating",
      ratingValue: "4.9",
      reviewCount: "200",
    },
    sameAs: ["https://www.instagram.com/vishal.fitness.unnao"],
  };

  return (
    <div className="relative min-h-screen overflow-hidden bg-background">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <div className="pointer-events-none absolute -left-32 -top-32 size-[420px] rounded-full bg-[radial-gradient(circle,rgba(31,197,107,0.12),transparent_70%)]" />
      <div className="pointer-events-none absolute -right-24 top-1/3 size-[360px] rounded-full bg-[radial-gradient(circle,rgba(255,122,41,0.10),transparent_70%)]" />
      <div className="pointer-events-none absolute -bottom-32 right-1/4 size-[300px] rounded-full bg-[radial-gradient(circle,rgba(177,76,240,0.10),transparent_70%)]" />

      <div className="relative mx-auto max-w-[1200px] px-6 py-6 lg:px-10 lg:py-8">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="size-11 shrink-0 overflow-hidden rounded-xl border border-border bg-white">
              <Image src="/logo.jpg" alt="Vishal Fitness" width={44} height={44} className="size-full object-cover" />
            </div>
            <span className="font-display text-[22px] font-bold tracking-[0.04em]">VISHAL FITNESS</span>
          </div>
          <Link
            href="/login"
            className="rounded-full border border-foreground/30 px-5 py-2 text-[13.5px] font-semibold hover:border-foreground/60"
          >
            Sign in
          </Link>
        </div>

        <div className="mt-10 grid grid-cols-1 gap-10 md:grid-cols-2 md:gap-8 lg:mt-16 lg:grid-cols-[1.2fr_1fr] lg:gap-14">
          <div>
            <div className="flex items-center gap-2">
              <Sparkles className="size-[15px] text-pulse" />
              <span className="text-[11px] font-bold uppercase tracking-[0.14em] text-muted-foreground">
                Your fitness our commitment 💪
              </span>
            </div>

            <h1 className="font-display mt-5 text-[42px] font-bold leading-[1.05] sm:text-[52px] lg:text-[56px]">
              One pass.
              <br />
              Every <span className="text-pulse">workout.</span>
              <br />
              Zero friction.
            </h1>

            <p className="mt-5 max-w-md text-[15px] font-medium leading-relaxed text-foreground/80">
              A vibrant operating system for the modern gym — book classes, track lifts, log progress, and walk in
              with a single QR.
            </p>

            <Link
              href="/login"
              className="mt-7 inline-flex items-center gap-2 rounded-full bg-gradient-to-br from-brand to-aqua px-6 py-3.5 text-[15px] font-semibold text-on-brand"
            >
              Member Login
              <ArrowRight className="size-[18px]" />
            </Link>

            <div className="mt-7 flex items-center gap-2">
              <span className="size-2 rounded-full bg-brand" />
              <span className="text-[13px] font-medium">
                {liveCount > 0 ? (
                  <>
                    <span className="num font-bold">{liveCount}</span> athletes checked in today
                  </>
                ) : (
                  "Be the first to check in today!"
                )}
              </span>
            </div>

            <div className="mt-7 flex flex-wrap gap-2.5">
              {FEATURE_BADGES.map((b) => (
                <span
                  key={b.label}
                  className="flex items-center gap-1.5 rounded-full border border-border bg-card/80 px-3.5 py-2 text-[12px] font-semibold"
                >
                  <b.icon className="size-3.5 text-brand" />
                  {b.label}
                </span>
              ))}
            </div>
          </div>

          <div className="flex flex-col gap-3">
            <a
              href="https://www.instagram.com/vishal.fitness.unnao"
              target="_blank"
              rel="noopener noreferrer"
              className="relative flex items-center gap-4 overflow-hidden rounded-[20px] bg-[linear-gradient(135deg,#833AB4,#FD1D1D,#F56040)] p-4 text-white shadow-sm"
            >
              <span className="pointer-events-none absolute inset-0 bg-black/20" />
              <span className="relative grid size-11 shrink-0 place-items-center rounded-full bg-white/20">
                <Camera className="size-5" />
              </span>
              <span className="relative min-w-0 flex-1">
                <span className="block text-[14px] font-bold text-white">Follow @vishal.fitness.unnao</span>
                <span className="block text-[12px] text-white">Watch our latest reels & workout tips! 🚀</span>
              </span>
              <span className="relative shrink-0 rounded-full bg-white px-3.5 py-2 text-[12px] font-bold text-[#E1306C]">
                Follow
              </span>
            </a>

            <div className="grid grid-cols-3 gap-2.5">
              <StatCard value="200+" label="ATHLETES" color="text-brand" />
              <StatCard value="100" label="CLASSES/WK" color="text-energy" />
              <StatCard value="4.9" label="RATING" color="text-aqua" />
            </div>

            <div className="flex items-center gap-3.5 rounded-[20px] border border-border bg-card p-4">
              <span className="grid size-9 shrink-0 place-items-center rounded-full bg-brand/12">
                <Clock className="size-[18px] text-brand" />
              </span>
              <span className="min-w-0 flex-1">
                <span className="block text-[10px] font-bold uppercase tracking-[0.1em] text-brand">Gym Hours</span>
                <span className="block text-[13.5px] font-semibold">Mon – Sat · 6:00 AM – 10:00 PM</span>
              </span>
              <span
                className={`shrink-0 rounded-full px-3 py-1 text-[9.5px] font-extrabold uppercase tracking-wide ${
                  isGymOpen ? "bg-brand/12 text-brand" : "bg-energy/12 text-energy"
                }`}
              >
                {isGymOpen ? "Open" : "Closed"}
              </span>
            </div>
          </div>
        </div>

        <div className="mt-12 grid grid-cols-1 gap-3.5 sm:grid-cols-3">
          <HighlightCard
            icon={Dumbbell}
            color="text-brand"
            bg="bg-brand/10"
            title="Expert Trainers"
            sub="Certified professionals guiding every step of your fitness journey."
          />
          <a
            href="https://maps.google.com/?q=Vishal+Fitness+Unnao"
            target="_blank"
            rel="noopener noreferrer"
            className="block"
          >
            <HighlightCard
              icon={MapPin}
              color="text-energy"
              bg="bg-energy/10"
              title="Prime Location"
              sub="Conveniently located in Unnao with easy access and ample parking."
              cta="Open Maps"
            />
          </a>
          <a
            href="https://www.instagram.com/vishal.fitness.unnao"
            target="_blank"
            rel="noopener noreferrer"
            className="block"
          >
            <HighlightCard
              icon={Star}
              color="text-aqua"
              bg="bg-aqua/10"
              title="Top Rated"
              sub="4.9 stars from 200+ members — Unnao's most loved fitness centre."
              cta="Follow us"
            />
          </a>
        </div>

        {passes.length > 0 ? (
          <div className="mt-14">
            <div className="flex items-center gap-3">
              <span className="grid size-9 shrink-0 place-items-center rounded-xl bg-brand/10">
                <UserPlus className="size-[18px] text-brand" />
              </span>
              <div>
                <h2 className="text-[11px] font-extrabold uppercase tracking-[0.14em] text-brand">
                  Membership Plans
                </h2>
                <div className="text-[13px] text-muted-foreground">Pick the plan that fits your goals</div>
              </div>
            </div>

            <div className="mt-5 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
              {passes.map((p, i) => (
                <PassCard key={p.id} pass={p} index={i} isLast={i === passes.length - 1 && passes.length > 1} />
              ))}
            </div>

            <div className="mt-5 flex flex-col items-start gap-4 rounded-[20px] border border-brand/25 bg-card/85 p-5 sm:flex-row sm:items-center">
              <span className="grid size-11 shrink-0 place-items-center rounded-xl bg-gradient-to-br from-brand to-aqua">
                <UserPlus className="size-5 text-white" />
              </span>
              <div className="flex-1">
                <div className="text-[15px] font-bold">Ready to join?</div>
                <div className="text-[12.5px] text-muted-foreground">
                  Visit us at the gym or contact staff to get registered.
                </div>
              </div>
              <a
                href="https://www.instagram.com/vishal.fitness.unnao"
                target="_blank"
                rel="noopener noreferrer"
                className="shrink-0 rounded-full bg-gradient-to-br from-brand to-aqua px-5 py-2.5 text-[13px] font-bold text-white"
              >
                Contact
              </a>
            </div>
          </div>
        ) : (
          <div className="mt-14 rounded-[20px] border border-brand/25 bg-card/85 p-6 text-center">
            <h2 className="text-[15px] font-bold">Membership Plans</h2>
            <p className="mt-1.5 text-[12.5px] text-muted-foreground">
              Contact us for current membership pricing — visit us at the gym or reach out on Instagram.
            </p>
            <a
              href="https://www.instagram.com/vishal.fitness.unnao"
              target="_blank"
              rel="noopener noreferrer"
              className="mt-4 inline-flex rounded-full bg-gradient-to-br from-brand to-aqua px-5 py-2.5 text-[13px] font-bold text-white"
            >
              Contact
            </a>
          </div>
        )}

        <div className="mt-14 pb-8 text-center">
          <a
            href="https://qyroxis.com"
            target="_blank"
            rel="noopener noreferrer"
            className="text-[11px] font-bold uppercase tracking-[0.14em] text-foreground/70"
          >
            App made by <span className="text-brand underline">Qyroxis</span>
          </a>
        </div>
      </div>
    </div>
  );
}

function StatCard({ value, label, color }: { value: string; label: string; color: string }) {
  return (
    <div className="rounded-[20px] border border-border bg-card p-4 text-center">
      <div className={`font-display text-[22px] font-bold tracking-tight ${color}`}>{value}</div>
      <div className="mt-1 text-[9px] font-bold uppercase tracking-wide">{label}</div>
    </div>
  );
}

function HighlightCard({
  icon: Icon,
  color,
  bg,
  title,
  sub,
  cta,
}: {
  icon: React.ComponentType<{ className?: string }>;
  color: string;
  bg: string;
  title: string;
  sub: string;
  cta?: string;
}) {
  return (
    <div className="flex h-full items-start gap-3.5 rounded-[20px] border border-border bg-card/85 p-4">
      <span className={`grid size-9 shrink-0 place-items-center rounded-xl ${bg}`}>
        <Icon className={`size-[18px] ${color}`} />
      </span>
      <div className="min-w-0">
        <h3 className="text-[13.5px] font-bold">{title}</h3>
        <div className="mt-0.5 text-[11.5px] leading-snug text-muted-foreground">{sub}</div>
        {cta && (
          <div className={`mt-1.5 flex items-center gap-1 text-[11px] font-bold ${color}`}>
            {cta}
            <ArrowRight className="size-2.5" />
          </div>
        )}
      </div>
    </div>
  );
}

function PassCard({ pass, index, isLast }: { pass: Pass; index: number; isLast: boolean }) {
  const gradient = PASS_GRADIENTS[index % PASS_GRADIENTS.length];
  const perMonth = pass.duration_days > 0 ? Math.round(pass.price / (pass.duration_days / 30)) : pass.price;
  const features = pass.features ?? [];
  // The sun→energy→pulse gradient's "sun" stop is too light for white text to
  // clear WCAG AA contrast on its own — add a dark scrim behind the content.
  const needsScrim = gradient === PASS_GRADIENTS[3];

  return (
    <div className={`relative overflow-hidden rounded-[20px] bg-gradient-to-br p-5 text-white shadow-sm ${gradient}`}>
      {needsScrim && <div className="pointer-events-none absolute inset-0 bg-black/50" />}
      <div className="relative">
        <div className="flex items-start justify-between gap-2">
          <div>
            <div className="font-display text-[13px] font-extrabold uppercase tracking-wide">{pass.name}</div>
            <div className="mt-0.5 text-[11px] text-white/75">{pass.duration_days} days</div>
          </div>
          {isLast && (
            <span className="rounded-full bg-white/20 px-2.5 py-1 text-[8px] font-extrabold uppercase">
              Best Value
            </span>
          )}
        </div>

        <div className="num mt-4 font-display text-[28px] font-extrabold">{formatINR(pass.price)}</div>
        <div className="mt-1.5 inline-block rounded-md bg-black/20 px-2.5 py-1 text-[11px] font-bold">
          {formatINR(perMonth)} / mo
        </div>

        {features.length > 0 && (
          <>
            <div className="mt-4 h-px bg-white/20" />
            <ul className="mt-3 space-y-1.5">
              {features.slice(0, 3).map((f) => (
                <li key={f} className="flex items-center gap-2 text-[11.5px] text-white/90">
                  <span className="size-1 shrink-0 rounded-full bg-white/70" />
                  <span className="truncate">{f}</span>
                </li>
              ))}
            </ul>
            {features.length > 3 && (
              <div className="mt-1.5 text-[9px] font-semibold text-white/65">
                +{features.length - 3} more benefits
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
