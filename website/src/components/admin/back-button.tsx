"use client";

import { useRouter } from "next/navigation";
import { ArrowLeft } from "lucide-react";

// A hardcoded back destination breaks once a page has more than one entry
// point (e.g. the member ledger is reachable both from the Ledger directory
// and from a member's card on Subscriptions) - browser history is the only
// thing that actually knows which one was used.
export function BackButton({ fallbackHref }: { fallbackHref: string }) {
  const router = useRouter();

  return (
    <button
      type="button"
      onClick={() => {
        if (typeof window !== "undefined" && window.history.length > 1) {
          router.back();
        } else {
          router.push(fallbackHref);
        }
      }}
      aria-label="Back"
      className="grid size-9 shrink-0 place-items-center rounded-xl border border-border bg-card"
    >
      <ArrowLeft className="size-4" />
    </button>
  );
}
