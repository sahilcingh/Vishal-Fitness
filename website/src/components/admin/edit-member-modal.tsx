"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import {
  User,
  Camera,
  KeyRound,
  Copy,
  Loader2,
  ChevronDown,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { formatINR } from "@/lib/format";
import { Modal } from "@/components/admin/modal";

type Pass = { id: string; name: string; price: number; duration_days: number };
export type EditableMember = {
  id: string;
  full_name: string | null;
  phone: string | null;
};

const GENDERS = ["Male", "Female", "Other"];
const MAX_PHOTO_BYTES = 5 * 1024 * 1024;

function toYMD(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
function parseYMD(s: string) {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}
function addDays(s: string, days: number) {
  const d = parseYMD(s);
  d.setDate(d.getDate() + days);
  return toYMD(d);
}
function prettyDate(s: string) {
  return parseYMD(s).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
}
function isValidYMD(s: string) {
  return /^\d{4}-\d{2}-\d{2}$/.test(s);
}
// Supabase returns `date` columns as "YYYY-MM-DD" but `timestamp`/`timestamptz`
// columns as a full ISO string ("YYYY-MM-DDTHH:mm:ss+00:00") - normalize either
// to a bare date so we never silently discard a real stored date.
function normalizeYMD(s: string | null | undefined) {
  if (!s) return "";
  const sliced = s.slice(0, 10);
  return isValidYMD(sliced) ? sliced : "";
}

export function EditMemberModal({
  member,
  passes,
  onClose,
  onSaved,
}: {
  member: EditableMember | null;
  passes: Pass[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const [loading, setLoading] = useState(true);
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [gender, setGender] = useState("");
  const [timeSlot, setTimeSlot] = useState("");
  const [memberEmail, setMemberEmail] = useState("");
  const [email, setEmail] = useState("");
  const [existingPhotoUrl, setExistingPhotoUrl] = useState<string | null>(null);
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);

  const [subscriptionId, setSubscriptionId] = useState<string | null>(null);
  const [passId, setPassId] = useState("");
  const [originalPassId, setOriginalPassId] = useState("");
  const [startDate, setStartDate] = useState(toYMD(new Date()));
  const [originalStartDate, setOriginalStartDate] = useState("");
  const [storedEndDate, setStoredEndDate] = useState("");
  const [extraDays, setExtraDays] = useState("");

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isResetting, setIsResetting] = useState(false);
  const [newPassword, setNewPassword] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const selectedPass = passes.find((p) => p.id === passId) ?? null;
  const extraDaysNum = parseInt(extraDays, 10) || 0;
  // Show the real stored end_date until the admin actually changes something
  // that would affect it (pass, start date, or extra days) - only then recompute.
  const unchanged = passId === originalPassId && startDate === originalStartDate && extraDaysNum === 0;
  const endDate =
    unchanged && storedEndDate
      ? storedEndDate
      : selectedPass && isValidYMD(startDate)
        ? addDays(startDate, selectedPass.duration_days + extraDaysNum)
        : startDate;

  useEffect(() => {
    if (!member) return;
    let cancelled = false;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- reset transient state before the async fetch for the newly-opened member starts
    setLoading(true);
    setError(null);
    setNewPassword(null);
    setPhotoFile(null);
    setPhotoPreview(null);

    (async () => {
      const supabase = createClient();
      const { data: profile } = await supabase
        .from("profiles")
        .select("full_name, phone, gender, time_slot, photo_url")
        .eq("id", member.id)
        .maybeSingle();
      if (cancelled) return;

      setName(profile?.full_name ?? "");
      setPhone(profile?.phone ?? "");
      setGender(profile?.gender ?? "");
      setTimeSlot(profile?.time_slot ?? "");
      setExistingPhotoUrl(profile?.photo_url ?? null);

      // Fetch fresh - prefer the active subscription, else the most recent one.
      const { data: activeSubs } = await supabase
        .from("subscriptions")
        .select("id, pass_id, status, start_date, end_date")
        .eq("user_id", member.id)
        .eq("status", "active")
        .order("created_at", { ascending: false })
        .limit(1);
      let sub = activeSubs?.[0];
      if (!sub) {
        const { data: anySubs } = await supabase
          .from("subscriptions")
          .select("id, pass_id, status, start_date, end_date")
          .eq("user_id", member.id)
          .order("created_at", { ascending: false })
          .limit(1);
        sub = anySubs?.[0];
      }
      if (cancelled) return;

      if (sub) {
        const normalizedStart = normalizeYMD(sub.start_date) || toYMD(new Date());
        setSubscriptionId(sub.id);
        setPassId(sub.pass_id ?? "");
        setOriginalPassId(sub.pass_id ?? "");
        setStartDate(normalizedStart);
        setOriginalStartDate(normalizedStart);
        setStoredEndDate(normalizeYMD(sub.end_date));
      } else {
        setSubscriptionId(null);
        setPassId("");
        setOriginalPassId("");
        setStartDate(toYMD(new Date()));
        setOriginalStartDate(toYMD(new Date()));
        setStoredEndDate("");
      }
      setExtraDays("");
      setLoading(false);

      const phoneVal = profile?.phone ?? "";
      if (phoneVal) {
        const { data: emailData } = await supabase.rpc("get_email_by_phone", {
          phone_input: phoneVal.replace(/\D/g, ""),
        });
        if (!cancelled) {
          const found = (emailData as string) ?? "";
          setMemberEmail(found);
          setEmail(found);
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [member]);

  if (!member) return null;

  function handlePhotoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith("image/") || file.size > MAX_PHOTO_BYTES) {
      setError("Please choose an image under 5MB.");
      e.target.value = "";
      return;
    }
    setError(null);
    setPhotoFile(file);
    setPhotoPreview(URL.createObjectURL(file));
  }

  async function uploadPhotoIfAny(userId: string) {
    if (!photoFile) return null;
    const supabase = createClient();
    const ext = photoFile.name.includes(".") ? photoFile.name.split(".").pop()!.toLowerCase() : "jpg";
    const path = `${userId}/avatar.${ext}`;
    const { error: upErr } = await supabase.storage.from("member-photos").upload(path, photoFile, { upsert: true });
    if (upErr) return null;
    const { data } = supabase.storage.from("member-photos").getPublicUrl(path);
    return data.publicUrl;
  }

  async function handleResetPassword() {
    if (!window.confirm("Reset this member's password? Their current credentials will stop working immediately.")) {
      return;
    }
    setIsResetting(true);
    setError(null);
    setNewPassword(null);
    const supabase = createClient();
    try {
      const { data, error: fnError } = await supabase.functions.invoke("reset-member-password", {
        body: { user_id: member!.id },
      });
      let result = data as { success?: boolean; temp_password?: string; error?: string } | null;
      if (fnError) {
        try {
          result = await (fnError as unknown as { context: Response }).context.json();
        } catch {
          result = { error: fnError.message };
        }
      }
      if (result?.success) {
        setNewPassword(result.temp_password ?? null);
      } else {
        setError(result?.error ?? "Deploy the reset-member-password Edge Function first.");
      }
    } catch {
      setError("Reset failed. Deploy the reset-member-password Edge Function first.");
    } finally {
      setIsResetting(false);
    }
  }

  async function handleSave() {
    if (!name.trim()) return setError("Name is required.");
    if (!/^\d{10}$/.test(phone.trim())) return setError("Enter a valid 10-digit phone number.");
    setError(null);
    setIsSubmitting(true);
    const supabase = createClient();
    try {
      const photoUrl = await uploadPhotoIfAny(member!.id);
      const photoFailed = !!photoFile && !photoUrl;
      const profileUpdate: Record<string, unknown> = {
        full_name: name.trim(),
        phone: phone.trim(),
        gender: gender || null,
        time_slot: timeSlot.trim() || null,
      };
      if (photoUrl) profileUpdate.photo_url = photoUrl;
      const { error: profileErr } = await supabase.from("profiles").update(profileUpdate).eq("id", member!.id);
      if (profileErr) throw profileErr;

      if (passId && subscriptionId) {
        const { error: subErr } = await supabase
          .from("subscriptions")
          .update({ pass_id: passId, start_date: startDate, end_date: endDate })
          .eq("id", subscriptionId);
        if (subErr) throw subErr;
      }

      const trimmedEmail = email.trim();
      if (trimmedEmail && trimmedEmail !== memberEmail && trimmedEmail.includes("@")) {
        try {
          const { data: emailData, error: emailErr } = await supabase.functions.invoke("reset-member-password", {
            body: { user_id: member!.id, new_email: trimmedEmail },
          });
          let emailResult = emailData as { success?: boolean; error?: string } | null;
          if (emailErr) {
            try {
              emailResult = await (emailErr as unknown as { context: Response }).context.json();
            } catch {
              emailResult = { error: emailErr.message };
            }
          }
          if (!emailResult?.success) {
            // Don't claim the email changed when it didn't - surface the
            // real failure and stop short of showing it as updated.
            setError(
              `Profile saved, but the email update failed: ${emailResult?.error ?? "the reset-member-password Edge Function may not be deployed"}.`,
            );
            setIsSubmitting(false);
            onSaved();
            return;
          }
          setMemberEmail(trimmedEmail);
        } catch (err) {
          const msg = (err as { message?: string } | null)?.message;
          setError(`Profile saved, but the email update failed${msg ? `: ${msg}` : ""}. Please try again.`);
          setIsSubmitting(false);
          onSaved();
          return;
        }
      }

      if (photoFailed) {
        setError("Everything else was saved, but the photo upload failed. Try again to update just the photo.");
        setIsSubmitting(false);
        onSaved();
        return;
      }

      onSaved();
      onClose();
    } catch (err) {
      const msg = (err as { message?: string } | null)?.message;
      setError(msg ? `Could not save changes: ${msg}` : "Could not save changes. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Modal open={!!member} onClose={onClose} maxWidthClass="max-w-[520px]">
      <div className="flex items-center justify-between">
        <div className="text-[17px] font-bold">Edit Member</div>
        <button onClick={onClose} className="text-[13px] font-semibold text-muted-foreground">
          Close
        </button>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <Loader2 className="size-6 animate-spin text-brand" />
        </div>
      ) : (
        <>
          <div className="mt-4 flex justify-center">
            <label className="relative cursor-pointer">
              <div className="grid size-20 place-items-center overflow-hidden rounded-full border-2 border-brand/25 bg-brand/8">
                {photoPreview ? (
                  // eslint-disable-next-line @next/next/no-img-element -- blob: preview URL, next/image can't optimize it
                  <img src={photoPreview} alt="" className="size-full object-cover" />
                ) : existingPhotoUrl ? (
                  <Image src={existingPhotoUrl} alt="" width={80} height={80} className="size-full object-cover" />
                ) : (
                  <User className="size-8 text-brand" />
                )}
              </div>
              <span className="absolute bottom-0 right-0 grid size-[24px] place-items-center rounded-full border-2 border-card bg-brand">
                <Camera className="size-3 text-white" />
              </span>
              <input
                type="file"
                accept="image/*"
                className="hidden"
                onChange={handlePhotoChange}
                aria-label="Upload member photo"
              />
            </label>
          </div>
          <p className="mt-2 text-center text-[11.5px] text-muted-foreground">Tap to add a photo (optional)</p>

          <div className="mt-5 text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Personal Details
          </div>
          <div className="mt-2.5 grid grid-cols-1 gap-3.5 sm:grid-cols-2">
            <div className="sm:col-span-2">
              <Field label="Full Name" value={name} onChange={setName} />
            </div>
            <Field
              label="Phone Number"
              value={phone}
              onChange={(v) => setPhone(v.replace(/\D/g, "").slice(0, 10))}
              inputMode="numeric"
            />
            <Dropdown label="Gender" value={gender} onChange={setGender} options={["", ...GENDERS]} optionLabel={(g) => g || "-"} />
            <div className="sm:col-span-2">
              <Field label="Time Slot" value={timeSlot} onChange={setTimeSlot} hint="e.g. 6:00 AM - 8:00 AM" />
            </div>
            <div className="sm:col-span-2">
              <Field label="Login Email" value={email} onChange={setEmail} hint={memberEmail || "Not found"} />
            </div>
          </div>

          <div className="mt-5 text-[11px] font-semibold uppercase tracking-[0.14em] text-muted-foreground">
            Membership
          </div>
          <div className="mt-2.5 grid grid-cols-1 gap-3.5 sm:grid-cols-2">
            <div className="sm:col-span-2">
              <Dropdown
                label="Pass Type"
                value={passId}
                onChange={setPassId}
                options={["", ...passes.map((p) => p.id)]}
                optionLabel={(id) => {
                  if (!id) return "No pass";
                  const p = passes.find((x) => x.id === id)!;
                  return `${p.name}  ·  ${formatINR(p.price)}  ·  ${p.duration_days} days`;
                }}
              />
            </div>
            <Field label="Start Date" type="date" value={startDate} onChange={setStartDate} />
            <Field
              label="Extra Days"
              value={extraDays}
              onChange={(v) => setExtraDays(v.replace(/\D/g, ""))}
              inputMode="numeric"
            />
            <div className="sm:col-span-2">
              <InfoTile
                label="End Date"
                value={selectedPass && isValidYMD(startDate) ? prettyDate(endDate) : "-"}
                valueClass="text-brand"
              />
            </div>
          </div>

          <div className="mt-5 rounded-xl border border-brand/20 bg-brand/6 p-3.5">
            <div className="flex items-center gap-1.5 text-[10px] font-extrabold uppercase tracking-wide text-brand">
              <KeyRound className="size-3.5" />
              Login Credentials
            </div>
            {newPassword && (
              <div className="mt-3 flex items-center gap-3 rounded-lg border border-border/60 bg-background px-3 py-2.5">
                <div className="min-w-0 flex-1">
                  <div className="text-[9px] font-semibold uppercase tracking-wide text-muted-foreground">
                    New Password
                  </div>
                  <div className="mt-0.5 truncate text-[13px] font-semibold">{newPassword}</div>
                </div>
                <button
                  type="button"
                  onClick={() => navigator.clipboard.writeText(newPassword)}
                  className="shrink-0 text-muted-foreground"
                  aria-label="Copy new password"
                >
                  <Copy className="size-4" />
                </button>
              </div>
            )}
            <button
              type="button"
              onClick={handleResetPassword}
              disabled={isResetting}
              className="mt-3 flex w-full items-center justify-center gap-2 rounded-xl border border-energy/50 py-2.5 text-[13px] font-semibold text-energy disabled:opacity-50"
            >
              {isResetting ? <Loader2 className="size-4 animate-spin" /> : <KeyRound className="size-4" />}
              {isResetting ? "Resetting…" : "Reset Password & Show Credentials"}
            </button>
          </div>

          {error && <div className="mt-4 rounded-xl bg-danger/10 px-3.5 py-3 text-[13px] text-danger">{error}</div>}

          <button
            type="button"
            onClick={handleSave}
            disabled={isSubmitting}
            className="mt-5 w-full rounded-[14px] bg-brand py-3 text-[14px] font-bold text-on-brand disabled:opacity-50"
          >
            {isSubmitting ? "Saving…" : "Save Changes"}
          </button>
        </>
      )}
    </Modal>
  );
}

// Same label-above-input pattern as add-member-form.tsx's Field/Dropdown/
// InfoTile - kept local (rather than imported) so this modal doesn't couple
// to the Add Member form's internals, matching how every other modal in
// this codebase (pass-form-modal.tsx, DiscountModal) defines its own field
// helpers.
function Field({
  label,
  hint,
  value,
  onChange,
  inputMode,
  type,
}: {
  label: string;
  hint?: string;
  value: string;
  onChange: (v: string) => void;
  inputMode?: React.HTMLAttributes<HTMLInputElement>["inputMode"];
  type?: string;
}) {
  return (
    <label className="block">
      <div className="mb-1.5 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">{label}</div>
      <input
        type={type ?? "text"}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={hint}
        inputMode={inputMode}
        className="h-11 w-full rounded-xl border border-border bg-background px-3.5 text-[13.5px] font-medium outline-none focus:border-brand placeholder:font-normal placeholder:text-muted-foreground/60"
      />
    </label>
  );
}

function Dropdown<T extends string>({
  label,
  value,
  onChange,
  options,
  optionLabel,
}: {
  label: string;
  value: T;
  onChange: (v: T) => void;
  options: T[];
  optionLabel: (v: T) => string;
}) {
  return (
    <label className="block">
      <div className="mb-1.5 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">{label}</div>
      <div className="relative">
        <select
          value={value}
          onChange={(e) => onChange(e.target.value as T)}
          className="h-11 w-full appearance-none rounded-xl border border-border bg-background px-3.5 pr-9 text-[13.5px] font-medium outline-none focus:border-brand"
        >
          {options.map((o) => (
            <option key={o} value={o}>
              {optionLabel(o)}
            </option>
          ))}
        </select>
        <ChevronDown className="pointer-events-none absolute right-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
      </div>
    </label>
  );
}

function InfoTile({ label, value, valueClass }: { label: string; value: string; valueClass?: string }) {
  return (
    <div className="block">
      <div className="mb-1.5 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">{label}</div>
      <div className={`flex h-11 items-center rounded-xl border border-border bg-background px-3.5 text-[13.5px] font-bold ${valueClass ?? ""}`}>
        {value}
      </div>
    </div>
  );
}
