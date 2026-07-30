import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { LoginForm } from "@/components/login/login-form";
import Image from "next/image";
import { Users, BarChart3, Megaphone } from "lucide-react";

export const dynamic = "force-dynamic";

const HIGHLIGHTS = [
  {
    icon: Users,
    color: "text-aqua",
    bg: "bg-aqua/10",
    title: "Member Management",
    sub: "Add, edit and track all gym subscriptions in one place.",
  },
  {
    icon: BarChart3,
    color: "text-energy",
    bg: "bg-energy/10",
    title: "Live Analytics",
    sub: "Monitor revenue, attendance and expiring memberships.",
  },
  {
    icon: Megaphone,
    color: "text-pulse",
    bg: "bg-pulse/10",
    title: "Announcements",
    sub: "Push updates and alerts directly to all members instantly.",
  },
] as const;

export default async function LoginPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (user) redirect("/admin");

  return (
    <div className="grid min-h-screen grid-cols-1 bg-[#0d0d0d] md:grid-cols-2">
      <div className="relative flex flex-col justify-between overflow-hidden px-6 py-10 sm:px-10 lg:px-16 lg:py-16">
        <div className="pointer-events-none absolute -right-28 -top-28 size-[380px] rounded-full bg-[radial-gradient(circle,rgba(38,182,232,0.18),transparent_70%)]" />
        <div className="pointer-events-none absolute -bottom-24 -left-20 size-[300px] rounded-full bg-[radial-gradient(circle,rgba(177,76,240,0.14),transparent_70%)]" />
        <div className="pointer-events-none absolute inset-y-0 left-0 w-[3px] bg-gradient-to-b from-aqua to-pulse" />

        <div className="relative z-10">
          <div className="flex items-center gap-3">
            <div className="grid size-11 shrink-0 place-items-center rounded-xl bg-gradient-to-br from-aqua to-pulse">
              <Image src="/logo.jpg" alt="" width={26} height={26} className="rounded" />
            </div>
            <span className="font-display text-2xl font-bold tracking-[0.06em] text-white">
              STAFF PORTAL
            </span>
          </div>
          <div className="mt-6 flex items-center gap-2">
            <span className="size-1.5 rounded-full bg-aqua" />
            <span className="text-[10px] font-semibold uppercase tracking-[0.2em] text-white/50">
              Secure Access
            </span>
          </div>

          <h1 className="font-display mt-8 text-[34px] font-bold leading-[1.1] text-white sm:text-[42px]">
            Admin Command
            <br />
            <span className="text-aqua">Center.</span>
          </h1>
          <p className="mt-4 max-w-md text-[15px] leading-relaxed text-white/50">
            Enter secure credentials to access the gym command center and manage operations.
          </p>
        </div>

        <div className="relative z-10 mt-10 space-y-5 lg:mt-0">
          {HIGHLIGHTS.map((h) => (
            <div key={h.title} className="flex items-start gap-4">
              <div className={`grid size-11 shrink-0 place-items-center rounded-xl ${h.bg}`}>
                <h.icon className={`size-[22px] ${h.color}`} />
              </div>
              <div>
                <div className="text-[15px] font-bold text-white">{h.title}</div>
                <div className="mt-0.5 text-[13px] leading-snug text-white/45">{h.sub}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="flex items-center justify-center border-t border-white/5 bg-black/20 px-6 py-10 md:border-l md:border-t-0 md:px-10">
        <LoginForm />
      </div>
    </div>
  );
}
