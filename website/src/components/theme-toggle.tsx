"use client";

import { useEffect, useState } from "react";
import { useTheme } from "next-themes";
import { Sun, Moon } from "lucide-react";

// Self-contained styling (own background/border/shadow) so this renders
// legibly on any surface — a dark sidebar, a light hero section, or floating
// over page content — since it's now rendered once, globally, in the root
// layout rather than per-page.
export function ThemeToggle() {
  const { resolvedTheme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- standard next-themes hydration guard
    setMounted(true);
  }, []);

  if (!mounted) {
    return <div className="size-10 shrink-0 rounded-full border border-border bg-card shadow-md" />;
  }

  const isDark = resolvedTheme === "dark";

  return (
    <button
      onClick={() => setTheme(isDark ? "light" : "dark")}
      className="grid size-10 shrink-0 place-items-center rounded-full border border-border bg-card text-foreground/70 shadow-md hover:text-foreground"
      aria-label="Toggle theme"
    >
      {isDark ? <Sun className="size-[18px]" /> : <Moon className="size-[18px]" />}
    </button>
  );
}
