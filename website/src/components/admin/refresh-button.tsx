"use client";

import { useRouter } from "next/navigation";
import { RefreshCw } from "lucide-react";

export function RefreshButton() {
  const router = useRouter();

  return (
    <button
      onClick={() => router.refresh()}
      aria-label="Refresh dashboard"
      className="grid size-[38px] place-items-center rounded-xl border border-border bg-card"
    >
      <RefreshCw className="size-4 text-muted-foreground" />
    </button>
  );
}
