"use client";

import { useState } from "react";
import { Repeat } from "lucide-react";
import { QuickRenewModal } from "@/components/admin/quick-renew-modal";

type Pass = { id: string; name: string; price: number; duration_days: number };

export function QuickRenewButton({ passes }: { passes: Pass[] }) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <button
        onClick={() => setOpen(true)}
        className="flex items-center gap-2 rounded-xl border border-border bg-card px-4 py-2.5 text-[13px] font-bold text-foreground"
      >
        <Repeat className="size-[15px]" />
        Update Membership
      </button>
      <QuickRenewModal open={open} onClose={() => setOpen(false)} passes={passes} />
    </>
  );
}
