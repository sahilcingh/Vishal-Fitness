"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { Home, Dumbbell, BarChart3, QrCode, Settings, Menu } from "lucide-react";
import { cn } from "@/lib/utils";
import { SettingsSheet } from "@/components/member/settings-sheet";

const NAV_ITEMS = [
  { href: "/member/today", label: "Today", icon: Home },
  { href: "/member/train", label: "Train", icon: Dumbbell },
  { href: "/member/progress", label: "Progress", icon: BarChart3 },
  { href: "/member/pass", label: "Pass", icon: QrCode },
] as const;

function NavLink({
  href,
  label,
  icon: Icon,
  active,
  onNavigate,
}: {
  href: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  active: boolean;
  onNavigate?: () => void;
}) {
  return (
    <Link
      href={href}
      onClick={onNavigate}
      className={cn(
        "flex items-center gap-2.5 rounded-lg px-2.5 py-2.5 text-[13.5px] font-semibold transition-colors",
        active
          ? "bg-brand text-on-brand"
          : "text-sidebar-foreground/80 hover:bg-sidebar-accent hover:text-sidebar-foreground",
      )}
    >
      <Icon className="size-[17px] shrink-0" />
      {label}
    </Link>
  );
}

export function MemberShell({
  name,
  email,
  photoUrl,
  children,
}: {
  name: string;
  email: string;
  photoUrl: string | null;
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);

  return (
    <div className="flex min-h-screen flex-col md:flex-row">
      <aside className="flex w-full flex-col gap-0 border-r border-sidebar-border bg-sidebar p-3.5 dark:bg-[linear-gradient(160deg,#141414,#242424)] md:sticky md:top-0 md:h-screen md:w-60">
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2.5 px-1.5 py-1">
            <div className="size-[34px] shrink-0 overflow-hidden rounded-full border border-sidebar-border bg-white">
              <Image src="/logo.jpg" alt="Vishal Fitness" width={34} height={34} className="size-full object-cover" />
            </div>
            <div>
              <div className="text-[15px] font-bold text-sidebar-foreground">Vishal Fitness</div>
              <div className="text-[9px] font-semibold uppercase tracking-widest text-sidebar-foreground/50">
                Member App
              </div>
            </div>
          </div>
          <button
            className="grid size-9 shrink-0 place-items-center rounded-lg border border-sidebar-border md:hidden"
            onClick={() => setOpen((v) => !v)}
            aria-label="Toggle menu"
            aria-expanded={open}
          >
            <Menu className="size-[18px] text-sidebar-foreground" />
          </button>
        </div>

        <nav className={cn("flex-1 flex-col gap-0.5 pt-4", open ? "flex" : "hidden md:flex")}>
          {NAV_ITEMS.map((item) => (
            <NavLink key={item.href} {...item} active={pathname === item.href} onNavigate={() => setOpen(false)} />
          ))}
        </nav>

        <div className="mt-3.5 flex items-center gap-2.5 border-t border-sidebar-border pt-3.5">
          <div className="grid size-8 shrink-0 place-items-center overflow-hidden rounded-full bg-brand/15 font-display text-sm font-bold text-brand">
            {photoUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={photoUrl} alt="" className="size-full object-cover" />
            ) : (
              name.charAt(0).toUpperCase() || "A"
            )}
          </div>
          <div className="min-w-0">
            <div className="truncate text-[12.5px] font-bold text-sidebar-foreground">{name}</div>
            <div className="truncate text-[10.5px] text-sidebar-foreground/50">{email}</div>
          </div>
          <button
            onClick={() => setSettingsOpen(true)}
            className="ml-auto grid size-8 shrink-0 place-items-center rounded-lg border border-sidebar-border text-sidebar-foreground/70"
            aria-label="Settings"
          >
            <Settings className="size-4" />
          </button>
        </div>
      </aside>

      <main key={pathname} className="page-fade-member mx-auto w-full max-w-[900px] flex-1 px-5 py-7 md:px-8">
        {children}
      </main>

      <SettingsSheet open={settingsOpen} onClose={() => setSettingsOpen(false)} name={name} photoUrl={photoUrl} />
    </div>
  );
}
