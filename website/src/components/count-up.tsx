"use client";

import { useEffect, useState } from "react";
import { formatINR } from "@/lib/format";

// Mirrors the design reference's countUp() exactly: same cubic ease-out
// (1 - (1-p)^3), same 1100ms default duration, same prefers-reduced-motion
// bailout. There, it re-triggers whenever a panel becomes active; here, each
// Server Component page mounts fresh on navigation, so the effect firing
// once per mount achieves the same "counts up when you land on this page"
// feel.
//
// `format` is a string key (not a function prop) deliberately - every call
// site here is a Server Component, and a plain function isn't serializable
// across the server/client boundary React Server Components draws.
export function CountUp({
  value,
  format,
  duration = 1100,
}: {
  value: number;
  format?: "inr";
  duration?: number;
}) {
  const [display, setDisplay] = useState(0);

  useEffect(() => {
    if (typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- reduced-motion bailout, mirrors the same pattern in theme-toggle.tsx
      setDisplay(value);
      return;
    }

    let raf = 0;
    let start: number | null = null;
    function frame(ts: number) {
      if (start === null) start = ts;
      const p = Math.min((ts - start) / duration, 1);
      const eased = 1 - Math.pow(1 - p, 3);
      setDisplay(value * eased);
      if (p < 1) raf = requestAnimationFrame(frame);
      else setDisplay(value);
    }
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [value, duration]);

  return <>{format === "inr" ? formatINR(display) : Math.round(display).toLocaleString("en-IN")}</>;
}
