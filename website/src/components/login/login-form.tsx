"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { ShieldCheck, User, ArrowRight, Loader2, AlertCircle, CheckCircle2, LockKeyhole } from "lucide-react";
import { createClient } from "@/lib/supabase/client";

export function LoginForm({
  mode,
  onToggleMode,
}: {
  mode: "member" | "staff";
  onToggleMode: () => void;
}) {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  const [forgotSent, setForgotSent] = useState(false);
  const [otp, setOtp] = useState("");
  const [newPassword, setNewPassword] = useState("");

  const isStaff = mode === "staff";

  // Tracks the latest `mode` prop so an in-flight handleForgotPassword() call
  // can tell, once it resolves, whether the user has since switched modes —
  // this component stays mounted across mode toggles, so state like
  // forgotSent otherwise persists and can leak into the wrong mode's view.
  const modeRef = useRef(mode);
  useEffect(() => {
    modeRef.current = mode;
  }, [mode]);

  function toggleMode() {
    onToggleMode();
    setPassword("");
    setError(null);
    setSuccessMessage(null);
    setForgotSent(false);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSuccessMessage(null);

    if (!email.trim() || !password.trim()) {
      setError("Please fill in all fields.");
      return;
    }

    setLoading(true);
    const supabase = createClient();

    // Members may sign in with a 10-digit phone number instead of email.
    let signinEmail = email.trim();
    if (!isStaff) {
      const onlyDigits = signinEmail.replace(/\D/g, "");
      if (onlyDigits.length === 10 && !signinEmail.includes("@")) {
        const { data: foundEmail, error: phoneLookupError } = await supabase.rpc("get_email_by_phone", {
          phone_input: onlyDigits,
        });
        if (phoneLookupError) {
          setError("Something went wrong. Please try again.");
          setLoading(false);
          return;
        }
        if (!foundEmail) {
          setError("No account found for this phone number.");
          setLoading(false);
          return;
        }
        signinEmail = foundEmail as string;
      }
    }

    const { data, error: signInError } = await supabase.auth.signInWithPassword({
      email: signinEmail,
      password: password.trim(),
    });

    if (signInError) {
      setError(signInError.message);
      setLoading(false);
      return;
    }

    const { data: profile } = await supabase.from("profiles").select("role").eq("id", data.user.id).maybeSingle();
    const isRoleAdmin = profile?.role === "admin";

    // Staff mode is a guard, not a gate: picking "Staff" but not actually
    // being an admin is rejected. Picking "Member" never blocks an admin —
    // they just land on the admin portal, same as the Flutter app.
    if (isStaff && !isRoleAdmin) {
      await supabase.auth.signOut();
      setError("Access denied. Admin privileges required.");
      setLoading(false);
      return;
    }

    router.push(isRoleAdmin ? "/admin" : "/member/today");
    router.refresh();
  }

  async function handleForgotPassword() {
    if (!email.trim()) {
      setError("Please enter your email address first to reset password.");
      return;
    }
    setError(null);
    setSuccessMessage(null);
    setLoading(true);
    const requestedMode = modeRef.current;
    const supabase = createClient();
    try {
      const { data: exists, error: existsError } = await supabase.rpc("check_email_exists", {
        email_to_check: email.trim(),
      });
      if (existsError) {
        setError("Something went wrong. Please try again.");
        return;
      }
      if (!exists) {
        setError("This email is not registered.");
        return;
      }
      const { error: resetErr } = await supabase.auth.resetPasswordForEmail(email.trim());
      if (resetErr) throw resetErr;
      // Guard against a stale response: if the user switched modes while this
      // request was in flight, don't flip the (still-mounted) form into the
      // OTP-reset view under the wrong mode.
      if (modeRef.current === requestedMode) {
        setForgotSent(true);
      }
    } catch {
      setError("Error processing request. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  async function handleVerifyForgotOtp() {
    if (otp.trim().length !== 6 || !newPassword.trim()) {
      setError("Please enter the 6-digit code and a new password.");
      return;
    }
    if (newPassword.trim().length < 6) {
      setError("Password must be at least 6 characters long.");
      return;
    }
    setError(null);
    setSuccessMessage(null);
    setLoading(true);
    const supabase = createClient();
    try {
      const { error: otpErr } = await supabase.auth.verifyOtp({ type: "recovery", token: otp.trim(), email: email.trim() });
      if (otpErr) throw otpErr;
      const { error: updateErr } = await supabase.auth.updateUser({ password: newPassword.trim() });
      if (updateErr) throw updateErr;
      setForgotSent(false);
      setOtp("");
      setNewPassword("");
      setPassword("");
      setError(null);
      setSuccessMessage("Password updated successfully. You can now sign in.");
    } catch {
      setError("Invalid verification code or error updating password.");
    } finally {
      setLoading(false);
    }
  }

  const accentGradient = isStaff ? "from-aqua to-pulse" : "from-brand to-aqua";
  const accentBorder = isStaff ? "border-aqua/20" : "border-brand/20";

  return (
    <div className={`w-full max-w-[380px] overflow-hidden rounded-2xl border ${accentBorder} bg-card shadow-2xl`}>
      <div className={`h-1 bg-gradient-to-r ${accentGradient}`} />
      <form onSubmit={forgotSent ? (e) => e.preventDefault() : handleSubmit} className="p-7">
        <div className="flex items-center gap-2">
          {isStaff ? <ShieldCheck className="size-[18px] text-aqua" /> : <User className="size-[18px] text-brand" />}
          <span className={`text-[10px] font-bold uppercase tracking-[0.18em] ${isStaff ? "text-aqua" : "text-brand"}`}>
            {isStaff ? "Authorized Personnel Only" : "Member Sign In"}
          </span>
        </div>

        {forgotSent ? (
          <>
            <p className="mt-4 text-[13px] leading-relaxed text-muted-foreground">
              We&apos;ve sent a 6-digit code to <span className="font-semibold text-foreground">{email}</span>
            </p>

            <label
              htmlFor="otp-code"
              className="mt-5 block text-[10px] font-semibold uppercase tracking-[0.14em] text-muted-foreground"
            >
              Verification Code
            </label>
            <input
              id="otp-code"
              value={otp}
              onChange={(e) => setOtp(e.target.value.replace(/\D/g, "").slice(0, 6))}
              inputMode="numeric"
              placeholder="000000"
              autoComplete="one-time-code"
              required
              aria-invalid={!!error}
              aria-describedby={error ? "recovery-error" : undefined}
              className="mt-2 h-[52px] w-full rounded-lg border border-border bg-background px-4 text-[16px] tracking-[6px] text-foreground outline-none focus:border-brand"
            />

            <label
              htmlFor="new-password"
              className="mt-4 block text-[10px] font-semibold uppercase tracking-[0.14em] text-muted-foreground"
            >
              New Password
            </label>
            <input
              id="new-password"
              type="password"
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
              placeholder="••••••••"
              autoComplete="new-password"
              required
              aria-invalid={!!error}
              aria-describedby={error ? "recovery-error" : undefined}
              className="mt-2 h-[52px] w-full rounded-lg border border-border bg-background px-4 text-[14px] text-foreground outline-none focus:border-brand"
            />

            {error && (
              <div
                id="recovery-error"
                className="mt-4 flex items-start gap-2 rounded-lg bg-danger/10 px-3 py-2.5 text-[13px] text-danger"
              >
                <AlertCircle className="mt-0.5 size-[15px] shrink-0" />
                {error}
              </div>
            )}

            <button
              type="button"
              onClick={handleVerifyForgotOtp}
              disabled={loading}
              className="mt-6 flex h-[52px] w-full items-center justify-center gap-2 rounded-lg bg-gradient-to-r from-brand to-aqua text-[15px] font-semibold text-white disabled:opacity-60"
            >
              {loading ? <Loader2 className="size-5 animate-spin" /> : "Verify & Update"}
            </button>
            <button
              type="button"
              onClick={() => {
                setForgotSent(false);
                setOtp("");
                setNewPassword("");
                setError(null);
              }}
              className="mt-3 w-full text-center text-[13px] font-medium text-muted-foreground"
            >
              Cancel
            </button>
          </>
        ) : (
          <>
            <label
              htmlFor="email-or-phone"
              className="mt-6 block text-[10px] font-semibold uppercase tracking-[0.14em] text-muted-foreground"
            >
              {isStaff ? "Admin Email" : "Email or Phone"}
            </label>
            <input
              id="email-or-phone"
              type={isStaff ? "email" : "text"}
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder={isStaff ? "admin@vishalfitness.com" : "Email or 10-digit phone"}
              autoComplete="username"
              required
              aria-invalid={!!error}
              aria-describedby={error ? "login-error" : undefined}
              className={`mt-2 h-[52px] w-full rounded-lg border bg-background px-4 text-[14px] text-foreground outline-none placeholder:text-muted-foreground ${isStaff ? "border-aqua/25 focus:border-aqua" : "border-border focus:border-brand"}`}
            />

            <label
              htmlFor="password"
              className="mt-5 block text-[10px] font-semibold uppercase tracking-[0.14em] text-muted-foreground"
            >
              {isStaff ? "Master Password" : "Password"}
            </label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              autoComplete="current-password"
              required
              aria-invalid={!!error}
              aria-describedby={error ? "login-error" : undefined}
              className={`mt-2 h-[52px] w-full rounded-lg border bg-background px-4 text-[14px] tracking-[4px] text-foreground outline-none placeholder:tracking-normal placeholder:text-muted-foreground ${isStaff ? "border-aqua/25 focus:border-aqua" : "border-border focus:border-brand"}`}
            />

            {!isStaff && (
              <div className="mt-2.5 flex justify-end">
                <button
                  type="button"
                  onClick={handleForgotPassword}
                  disabled={loading}
                  className="text-[13px] font-semibold text-brand disabled:opacity-60"
                >
                  Forgot Password?
                </button>
              </div>
            )}
            {isStaff && (
              <div className="mt-2.5 flex items-center justify-end gap-1.5 text-muted-foreground">
                <LockKeyhole className="size-3" />
                <span className="text-[10.5px] font-medium uppercase tracking-wide">Secure session</span>
              </div>
            )}

            {error && (
              <div
                id="login-error"
                className="mt-4 flex items-start gap-2 rounded-lg bg-danger/10 px-3 py-2.5 text-[13px] text-danger"
              >
                <AlertCircle className="mt-0.5 size-[15px] shrink-0" />
                {error}
              </div>
            )}

            {successMessage && (
              <div className="mt-4 flex items-start gap-2 rounded-lg bg-brand/10 px-3 py-2.5 text-[13px] text-brand">
                <CheckCircle2 className="mt-0.5 size-[15px] shrink-0" />
                {successMessage}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className={`mt-6 flex h-[52px] w-full items-center justify-center gap-2 rounded-lg bg-gradient-to-r ${accentGradient} text-[15px] font-semibold text-white transition-opacity disabled:opacity-60`}
            >
              {loading ? (
                <Loader2 className="size-5 animate-spin" />
              ) : (
                <>
                  {isStaff ? "Authenticate" : "Sign in"}
                  <ArrowRight className="size-[18px]" />
                </>
              )}
            </button>
          </>
        )}

        <button
          type="button"
          onClick={toggleMode}
          disabled={loading}
          className="mt-6 flex w-full items-center justify-center gap-1.5 text-[11px] font-semibold uppercase tracking-wide text-muted-foreground disabled:opacity-60"
        >
          {isStaff ? <User className="size-3.5" /> : <ShieldCheck className="size-3.5" />}
          {isStaff ? "Return to Member Login" : "Staff / Admin Access"}
        </button>
      </form>
    </div>
  );
}
