"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import {
  LayoutDashboard,
  Receipt,
  Users,
  UserPlus,
  UserCog,
  CalendarClock,
  Ticket,
  Megaphone,
  History,
  BookOpen,
  FileBarChart,
  LogOut,
  Menu,
  X,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { createClient } from "@/lib/supabase/client";

const NAV_ITEMS = [
  { href: "/admin", label: "Overview", icon: LayoutDashboard },
  { href: "/admin/daily-revenue", label: "Daily Revenue", icon: Receipt, tag: "NEW" },
  { href: "/admin/members", label: "Ledger", icon: BookOpen, tag: "NEW" },
] as const;

const MANAGE_ITEMS = [
  { href: "/admin/add-member", label: "Add Member", icon: UserPlus },
  { href: "/admin/edit-member", label: "Edit Member", icon: UserCog },
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
      aria-current={active ? "page" : undefined}
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

export function AdminSidebar({ name, email }: { name: string; email: string }) {
  const pathname = usePathname();
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [signingOut, setSigningOut] = useState(false);

  // Navigating (e.g. tapping a link inside the drawer) shouldn't leave the
  // overlay open on top of the new page - this layout persists across route
  // changes, it isn't remounted per page. Adjusting state during render
  // (React's recommended pattern for this) instead of an effect, so the
  // drawer closes in the same paint as the navigation rather than one tick
  // later.
  const [prevPathname, setPrevPathname] = useState(pathname);
  if (pathname !== prevPathname) {
    setPrevPathname(pathname);
    setOpen(false);
  }

  // Prevent the page behind the mobile drawer from scrolling while it's open.
  useEffect(() => {
    if (!open) return;
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previous;
    };
  }, [open]);

  async function handleSignOut() {
    setSigningOut(true);
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/");
    router.refresh();
  }

  const navLinks = (
    <>
      <nav className="flex flex-1 flex-col gap-0.5 pt-4">
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
          {name.charAt(0).toUpperCase() || "A"}
        </div>
        <div className="min-w-0">
          <div className="truncate text-[12.5px] font-bold text-sidebar-foreground">{name}</div>
          <div className="truncate text-[10.5px] text-sidebar-foreground/50">{email || "Owner"}</div>
        </div>
        <button
          onClick={handleSignOut}
          disabled={signingOut}
          className="ml-auto grid size-8 shrink-0 place-items-center rounded-lg border border-sidebar-border disabled:opacity-50"
          aria-label="Sign out"
        >
          <LogOut className="size-4 text-energy" />
        </button>
      </div>
    </>
  );

  return (
    <>
      {/* Persistent column: full sidebar on desktop; on mobile, just the
          logo header + menu toggle bar (never slides away). */}
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
            onClick={() => setOpen(true)}
            aria-label="Open menu"
            aria-expanded={open}
          >
            <Menu className="size-[18px] text-sidebar-foreground" />
          </button>
        </div>

        <div className="hidden md:flex md:flex-1 md:flex-col">{navLinks}</div>
      </aside>

      {/* Mobile-only slide-in drawer + backdrop. Always mounted (not
          conditionally rendered) so the transform/opacity transitions can
          actually animate in and out, instead of popping in statically. */}
      <div
        className={cn(
          "fixed inset-0 z-40 bg-black/60 transition-opacity duration-300 md:hidden",
          open ? "opacity-100" : "pointer-events-none opacity-0",
        )}
        onClick={() => setOpen(false)}
        aria-hidden="true"
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-label="Admin navigation"
        className={cn(
          "fixed inset-y-0 left-0 z-50 flex w-72 max-w-[80vw] flex-col border-r border-sidebar-border bg-sidebar p-3.5 shadow-2xl transition-transform duration-300 ease-[cubic-bezier(0.16,1,0.3,1)] dark:bg-[linear-gradient(160deg,#141414,#242424)] md:hidden",
          open ? "translate-x-0" : "-translate-x-full",
        )}
      >
        <div className="flex items-center justify-between gap-2 px-1.5 py-1">
          <div className="text-[13px] font-bold text-sidebar-foreground">Menu</div>
          <button
            className="grid size-8 shrink-0 place-items-center rounded-lg border border-sidebar-border"
            onClick={() => setOpen(false)}
            aria-label="Close menu"
          >
            <X className="size-4 text-sidebar-foreground" />
          </button>
        </div>
        {navLinks}
      </div>
    </>
  );
}
