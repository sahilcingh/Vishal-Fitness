"use client";

import { usePathname } from "next/navigation";

// Re-keying on the pathname forces React to remount this div on every
// navigation, which replays the CSS animation - a plain className with no
// key change would only animate once, on first mount.
export function PageTransition({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  return (
    <div key={pathname} className="page-fade-admin">
      {children}
    </div>
  );
}
