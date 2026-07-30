"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import {
  LayoutDashboard,
  Receipt,
  Users,
  CalendarClock,
  Ticket,
  Megaphone,
  History,
  FileBarChart,
  LogOut,
  Menu,
} from "lucide-react";
import { cn } from "@/lib/utils";

const NAV_ITEMS = [
  { href: "/admin", label: "Overview", icon: LayoutDashboard },
  { href: "/admin/daily-revenue", label: "Daily Revenue", icon: Receipt, tag: "NEW" },
] as const;

const MANAGE_ITEMS = [
  { href: "/admin/subscriptions", label: "Subscriptions", icon: Users },
  { href: "/admin/classes", label: "Classes", icon: CalendarClock },
  { href: "/admin/passes", label: "Passes", icon: Ticket },
] as const;

const INSIGHT_ITEMS = [
  { href: "/admin/reports", label: "Reports", icon: FileBarChart },
  { href: "/admin/expiry", label: "Expiry Alerts", icon: History },
  { href: "/admin/announcements", label: "Announcements", icon: Megaphone },
] as const;

function NavLink({
  href,
  label,
  icon: Icon,
  tag,
  active,
}: {
  href: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  tag?: string;
  active: boolean;
}) {
  return (
    <Link
      href={href}
      className={cn(
        "flex items-center gap-2.5 rounded-lg px-2.5 py-2.5 text-[13.5px] font-semibold transition-colors",
        active
          ? "bg-brand text-on-brand"
          : "text-sidebar-foreground/80 hover:bg-sidebar-accent hover:text-sidebar-foreground",
      )}
    >
      <Icon className="size-[17px] shrink-0" />
      {label}
      {tag && (
        <span className="ml-auto rounded-full bg-sun px-1.5 py-0.5 text-[8.5px] font-bold tracking-wide text-[#0F0F0F]">
          {tag}
        </span>
      )}
    </Link>
  );
}

export function AdminSidebar() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  return (
    <aside className="flex w-full flex-col gap-0 border-r border-sidebar-border bg-sidebar p-3.5 dark:bg-[linear-gradient(160deg,#141414,#242424)] md:sticky md:top-0 md:h-screen md:w-60">
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2.5 px-1.5 py-1">
          <div className="size-[34px] shrink-0 overflow-hidden rounded-full border border-sidebar-border bg-white">
            <Image src="/logo.jpg" alt="Vishal Fitness" width={34} height={34} className="size-full object-cover" />
          </div>
          <div>
            <div className="text-[15px] font-bold text-sidebar-foreground">Vishal Fitness</div>
            <div className="text-[9px] font-semibold uppercase tracking-widest text-sidebar-foreground/50">
              Admin Portal
            </div>
          </div>
        </div>
        <button
          className="grid size-9 shrink-0 place-items-center rounded-lg border border-sidebar-border md:hidden"
          onClick={() => setOpen((v) => !v)}
          aria-label="Toggle menu"
        >
          <Menu className="size-[18px] text-sidebar-foreground" />
        </button>
      </div>

      <nav className={cn("flex-1 flex-col gap-0.5 pt-4", open ? "flex" : "hidden md:flex")}>
        {NAV_ITEMS.map((item) => (
          <NavLink key={item.href} {...item} active={pathname === item.href} />
        ))}

        <div className="mb-1.5 mt-3.5 px-2.5 text-[9.5px] font-semibold uppercase tracking-widest text-sidebar-foreground/40">
          Manage
        </div>
        {MANAGE_ITEMS.map((item) => (
          <NavLink key={item.href} {...item} active={pathname === item.href} />
        ))}

        <div className="mb-1.5 mt-3.5 px-2.5 text-[9.5px] font-semibold uppercase tracking-widest text-sidebar-foreground/40">
          Insights
        </div>
        {INSIGHT_ITEMS.map((item) => (
          <NavLink key={item.href} {...item} active={pathname === item.href} />
        ))}
      </nav>

      <div className="mt-3.5 flex items-center gap-2.5 border-t border-sidebar-border pt-3.5">
        <div className="grid size-8 shrink-0 place-items-center rounded-full bg-brand/15 font-display text-sm font-bold text-brand">
          V
        </div>
        <div>
          <div className="text-[12.5px] font-bold text-sidebar-foreground">Vishal</div>
          <div className="text-[10.5px] text-sidebar-foreground/50">Owner</div>
        </div>
        <button
          className="ml-auto grid size-8 place-items-center rounded-lg border border-sidebar-border"
          aria-label="Sign out"
        >
          <LogOut className="size-4 text-energy" />
        </button>
      </div>
    </aside>
  );
}
