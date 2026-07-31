"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { User, Camera, Loader2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Modal } from "@/components/admin/modal";

// Same cap/type check used in admin/add-member-form.tsx and
// admin/edit-member-modal.tsx - keep all three photo uploads consistent.
const MAX_PHOTO_BYTES = 5 * 1024 * 1024;

export function EditProfileModal({
  open,
  onClose,
  initialName,
  initialPhotoUrl,
}: {
  open: boolean;
  onClose: () => void;
  initialName: string;
  initialPhotoUrl: string | null;
}) {
  const router = useRouter();
  const [name, setName] = useState(initialName);
  const [phone, setPhone] = useState("");
  const [email, setEmail] = useState("");
  const [currentEmail, setCurrentEmail] = useState("");
  const [photoUrl, setPhotoUrl] = useState<string | null>(initialPhotoUrl);
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [otpStep, setOtpStep] = useState(false);
  const [otp, setOtp] = useState("");
  const [photoError, setPhotoError] = useState<string | null>(null);

  // Separate in-flight flags per action - sending/verifying an email OTP
  // must not disable or spinner the unrelated Save Changes button, and vice
  // versa.
  const [savingProfile, setSavingProfile] = useState(false);
  const [savingEmailStep, setSavingEmailStep] = useState(false);

  // Field-scoped errors render directly under the field they describe;
  // `error` is reserved for whole-form failures (e.g. a network error saving
  // the entire profile) that don't belong to one field.
  const [error, setError] = useState<string | null>(null);
  const [nameError, setNameError] = useState<string | null>(null);
  const [phoneError, setPhoneError] = useState<string | null>(null);
  const [emailError, setEmailError] = useState<string | null>(null);
  const [otpError, setOtpError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- reset the form to the member's current data each time the sheet opens
    setError(null);
    setNameError(null);
    setPhoneError(null);
    setEmailError(null);
    setOtpError(null);
    setOtpStep(false);
    setOtp("");
    setPhotoFile(null);
    setPhotoPreview(null);
    setPhotoError(null);
    setPhotoUrl(initialPhotoUrl);
    setName(initialName);

    (async () => {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) return;
      setCurrentEmail(user.email ?? "");
      setEmail(user.email ?? "");
      const { data: profile } = await supabase.from("profiles").select("phone").eq("id", user.id).maybeSingle();
      setPhone(profile?.phone ?? "");
    })();
  }, [open, initialName, initialPhotoUrl]);

  if (!open) return null;

  const emailChanged = email.trim() !== currentEmail;

  function handlePhotoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith("image/") || file.size > MAX_PHOTO_BYTES) {
      setPhotoError("Please choose an image under 5MB.");
      e.target.value = "";
      return;
    }
    setPhotoError(null);
    setPhotoFile(file);
    setPhotoPreview(URL.createObjectURL(file));
  }

  function handlePhotoLabelKeyDown(e: React.KeyboardEvent<HTMLLabelElement>) {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      fileInputRef.current?.click();
    }
  }

  async function handleSave() {
    setError(null);
    setNameError(null);
    setPhoneError(null);
    if (!name.trim()) return setNameError("Name cannot be empty.");
    if (phone.trim() && phone.replace(/\D/g, "").length !== 10) {
      return setPhoneError("Mobile number must be exactly 10 digits.");
    }
    setSavingProfile(true);
    const supabase = createClient();
    try {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) throw new Error("Not signed in");

      let newPhotoUrl = photoUrl;
      if (photoFile) {
        const path = `${user.id}/avatar.jpg`;
        const { error: upErr } = await supabase.storage.from("member-photos").upload(path, photoFile, {
          upsert: true,
          contentType: "image/jpeg",
        });
        if (upErr) {
          setError(`Failed to upload photo: ${upErr.message}`);
          setSavingProfile(false);
          return;
        }
        const { data } = supabase.storage.from("member-photos").getPublicUrl(path);
        newPhotoUrl = data.publicUrl;
      }

      const payload: Record<string, unknown> = { id: user.id, full_name: name.trim() };
      if (phone.trim()) payload.phone = phone.trim();
      if (newPhotoUrl) payload.photo_url = newPhotoUrl;
      const { error: upsertErr } = await supabase.from("profiles").upsert(payload);
      if (upsertErr) throw upsertErr;

      router.refresh();
      onClose();
    } catch {
      setError("Failed to save. Please try again.");
    } finally {
      setSavingProfile(false);
    }
  }

  async function handleSendEmailOtp() {
    setEmailError(null);
    if (!email.trim()) return setEmailError("Please enter a valid email address.");
    if (email.trim() === currentEmail) return setEmailError("This is already your current email.");
    setSavingEmailStep(true);
    const supabase = createClient();
    try {
      const { error: updateErr } = await supabase.auth.updateUser({ email: email.trim() });
      if (updateErr) throw updateErr;
      setOtpStep(true);
    } catch {
      setEmailError("Could not send verification code. Try again.");
    } finally {
      setSavingEmailStep(false);
    }
  }

  async function handleVerifyEmailOtp() {
    setOtpError(null);
    if (otp.trim().length !== 6) return setOtpError("Enter the 6-digit code sent to your new email.");
    setSavingEmailStep(true);
    const supabase = createClient();
    try {
      const { error: otpErr } = await supabase.auth.verifyOtp({ email: email.trim(), token: otp.trim(), type: "email_change" });
      if (otpErr) throw otpErr;
      setCurrentEmail(email.trim());
      setOtpStep(false);
      setOtp("");
      router.refresh();
      onClose();
    } catch {
      setOtpError("Invalid or expired code.");
    } finally {
      setSavingEmailStep(false);
    }
  }

  return (
    <Modal open={open} onClose={onClose} maxWidthClass="max-w-[420px]">
      {otpStep ? (
        <>
          <div className="text-[17px] font-bold">Verify New Email</div>
          <p className="mt-2 text-[13px] text-muted-foreground">Code sent to {email.trim()}</p>
          <label className="mt-4 block text-[10px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            6-Digit Verification Code
          </label>
          <input
            value={otp}
            onChange={(e) => setOtp(e.target.value.replace(/\D/g, "").slice(0, 6))}
            inputMode="numeric"
            placeholder="000000"
            className="mt-2 h-[50px] w-full rounded-xl border border-border bg-card px-4 text-[16px] tracking-[6px] outline-none focus:border-brand"
          />
          {otpError && <div className="mt-3 rounded-xl bg-danger/10 px-3.5 py-3 text-[13px] text-danger">{otpError}</div>}
          <button
            onClick={handleVerifyEmailOtp}
            disabled={savingEmailStep}
            className="mt-4 w-full rounded-xl bg-brand py-3 text-[14px] font-bold text-on-brand disabled:opacity-50"
          >
            {savingEmailStep ? "Verifying…" : "Confirm Email Change"}
          </button>
          <div className="mt-3 flex items-center justify-center gap-3 text-[13px]">
            <button onClick={handleSendEmailOtp} disabled={savingEmailStep} className="font-semibold text-brand">
              Resend code
            </button>
            <span className="text-muted-foreground">·</span>
            <button
              onClick={() => {
                setOtpStep(false);
                setOtp("");
                setOtpError(null);
                setEmail(currentEmail);
              }}
              className="font-medium text-muted-foreground"
            >
              Cancel
            </button>
          </div>
        </>
      ) : (
        <>
          <div className="text-[17px] font-bold">Edit Profile</div>

          <div className="mt-5 flex justify-center">
            <label
              className="relative cursor-pointer rounded-full focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
              tabIndex={0}
              role="button"
              aria-label="Change profile photo"
              onKeyDown={handlePhotoLabelKeyDown}
            >
              <div className="grid size-20 place-items-center overflow-hidden rounded-full border-2 border-brand/25 bg-brand/8">
                {photoPreview ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={photoPreview} alt="" className="size-full object-cover" />
                ) : photoUrl ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={photoUrl} alt="" className="size-full object-cover" />
                ) : (
                  <User className="size-8 text-brand" />
                )}
              </div>
              <span className="absolute bottom-0 right-0 grid size-[24px] place-items-center rounded-full border-2 border-card bg-brand">
                <Camera className="size-3 text-white" />
              </span>
              <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={handlePhotoChange} />
            </label>
          </div>
          {photoError && <p className="mt-2 text-center text-[11.5px] font-medium text-danger">{photoError}</p>}

          <div className="mt-6 flex flex-col gap-3.5">
            <div>
              <label className="text-[10px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">Full Name</label>
              <input
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Your full name"
                className="mt-1.5 h-[48px] w-full rounded-xl border border-border bg-card px-4 text-[14px] outline-none focus:border-brand"
              />
              {nameError && <p className="mt-1.5 text-[11.5px] font-medium text-danger">{nameError}</p>}
            </div>
            <div>
              <label className="text-[10px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">Mobile Number</label>
              <input
                value={phone}
                onChange={(e) => setPhone(e.target.value.replace(/\D/g, "").slice(0, 10))}
                inputMode="numeric"
                placeholder="10-digit mobile number"
                className="mt-1.5 h-[48px] w-full rounded-xl border border-border bg-card px-4 text-[14px] outline-none focus:border-brand"
              />
              {phoneError && <p className="mt-1.5 text-[11.5px] font-medium text-danger">{phoneError}</p>}
            </div>
            <div>
              <label className="text-[10px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">Email Address</label>
              <div className="mt-1.5 flex gap-2">
                <input
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="your@email.com"
                  className="h-[48px] flex-1 rounded-xl border border-border bg-card px-4 text-[14px] outline-none focus:border-brand"
                />
                <button
                  onClick={handleSendEmailOtp}
                  disabled={savingEmailStep || !emailChanged}
                  className="shrink-0 rounded-xl bg-brand/12 px-4 text-[13px] font-bold text-brand disabled:bg-muted disabled:text-muted-foreground"
                >
                  {savingEmailStep ? "Sending…" : "Verify"}
                </button>
              </div>
              {emailChanged && !emailError && (
                <p className="mt-1.5 text-[10.5px] font-medium text-energy">Tap &quot;Verify&quot; to confirm new email via OTP.</p>
              )}
              {emailError && <p className="mt-1.5 text-[11.5px] font-medium text-danger">{emailError}</p>}
            </div>
          </div>

          {error && <div className="mt-4 rounded-xl bg-danger/10 px-3.5 py-3 text-[13px] text-danger">{error}</div>}

          <button
            onClick={handleSave}
            disabled={savingProfile}
            className="mt-6 flex w-full items-center justify-center gap-2 rounded-xl bg-brand py-3.5 text-[15px] font-bold text-on-brand disabled:opacity-50"
          >
            {savingProfile ? <Loader2 className="size-5 animate-spin" /> : "Save Changes"}
          </button>
        </>
      )}
    </Modal>
  );
}
