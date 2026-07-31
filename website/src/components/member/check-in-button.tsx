"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { QrCode, Loader2, CheckCircle2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";

// Mirrors _handleCheckIn() in pass_screen.dart: upsert a profile row first
// (prevents an FK violation on check_ins for a brand-new account that has
// never touched its own profile row), then insert the check-in itself.
export function CheckInButton({ alreadyCheckedInToday = false }: { alreadyCheckedInToday?: boolean }) {
  const router = useRouter();
  const [state, setState] = useState<"idle" | "loading" | "success" | "error">("idle");
  // Seeded from the server's already-fetched check-ins (today's IST calendar
  // day) so a page load after checking in still shows the disabled state,
  // and also flips true locally right after a successful check-in — either
  // way this guards against a duplicate check_ins insert.
  const [checkedInToday, setCheckedInToday] = useState(alreadyCheckedInToday);

  async function handleCheckIn() {
    if (checkedInToday) return;
    setState("loading");
    const supabase = createClient();
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("no user");

      const fallbackName = (user.user_metadata?.full_name as string | undefined) ?? user.email?.split("@")[0] ?? "Member";
      await supabase.from("profiles").upsert({ id: user.id, full_name: fallbackName }, { onConflict: "id", ignoreDuplicates: true });

      const { error } = await supabase.from("check_ins").insert({ user_id: user.id });
      if (error) throw error;

      setState("success");
      setCheckedInToday(true);
      router.refresh();
    } catch {
      setState("error");
    } finally {
      setTimeout(() => setState((s) => (s === "success" || s === "error" ? "idle" : s)), 3000);
    }
  }

  const disabled = state === "loading" || checkedInToday;

  return (
    <div>
      <button
        type="button"
        onClick={handleCheckIn}
        disabled={disabled}
        className="flex w-full items-center justify-center gap-2 rounded-2xl bg-gradient-to-r from-sun to-pulse py-4 text-[15px] font-bold text-[#131316] disabled:opacity-70"
      >
        {state === "loading" ? (
          <Loader2 className="size-[18px] animate-spin" />
        ) : checkedInToday ? (
          <CheckCircle2 className="size-[18px]" />
        ) : (
          <QrCode className="size-[18px]" />
        )}
        {checkedInToday ? "Checked in today" : "Manual check-in"}
      </button>
      {state === "error" && <p className="mt-2 text-center text-[12.5px] text-danger">Check-in failed. Please contact staff.</p>}
    </div>
  );
}
