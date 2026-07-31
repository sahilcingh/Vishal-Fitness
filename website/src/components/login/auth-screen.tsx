"use client";

import { useState } from "react";
import Image from "next/image";
import { Dumbbell, CalendarCheck, QrCode, Users, TrendingUp, Megaphone } from "lucide-react";
import { LoginForm } from "@/components/login/login-form";

const MEMBER_HIGHLIGHTS = [
  { icon: Dumbbell, color: "text-brand", bg: "bg-brand/10", title: "Premium Equipment", sub: "Free weights, machines & dedicated cardio zones for every goal." },
  { icon: CalendarCheck, color: "text-energy", bg: "bg-energy/10", title: "100+ Classes Weekly", sub: "Yoga, Zumba, HIIT & CrossFit — guided by expert trainers." },
  { icon: QrCode, color: "text-aqua", bg: "bg-aqua/10", title: "Instant Digital Pass", sub: "Buy once, scan on arrival. No queues, no paperwork." },
] as const;

const STAFF_HIGHLIGHTS = [
  { icon: Users, color: "text-aqua", bg: "bg-aqua/10", title: "Member Management", sub: "Add, edit and track every gym subscription in one place." },
  { icon: TrendingUp, color: "text-energy", bg: "bg-energy/10", title: "Live Revenue Analytics", sub: "Monitor daily revenue, attendance and expiring memberships." },
  { icon: Megaphone, color: "text-pulse", bg: "bg-pulse/10", title: "Announcements", sub: "Push updates and alerts directly to every member, instantly." },
] as const;

export function AuthScreen() {
  const [mode, setMode] = useState<"member" | "staff">("member");
  const isStaff = mode === "staff";
  const highlights = isStaff ? STAFF_HIGHLIGHTS : MEMBER_HIGHLIGHTS;

  return (
    <div className="grid min-h-screen grid-cols-1 bg-background md:grid-cols-2">
      <div className="relative flex flex-col justify-between overflow-hidden px-6 py-10 sm:px-10 lg:px-16 lg:py-16">
        <div className="pointer-events-none absolute -right-28 -top-28 size-[380px] rounded-full bg-[radial-gradient(circle,rgba(38,182,232,0.18),transparent_70%)]" />
        <div className="pointer-events-none absolute -bottom-24 -left-20 size-[300px] rounded-full bg-[radial-gradient(circle,rgba(177,76,240,0.14),transparent_70%)]" />
        <div className="pointer-events-none absolute inset-y-0 left-0 w-[3px] bg-gradient-to-b from-aqua to-pulse" />

        <div className="relative z-10">
          <div className="flex items-center gap-3">
            <div className="grid size-11 shrink-0 place-items-center rounded-xl bg-gradient-to-br from-aqua to-pulse">
              <Image src="/logo.jpg" alt="Vishal Fitness" width={26} height={26} className="rounded" />
            </div>
            <span className="font-display text-2xl font-bold tracking-[0.06em] text-foreground">VISHAL FITNESS</span>
          </div>
          <div className="mt-6 flex items-center gap-2">
            <span className="size-1.5 rounded-full bg-aqua" />
            <span className="text-[10px] font-semibold uppercase tracking-[0.2em] text-muted-foreground">
              {isStaff ? "Secure Access" : "Welcome Back"}
            </span>
          </div>

          {isStaff ? (
            <>
              <h1 className="font-display mt-8 text-[34px] font-bold leading-[1.1] text-foreground sm:text-[42px]">
                Admin Command
                <br />
                <span className="text-aqua">Center.</span>
              </h1>
              <p className="mt-4 max-w-md text-[15px] leading-relaxed text-muted-foreground">
                Enter secure credentials to access the gym command center and manage operations.
              </p>
            </>
          ) : (
            <>
              <h1 className="font-display mt-8 text-[34px] font-bold leading-[1.1] text-foreground sm:text-[42px]">
                Sign in to <span className="text-brand">continue</span>
                <br />
                training.
              </h1>
              <p className="mt-4 max-w-md text-[15px] leading-relaxed text-muted-foreground">
                Your streak is waiting. Let&apos;s pick up where you left off.
              </p>
            </>
          )}
        </div>

        <div className="relative z-10 mt-10 space-y-5 lg:mt-0">
          {highlights.map((h) => (
            <div key={h.title} className="flex items-start gap-4">
              <div className={`grid size-11 shrink-0 place-items-center rounded-xl ${h.bg}`}>
                <h.icon className={`size-[22px] ${h.color}`} />
              </div>
              <div>
                <div className="text-[15px] font-bold text-foreground">{h.title}</div>
                <div className="mt-0.5 text-[13px] leading-snug text-muted-foreground">{h.sub}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="flex items-center justify-center border-t border-border px-6 py-10 md:border-l md:border-t-0 md:px-10">
        <LoginForm mode={mode} onToggleMode={() => setMode(isStaff ? "member" : "staff")} />
      </div>
    </div>
  );
}
