"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { ShieldCheck, ArrowRight, Loader2, AlertCircle } from "lucide-react";
import { createClient } from "@/lib/supabase/client";

export function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (!email.trim() || !password.trim()) {
      setError("Please fill in all fields.");
      return;
    }

    setLoading(true);
    const supabase = createClient();

    const { data, error: signInError } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password: password.trim(),
    });

    if (signInError) {
      setError(signInError.message);
      setLoading(false);
      return;
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", data.user.id)
      .maybeSingle();

    if (profile?.role !== "admin") {
      await supabase.auth.signOut();
      setError("Access denied. Admin privileges required.");
      setLoading(false);
      return;
    }

    router.push("/admin");
    router.refresh();
  }

  return (
    <div className="w-full max-w-[380px] overflow-hidden rounded-2xl border border-aqua/20 bg-card shadow-2xl">
      <div className="h-1 bg-gradient-to-r from-aqua to-pulse" />
      <form onSubmit={handleSubmit} className="p-7">
        <div className="flex items-center gap-2">
          <ShieldCheck className="size-[18px] text-aqua" />
          <span className="text-[10px] font-bold uppercase tracking-[0.18em] text-aqua">
            Authorized Personnel Only
          </span>
        </div>

        <label className="mt-6 block text-[10px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
          Admin Email
        </label>
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="admin@yourgym.com"
          autoComplete="email"
          className="mt-2 h-[52px] w-full rounded-lg border border-aqua/25 bg-white/[0.03] px-4 text-[14px] text-foreground outline-none placeholder:text-muted-foreground focus:border-aqua"
        />

        <label className="mt-5 block text-[10px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
          Master Password
        </label>
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="••••••••"
          autoComplete="current-password"
          className="mt-2 h-[52px] w-full rounded-lg border border-aqua/25 bg-white/[0.03] px-4 text-[14px] tracking-[4px] text-foreground outline-none placeholder:tracking-normal placeholder:text-muted-foreground focus:border-aqua"
        />

        {error && (
          <div className="mt-4 flex items-start gap-2 rounded-lg bg-danger/10 px-3 py-2.5 text-[13px] text-danger">
            <AlertCircle className="mt-0.5 size-[15px] shrink-0" />
            {error}
          </div>
        )}

        <button
          type="submit"
          disabled={loading}
          className="mt-6 flex h-[52px] w-full items-center justify-center gap-2 rounded-lg bg-gradient-to-r from-aqua to-pulse text-[15px] font-semibold text-white transition-opacity disabled:opacity-60"
        >
          {loading ? (
            <Loader2 className="size-5 animate-spin" />
          ) : (
            <>
              Authenticate
              <ArrowRight className="size-[18px]" />
            </>
          )}
        </button>
      </form>
    </div>
  );
}
