"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import {
  User,
  Camera,
  Check,
  AlertTriangle,
  Ban,
  Copy,
  Info,
  ChevronDown,
  Loader2,
  Plus,
  X,
  Pencil,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { formatINR } from "@/lib/format";
import { clampInstallments } from "@/lib/installments";
import { Modal } from "@/components/admin/modal";
import { logMemberEvent } from "@/lib/member-events";
import { MembersPickerPanel, type PickerMember } from "@/components/admin/members-picker-panel";
import { MemberDetailTables } from "@/components/admin/member-ledger";
import { buildLedgerRows } from "@/lib/member-ledger-rows";
import { EditMemberModal } from "@/components/admin/edit-member-modal";

type Pass = { id: string; name: string; price: number; duration_days: number };
type Profile = { id: string; full_name: string | null; phone: string | null };
type MemberSubscription = {
  id: string;
  start_date: string;
  end_date: string;
  status: string;
  created_at: string;
  discount_amount: number | null;
  pass_id: string | null;
  gym_passes: { name: string | null; price: number | null; duration_days: number | null } | null;
};
type MemberPayment = {
  amount: number;
  payment_method: string | null;
  payment_date: string;
  notes: string | null;
  subscription_id: string | null;
};
type InstallmentRow = { key: string; amount: string; date: string; method: string; notes: string };

type DialogState =
  | { kind: "error"; message: string }
  | {
    kind: "memberExists";
    profile: Profile;
    subs: MemberSubscription[];
    actionLabel: string;
    tone: "brand" | "sun" | "energy";
    message: string;
    suggestedStart: string | null;
  }
  | { kind: "blockedDuplicate"; memberName: string; passName: string; startDate: string }
  | { kind: "nearDuplicate"; memberName: string; passName: string; existingStart: string }
  | {
    kind: "success";
    name: string;
    email: string | null;
    password: string | null;
    endDate: string;
    total: number;
    paid: number;
    balance: number;
    existingAccount: boolean;
  };

const PAYMENT_METHODS = ["Cash", "UPI", "Card", "Bank Transfer", "Cheque"];
const GENDERS = ["Male", "Female", "Other"];
const MAX_PHOTO_BYTES = 5 * 1024 * 1024;

type FieldErrors = {
  name?: string;
  phone?: string;
  pass?: string;
  discount?: string;
  paidAmount?: string;
  photo?: string;
};

const TONE_CLASSES = {
  brand: { bg: "bg-brand/10", border: "border-brand/30", text: "text-brand" },
  sun: { bg: "bg-sun/12", border: "border-sun/30", text: "text-[#B8930A]" },
  energy: { bg: "bg-energy/10", border: "border-energy/30", text: "text-energy" },
} as const;

function isValidYMD(s: string) {
  return /^\d{4}-\d{2}-\d{2}$/.test(s);
}
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
  return parseYMD(s.slice(0, 10)).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
}
function seedInstallment(): InstallmentRow {
  return { key: `seed-${Date.now()}`, amount: "", date: toYMD(new Date()), method: "Cash", notes: "" };
}

export function AddMemberForm({
  passes,
  initialPhone,
  members,
}: {
  passes: Pass[];
  initialPhone?: string;
  members: PickerMember[];
}) {
  const router = useRouter();

  const [name, setName] = useState("");
  const [phone, setPhone] = useState(() => (initialPhone && /^\d{10}$/.test(initialPhone) ? initialPhone : ""));
  const [email, setEmail] = useState("");
  const [gender, setGender] = useState("");
  const [address, setAddress] = useState("");
  const [timeSlot, setTimeSlot] = useState("");

  // Live "does this member already exist" check, fired the moment the admin
  // leaves the phone field (or clicks them in the All Members panel) - lets
  // them see the member's full record and history before deciding what to do
  // next, instead of being surprised by a popup after filling the whole form.
  const [existingProfile, setExistingProfile] = useState<Profile | null>(null);
  const [existingCreatedAt, setExistingCreatedAt] = useState("");
  const [existingPhotoUrl, setExistingPhotoUrl] = useState<string | null>(null);
  const [existingSubs, setExistingSubs] = useState<MemberSubscription[]>([]);
  const [ledgerSubs, setLedgerSubs] = useState<MemberSubscription[]>([]);
  const [ledgerPayments, setLedgerPayments] = useState<MemberPayment[]>([]);
  const [checkedPhone, setCheckedPhone] = useState("");
  const [checkingPhone, setCheckingPhone] = useState(false);
  const [loadingMember, setLoadingMember] = useState(false);
  const [showNewMembership, setShowNewMembership] = useState(true);
  // Which subscription (if any) the admin is correcting via the "Current &
  // Past Memberships" list - opens the same scoped EditMemberModal used on
  // the Subscriptions page, so a bad historical record can be fixed right
  // where it's noticed.
  const [editingSubId, setEditingSubId] = useState<string | null>(null);

  // Snapshots of the loaded profile's fields, used only to detect what the
  // admin actually changed (for the member_events audit trail) - never
  // written to the DB directly.
  const [originalGender, setOriginalGender] = useState("");
  const [originalAddress, setOriginalAddress] = useState("");
  const [originalTimeSlot, setOriginalTimeSlot] = useState("");

  const [passId, setPassId] = useState("");
  const [startDate, setStartDate] = useState(toYMD(new Date()));
  const [extraDays, setExtraDays] = useState("");

  const [isPercent, setIsPercent] = useState(false);
  const [discount, setDiscount] = useState("");
  const [installments, setInstallments] = useState<InstallmentRow[]>([seedInstallment()]);

  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  const [dialog, setDialog] = useState<DialogState | null>(null);

  const isRenewing = existingProfile !== null && checkedPhone === phone.trim();
  const hasSelectableExistingSub = isRenewing && existingSubs.length > 0;
  // Adding a brand new membership vs. just recording a payment against the
  // member's existing subscription - the latter is only possible once we
  // know they have at least one non-cancelled subscription to target.
  const addingNewMembership = !hasSelectableExistingSub || showNewMembership;
  const targetExistingSub = hasSelectableExistingSub && !addingNewMembership ? existingSubs[0] : null;

  // If we arrived here with a phone number pre-filled (the "Add as New
  // Member" handoff from the Update Membership quick-check on Overview,
  // which already confirmed this number wasn't found), re-verify it once on
  // mount - cheap, and guards against the number having been registered by
  // someone else in the meantime.
  useEffect(() => {
    if (initialPhone && /^\d{10}$/.test(initialPhone)) {
      checkPhone();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- run once on mount only, using whatever initialPhone was passed at mount time
  }, []);

  const selectedPass = passes.find((p) => p.id === passId) ?? null;
  const extraDaysNum = parseInt(extraDays, 10) || 0;
  const endDate =
    selectedPass && isValidYMD(startDate) ? addDays(startDate, selectedPass.duration_days + extraDaysNum) : startDate;

  const passPrice = selectedPass?.price ?? 0;
  const discountVal = parseFloat(discount) || 0;
  // discountAmount is clamped to [0, passPrice] regardless of what discountVal
  // parses to, so it can never be written to the DB negative or above the
  // pass price even if the fieldErrors gate below is somehow skipped.
  // NOTE: this clamp is only enforced here in application code - there is no
  // DB-level CHECK constraint on subscriptions.discount_amount, so a client
  // calling the Supabase REST API directly (bypassing this component
  // entirely) could still write an out-of-range value.
  const discountAmount = isPercent
    ? Math.min(Math.max((passPrice * discountVal) / 100, 0), passPrice)
    : Math.min(Math.max(discountVal, 0), passPrice);

  // The price/balance basis switches depending on what's being paid for:
  // a brand new membership (price - discount, nothing paid yet) or an
  // installment against the member's already-existing subscription (that
  // subscription's own price/discount, minus whatever it's already collected).
  const effectivePriceBasis = addingNewMembership
    ? Math.max(passPrice - discountAmount, 0)
    : Math.max((targetExistingSub?.gym_passes?.price ?? 0) - (targetExistingSub?.discount_amount ?? 0), 0);
  const alreadyPaidBasis = addingNewMembership
    ? 0
    : ledgerPayments.filter((p) => p.subscription_id === targetExistingSub?.id).reduce((sum, p) => sum + (p.amount ?? 0), 0);
  const remainingBalance = Math.max(effectivePriceBasis - alreadyPaidBasis, 0);

  const parsedInstallments = installments.map((r) => ({ ...r, amountNum: parseFloat(r.amount) || 0 }));
  const rawInstallmentsTotal = parsedInstallments.reduce((sum, r) => sum + r.amountNum, 0);
  const safeInstallments = clampInstallments(parsedInstallments, remainingBalance);
  const newPaidTotal = safeInstallments.reduce((sum, r) => sum + r.safeAmount, 0);
  const finalBalance = Math.max(remainingBalance - newPaidTotal, 0);

  function addInstallmentRow() {
    setInstallments((rows) => [...rows, { key: `${Date.now()}-${rows.length}`, amount: "", date: toYMD(new Date()), method: "Cash", notes: "" }]);
  }
  function updateInstallment(key: string, patch: Partial<InstallmentRow>) {
    setInstallments((rows) => rows.map((r) => (r.key === key ? { ...r, ...patch } : r)));
  }
  function removeInstallment(key: string) {
    setInstallments((rows) => (rows.length > 1 ? rows.filter((r) => r.key !== key) : rows));
  }

  function resetForm() {
    setName("");
    setPhone("");
    setEmail("");
    setGender("");
    setAddress("");
    setTimeSlot("");
    clearExistingMemberState();
    setCheckedPhone("");
    setPassId("");
    setStartDate(toYMD(new Date()));
    setExtraDays("");
    setIsPercent(false);
    setDiscount("");
    setInstallments([seedInstallment()]);
    setPhotoFile(null);
    setPhotoPreview(null);
    setFieldErrors({});
  }

  // Clears everything derived from "this phone belongs to an existing
  // profile" - but deliberately leaves name/gender/address/time slot alone,
  // since the admin may already be typing those in for a genuinely new
  // member when this fires (e.g. editing the phone digit-by-digit).
  function clearExistingMemberState() {
    setExistingProfile(null);
    setExistingCreatedAt("");
    setExistingPhotoUrl(null);
    setExistingSubs([]);
    setLedgerSubs([]);
    setLedgerPayments([]);
    setOriginalGender("");
    setOriginalAddress("");
    setOriginalTimeSlot("");
    setShowNewMembership(true);
  }

  function handlePhotoChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith("image/") || file.size > MAX_PHOTO_BYTES) {
      setFieldErrors((prev) => ({ ...prev, photo: "Please choose an image under 5MB." }));
      e.target.value = "";
      return;
    }
    setFieldErrors((prev) => ({ ...prev, photo: undefined }));
    setPhotoFile(file);
    setPhotoPreview(URL.createObjectURL(file));
  }

  async function uploadPhotoIfAny(userId: string) {
    if (!photoFile) return null;
    const supabase = createClient();
    const ext = photoFile.name.includes(".") ? photoFile.name.split(".").pop()!.toLowerCase() : "jpg";
    const path = `${userId}/avatar.${ext}`;
    const { error } = await supabase.storage.from("member-photos").upload(path, photoFile, { upsert: true });
    if (error) return null;
    const { data } = supabase.storage.from("member-photos").getPublicUrl(path);
    return data.publicUrl;
  }

  function computeMemberExistsDialog(subs: MemberSubscription[]) {
    const now = new Date();
    let hasActive = false;
    let latestEnd: Date | null = null;
    for (const sub of subs) {
      if (sub.status === "active" && sub.end_date) {
        const end = parseYMD(sub.end_date.slice(0, 10));
        if (end > now) {
          hasActive = true;
          if (!latestEnd || end > latestEnd) latestEnd = end;
        }
      }
    }
    const daysLeft = latestEnd ? Math.floor((latestEnd.getTime() - now.getTime()) / 86_400_000) : 0;

    if (subs.length === 0) {
      return { actionLabel: "Add First Pass", tone: "brand" as const, message: "No membership history found. Add their first pass below.", suggestedStart: null };
    }
    if (!hasActive) {
      return { actionLabel: "Re-enroll", tone: "brand" as const, message: "All previous memberships have expired. Re-enroll them with a new pass.", suggestedStart: null };
    }
    if (daysLeft <= 7) {
      return {
        actionLabel: "Renew Now",
        tone: "brand" as const,
        message: `Active pass expires in ${daysLeft} day${daysLeft === 1 ? "" : "s"}. Renewal will start the day after.`,
        suggestedStart: toYMD(new Date(latestEnd!.getTime() + 86_400_000)),
      };
    }
    if (daysLeft <= 30) {
      return {
        actionLabel: "Schedule Renewal",
        tone: "sun" as const,
        message: `Active pass has ${daysLeft} days remaining. Schedule a renewal to start after it ends.`,
        suggestedStart: toYMD(new Date(latestEnd!.getTime() + 86_400_000)),
      };
    }
    return {
      actionLabel: "Add Anyway",
      tone: "energy" as const,
      message: `Active pass still has ${daysLeft} days remaining. Adding a new pass this early is unusual - confirm only if intentional.`,
      suggestedStart: null,
    };
  }

  async function fetchExistingByPhone(phoneVal: string) {
    const supabase = createClient();
    const { data } = await supabase.from("profiles").select("id, full_name, phone").eq("phone", phoneVal).limit(1);
    return (data?.[0] as Profile | undefined) ?? null;
  }

  async function fetchSubHistory(userId: string): Promise<MemberSubscription[]> {
    const supabase = createClient();
    const { data } = await supabase
      .from("subscriptions")
      .select("id, start_date, end_date, status, created_at, discount_amount, pass_id, gym_passes:pass_id ( name, price, duration_days )")
      .eq("user_id", userId)
      .neq("status", "cancelled")
      .order("created_at", { ascending: false })
      .limit(5)
      .returns<MemberSubscription[]>();
    return data ?? [];
  }

  // The member's whole lifetime record - every subscription (including
  // cancelled ones, unlike fetchSubHistory) and every payment, used to
  // render the same Debit/Credit/Balance ledger as the standalone member
  // page, and to work out how much is already paid on a given subscription.
  async function fetchLedgerData(userId: string) {
    const supabase = createClient();
    const [{ data: subs }, { data: pays }] = await Promise.all([
      supabase
        .from("subscriptions")
        .select("id, start_date, end_date, status, created_at, discount_amount, pass_id, gym_passes:pass_id ( name, price, duration_days )")
        .eq("user_id", userId)
        .order("created_at", { ascending: true })
        .returns<MemberSubscription[]>(),
      supabase
        .from("payments")
        .select("amount, payment_method, payment_date, notes, subscription_id")
        .eq("user_id", userId)
        .order("payment_date", { ascending: true })
        .returns<MemberPayment[]>(),
    ]);
    return { subs: subs ?? [], payments: pays ?? [] };
  }

  // Syncs all "who is this member" state (profile fields, photo, membership
  // history, ledger) from the DB. Deliberately does NOT touch the
  // membership/payment section (pass, dates, discount, installments) -
  // callers that want a full fresh start layer that reset on top.
  async function loadMemberIdentity(basic: Profile) {
    setLoadingMember(true);
    try {
      const supabase = createClient();
      const [{ data: full }, subHistory, ledgerData] = await Promise.all([
        supabase.from("profiles").select("full_name, phone, gender, address, time_slot, photo_url, created_at").eq("id", basic.id).maybeSingle(),
        fetchSubHistory(basic.id),
        fetchLedgerData(basic.id),
      ]);
      setExistingProfile(basic);
      setCheckedPhone(basic.phone ?? "");
      setExistingCreatedAt(full?.created_at ?? "");
      setExistingSubs(subHistory);
      setLedgerSubs(ledgerData.subs);
      setLedgerPayments(ledgerData.payments);
      if (full?.full_name) setName(full.full_name);
      setGender(full?.gender ?? "");
      setOriginalGender(full?.gender ?? "");
      setAddress(full?.address ?? "");
      setOriginalAddress(full?.address ?? "");
      setTimeSlot(full?.time_slot ?? "");
      setOriginalTimeSlot(full?.time_slot ?? "");
      setExistingPhotoUrl(full?.photo_url ?? null);
      setShowNewMembership(subHistory.length === 0 ? true : computeMemberExistsDialog(subHistory).actionLabel !== "Add Anyway");
    } finally {
      setLoadingMember(false);
    }
  }

  // The All Members panel's onSelect - a deliberate "switch to this member"
  // action, so unlike loadMemberIdentity alone, this also resets whatever
  // pass/discount/installments were mid-entry for a different member.
  async function selectMember(basic: Profile) {
    setPhone(basic.phone ?? phone);
    await loadMemberIdentity(basic);
    setPassId("");
    setStartDate(toYMD(new Date()));
    setExtraDays("");
    setIsPercent(false);
    setDiscount("");
    setPhotoFile(null);
    setPhotoPreview(null);
    setInstallments([seedInstallment()]);
    setFieldErrors({});
  }

  // Fires on blur of the phone field (not on every keystroke - a plain
  // lookup-on-leave is simplest and matches how most billing/CRM tools do
  // this, e.g. Stripe Checkout / Shopify recognizing a returning customer's
  // email as soon as they tab away from it).
  async function checkPhone() {
    const trimmed = phone.trim();
    if (!/^\d{10}$/.test(trimmed)) {
      clearExistingMemberState();
      return;
    }
    setCheckingPhone(true);
    try {
      const found = await fetchExistingByPhone(trimmed);
      if (found) {
        await loadMemberIdentity(found);
      } else {
        clearExistingMemberState();
        setCheckedPhone(trimmed);
      }
    } finally {
      setCheckingPhone(false);
    }
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();

    const errors: FieldErrors = {};
    if (!name.trim()) errors.name = "Name is required.";
    if (!/^\d{10}$/.test(phone.trim())) errors.phone = "Enter a valid 10-digit phone number.";
    if (addingNewMembership) {
      if (!selectedPass) errors.pass = "Please select a pass type.";
      if (isPercent && discountVal > 100) errors.discount = "Discount percentage cannot exceed 100%.";
      else if (!isPercent && discountVal > passPrice)
        errors.discount = `Discount cannot exceed pass price (${formatINR(passPrice)}).`;
    } else if (!targetExistingSub) {
      errors.pass = "This member has no membership to record a payment against - add a new membership instead.";
    }
    if (rawInstallmentsTotal > remainingBalance) {
      errors.paidAmount = `Amount paid (${formatINR(rawInstallmentsTotal)}) exceeds the remaining balance (${formatINR(remainingBalance)}).`;
    }
    setFieldErrors((prev) => ({ photo: prev.photo, ...errors }));
    if (Object.keys(errors).length > 0) return;

    setIsSubmitting(true);
    try {
      // If the live phone-blur check (or the All Members panel) already
      // found this exact member, proceed straight to the right action
      // instead of interrupting with a popup that would just repeat what
      // the admin already sees on screen.
      if (isRenewing && existingProfile) {
        if (addingNewMembership) {
          await handleAddSubscriptionToExisting(existingProfile);
        } else if (targetExistingSub) {
          await recordInstallmentsOnly(existingProfile, targetExistingSub);
        }
        return;
      }

      // Fallback safety net for the rare case the live check never ran
      // (e.g. the phone field was never blurred before submitting) - same
      // behavior as before, so an existing member still can't silently end
      // up with a duplicate account.
      const existing = await fetchExistingByPhone(phone.trim());
      if (existing) {
        const subs = await fetchSubHistory(existing.id);
        setIsSubmitting(false);
        const computed = computeMemberExistsDialog(subs);
        setDialog({ kind: "memberExists", profile: existing, subs, ...computed });
        return;
      }
      await createNewMember();
    } catch {
      setIsSubmitting(false);
      setDialog({ kind: "error", message: "Could not complete the request. Please check your connection and try again." });
    }
  }

  async function createNewMember() {
    const supabase = createClient();
    try {
      const { data, error } = await supabase.functions.invoke("create-member", {
        body: {
          name: name.trim(),
          phone: phone.trim(),
          email: email.trim() || null,
          gender: gender || null,
          address: address.trim() || null,
          pass_id: selectedPass!.id,
          start_date: startDate,
        },
      });

      let result = data as { success?: boolean; user_id?: string; email?: string; temp_password?: string; end_date?: string; error?: string } | null;
      if (error) {
        try {
          result = await (error as { context: Response }).context.json();
        } catch {
          result = { error: error.message };
        }
      }

      if (!result || result.success !== true) {
        const msg = result?.error ?? "Unknown error occurred.";
        if (msg.toLowerCase().includes("already registered") || msg.toLowerCase().includes("already been registered")) {
          const existing = await fetchExistingByPhone(phone.trim());
          if (existing) {
            const subs = await fetchSubHistory(existing.id);
            const computed = computeMemberExistsDialog(subs);
            setDialog({ kind: "memberExists", profile: existing, subs, ...computed });
          } else {
            setDialog({ kind: "error", message: "This phone number is already registered. Please search for the member to add a pass." });
          }
        } else {
          setDialog({ kind: "error", message: `Error: ${msg}` });
        }
        return;
      }

      const userId = result.user_id!;

      const { data: latestSub } = await supabase
        .from("subscriptions")
        .select("id")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(1)
        .single();

      const subPatch: Record<string, unknown> = {};
      if (discountAmount > 0) subPatch.discount_amount = discountAmount;
      if (extraDaysNum > 0) subPatch.end_date = endDate;
      let patchFailed = false;
      if (Object.keys(subPatch).length > 0 && latestSub) {
        const { error: patchErr } = await supabase.from("subscriptions").update(subPatch).eq("id", latestSub.id);
        patchFailed = !!patchErr;
      }

      let paymentFailed = false;
      const paymentRows = safeInstallments
        .filter((r) => r.safeAmount > 0)
        .map((r, i) => ({
          subscription_id: latestSub?.id,
          user_id: userId,
          amount: r.safeAmount,
          payment_date: r.date,
          payment_method: r.method.toLowerCase(),
          notes: r.notes.trim() || (i === 0 ? "Initial payment at enrollment" : null),
        }));
      if (paymentRows.length > 0 && latestSub) {
        const { error: paymentErr } = await supabase.from("payments").insert(paymentRows);
        paymentFailed = !!paymentErr;
      }

      const photoUrl = await uploadPhotoIfAny(userId);
      const photoFailed = !!photoFile && !photoUrl;
      const profileUpdate: Record<string, unknown> = { needs_password_reset: true };
      if (timeSlot.trim()) profileUpdate.time_slot = timeSlot.trim();
      if (photoUrl) profileUpdate.photo_url = photoUrl;
      const { error: profileErr } = await supabase.from("profiles").update(profileUpdate).eq("id", userId);

      if (paymentFailed || profileErr || photoFailed || patchFailed) {
        // The member account itself was created successfully - don't lose
        // those credentials - but be explicit about what still needs manual
        // follow-up rather than silently showing a false success.
        const issues = [
          patchFailed && "applying the discount/extra-days adjustment failed - redo it manually from the Subscriptions page",
          paymentFailed && `recording the ${formatINR(newPaidTotal)} payment failed - add it manually from the Subscriptions page`,
          profileErr && "saving the time slot/forced-password-reset flag failed - edit the member to retry",
          !profileErr && photoFailed && "the photo upload failed - edit the member to retry",
        ].filter(Boolean);
        setDialog({
          kind: "error",
          message: `${name.trim()} was added, but ${issues.join("; and ")}. Login email: ${result.email ?? "-"}, temp password: ${result.temp_password ?? "-"}.`,
        });
        router.refresh();
        return;
      }

      setDialog({
        kind: "success",
        name: name.trim(),
        email: result.email ?? null,
        password: result.temp_password ?? null,
        endDate: result.end_date ?? endDate,
        total: effectivePriceBasis,
        paid: newPaidTotal,
        balance: finalBalance,
        existingAccount: false,
      });
      router.refresh();
    } catch {
      setDialog({ kind: "error", message: "Could not add the member. Please check your connection and try again." });
    } finally {
      setIsSubmitting(false);
    }
  }

  async function handleAddSubscriptionToExisting(profile: Profile) {
    const supabase = createClient();
    setIsSubmitting(true);
    try {
      const windowStart = addDays(startDate, -7);
      const windowEnd = addDays(startDate, 7);

      const { data: exact } = await supabase
        .from("subscriptions")
        .select("id")
        .eq("user_id", profile.id)
        .eq("pass_id", selectedPass!.id)
        .eq("start_date", startDate)
        .neq("status", "cancelled")
        .limit(1);

      if (exact && exact.length > 0) {
        setIsSubmitting(false);
        setDialog({
          kind: "blockedDuplicate",
          memberName: profile.full_name || name,
          passName: selectedPass!.name,
          startDate: prettyDate(startDate),
        });
        return;
      }

      const { data: near } = await supabase
        .from("subscriptions")
        .select("id, start_date")
        .eq("user_id", profile.id)
        .eq("pass_id", selectedPass!.id)
        .neq("status", "cancelled")
        .gte("start_date", windowStart)
        .lte("start_date", windowEnd)
        .limit(1);

      if (near && near.length > 0) {
        setIsSubmitting(false);
        setDialog({
          kind: "nearDuplicate",
          memberName: profile.full_name || name,
          passName: selectedPass!.name,
          existingStart: prettyDate(near[0].start_date),
        });
        return;
      }

      await doInsertSubscription(profile);
    } catch {
      setIsSubmitting(false);
      setDialog({ kind: "error", message: "Could not add the subscription. Please try again." });
    }
  }

  async function doInsertSubscription(profile: Profile) {
    const supabase = createClient();
    try {
      // discount_amount is already clamped to [0, passPrice] above - see the
      // NOTE at its computation. NOTE: only client-side validated; there is
      // no DB CHECK constraint backing this column.
      const { data: sub, error: subErr } = await supabase
        .from("subscriptions")
        .insert({
          user_id: profile.id,
          pass_id: selectedPass!.id,
          start_date: startDate,
          end_date: endDate,
          status: "active",
          discount_amount: discountAmount > 0 ? discountAmount : 0,
        })
        .select("id")
        .single();
      if (subErr || !sub) throw subErr;

      let paymentFailed = false;
      const paymentRows = safeInstallments
        .filter((r) => r.safeAmount > 0)
        .map((r, i) => ({
          subscription_id: sub.id,
          user_id: profile.id,
          amount: r.safeAmount,
          payment_date: r.date,
          payment_method: r.method.toLowerCase(),
          notes: r.notes.trim() || (i === 0 ? "Payment at re-enrollment" : null),
        }));
      if (paymentRows.length > 0) {
        const { error: paymentErr } = await supabase.from("payments").insert(paymentRows);
        paymentFailed = !!paymentErr;
      }

      const photoUrl = await uploadPhotoIfAny(profile.id);
      const photoFailed = !!photoFile && !photoUrl;
      // Only touch fields the admin actually filled in - conservative on
      // purpose, since this path can also be reached via the fallback
      // "member already exists" modal, where the form's fields may just be
      // whatever was typed before that surprise discovery rather than a
      // deliberate edit of the real record.
      const profileUpdate: Record<string, unknown> = {};
      if (gender) profileUpdate.gender = gender;
      if (address.trim()) profileUpdate.address = address.trim();
      if (timeSlot.trim()) profileUpdate.time_slot = timeSlot.trim();
      if (photoUrl) profileUpdate.photo_url = photoUrl;
      let profileFailed = false;
      if (Object.keys(profileUpdate).length > 0) {
        const { error: profileErr } = await supabase.from("profiles").update(profileUpdate).eq("id", profile.id);
        profileFailed = !!profileErr;
      }

      if (!profileFailed) {
        const changedFields: string[] = [];
        if ((gender || null) !== (originalGender || null)) changedFields.push("gender");
        if ((address.trim() || null) !== (originalAddress.trim() || null)) changedFields.push("address");
        if ((timeSlot.trim() || null) !== (originalTimeSlot.trim() || null)) changedFields.push("time slot");
        if (changedFields.length > 0) {
          await logMemberEvent(supabase, { userId: profile.id, eventType: "profile_edit", description: `Updated ${changedFields.join(", ")}` });
        }
        await logMemberEvent(supabase, {
          userId: profile.id,
          subscriptionId: sub.id,
          eventType: "subscription_edit",
          description: `Added new ${selectedPass!.name} membership (${prettyDate(startDate)} → ${prettyDate(endDate)})`,
        });
      }

      if (paymentFailed || profileFailed || photoFailed) {
        const issues = [
          paymentFailed && `recording the ${formatINR(newPaidTotal)} payment failed - add it manually from the Subscriptions page`,
          profileFailed && "saving the profile changes failed - edit the member to retry",
          !profileFailed && photoFailed && "the photo upload failed - edit the member to retry",
        ].filter(Boolean);
        setDialog({
          kind: "error",
          message: `The subscription was added, but ${issues.join("; and ")}.`,
        });
        router.refresh();
        return;
      }

      setDialog({
        kind: "success",
        name: profile.full_name || name,
        email: null,
        password: null,
        endDate,
        total: effectivePriceBasis,
        paid: newPaidTotal,
        balance: finalBalance,
        existingAccount: true,
      });
      router.refresh();
    } catch {
      setDialog({ kind: "error", message: "Could not add the subscription. Please try again." });
    } finally {
      setIsSubmitting(false);
    }
  }

  // The "no new pass, just paying down what they already owe" path - skips
  // the subscription insert entirely and records the installments straight
  // against their existing subscription, same clamp/validation as above.
  async function recordInstallmentsOnly(profile: Profile, sub: MemberSubscription) {
    const supabase = createClient();
    setIsSubmitting(true);
    try {
      const paymentRows = safeInstallments
        .filter((r) => r.safeAmount > 0)
        .map((r) => ({
          subscription_id: sub.id,
          user_id: profile.id,
          amount: r.safeAmount,
          payment_date: r.date,
          payment_method: r.method.toLowerCase(),
          notes: r.notes.trim() || null,
        }));
      let paymentFailed = false;
      if (paymentRows.length > 0) {
        const { error: paymentErr } = await supabase.from("payments").insert(paymentRows);
        paymentFailed = !!paymentErr;
      }

      const photoUrl = await uploadPhotoIfAny(profile.id);
      const photoFailed = !!photoFile && !photoUrl;
      const profileUpdate: Record<string, unknown> = {};
      if (gender) profileUpdate.gender = gender;
      if (address.trim()) profileUpdate.address = address.trim();
      if (timeSlot.trim()) profileUpdate.time_slot = timeSlot.trim();
      if (photoUrl) profileUpdate.photo_url = photoUrl;
      let profileFailed = false;
      if (Object.keys(profileUpdate).length > 0) {
        const { error: profileErr } = await supabase.from("profiles").update(profileUpdate).eq("id", profile.id);
        profileFailed = !!profileErr;
      }

      if (!profileFailed && paymentRows.length > 0) {
        await logMemberEvent(supabase, {
          userId: profile.id,
          subscriptionId: sub.id,
          eventType: "subscription_edit",
          description: `Recorded ${formatINR(newPaidTotal)} payment (${paymentRows.length} installment${paymentRows.length === 1 ? "" : "s"})`,
        });
      }

      if (paymentFailed || profileFailed || photoFailed) {
        const issues = [
          paymentFailed && `recording the ${formatINR(newPaidTotal)} payment failed - add it manually from the Subscriptions page`,
          profileFailed && "saving the profile changes failed - edit the member to retry",
          !profileFailed && photoFailed && "the photo upload failed - edit the member to retry",
        ].filter(Boolean);
        setDialog({ kind: "error", message: `Could not finish recording the payment: ${issues.join("; and ")}.` });
        router.refresh();
        return;
      }

      setDialog({
        kind: "success",
        name: profile.full_name || name,
        email: null,
        password: null,
        endDate: sub.end_date,
        total: effectivePriceBasis,
        paid: newPaidTotal,
        balance: finalBalance,
        existingAccount: true,
      });
      router.refresh();
    } catch {
      setDialog({ kind: "error", message: "Could not record the payment. Please try again." });
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <>
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-[1fr_380px]">
        <div className="flex flex-col gap-6">
          <form onSubmit={handleSubmit} className="rounded-[20px] border border-border bg-card p-6 shadow-sm sm:p-7">
            {initialPhone && /^\d{10}$/.test(initialPhone) && !isRenewing && (
              <div className="mb-5 flex items-center gap-3 rounded-xl border border-aqua/25 bg-aqua/6 px-3.5 py-3">
                <Info className="size-5 shrink-0 text-aqua" />
                <div className="text-[13px] text-foreground">
                  Continuing from Update Membership <span className="font-bold">{initialPhone}</span>{" "}
                  wasn&apos;t found, so fill in their details below to add them as a new member.
                </div>
              </div>
            )}
            <div className="flex justify-center">
              <label className="relative cursor-pointer">
                <div className="grid size-24 place-items-center overflow-hidden rounded-full border-2 border-brand/25 bg-brand/8">
                  {photoPreview ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={photoPreview} alt="" className="size-full object-cover" />
                  ) : existingPhotoUrl ? (
                    <Image src={existingPhotoUrl} alt="" width={96} height={96} className="size-full object-cover" />
                  ) : (
                    <User className="size-9 text-brand" />
                  )}
                </div>
                <span className="absolute bottom-0 right-0 grid size-7 place-items-center rounded-full border-2 border-card bg-brand">
                  <Camera className="size-3.5 text-white" />
                </span>
                <input type="file" accept="image/*" className="hidden" onChange={handlePhotoChange} />
              </label>
            </div>
            <p className="mt-2 text-center text-[11.5px] text-muted-foreground">Tap to add a photo (optional)</p>
            {fieldErrors.photo && (
              <p className="mt-1 text-center text-[11.5px] font-medium text-danger">{fieldErrors.photo}</p>
            )}

            <SectionLabel first>Personal Details</SectionLabel>
            <div className="grid grid-cols-1 gap-3.5 sm:grid-cols-2">
              <Field label="Full Name *" hint="e.g. Rahul Sharma" value={name} onChange={setName} error={fieldErrors.name} />
              <Field
                label="Phone Number *"
                hint="e.g. 9876543210"
                value={phone}
                onChange={(v) => {
                  setPhone(v.replace(/\D/g, "").slice(0, 10));
                  // The old lookup no longer matches once the number changes -
                  // clear the derived existing-member state immediately so a
                  // stale banner/history/ledger can't linger under a phone
                  // number that's since been edited.
                  setCheckedPhone("");
                  clearExistingMemberState();
                }}
                onBlur={checkPhone}
                inputMode="numeric"
                error={fieldErrors.phone}
              />
              <Field label="Email (optional)" hint="Leave blank to auto-generate" value={email} onChange={setEmail} />
              <Dropdown label="Gender (optional)" value={gender} onChange={setGender} options={["", ...GENDERS]} optionLabel={(g) => g || "Select"} />
              <div className="sm:col-span-2">
                <Field label="Time Slot (optional)" hint="e.g. 6:00 AM - 8:00 AM" value={timeSlot} onChange={setTimeSlot} />
              </div>
              <div className="sm:col-span-2">
                <Field label="Address (optional)" hint="e.g. 12 MG Road, Pune" value={address} onChange={setAddress} />
              </div>
            </div>

            {(checkingPhone || loadingMember) && (
              <div className="mt-3 flex items-center gap-2 text-[12.5px] text-muted-foreground">
                <Loader2 className="size-3.5 animate-spin" />
                {loadingMember ? "Loading member record..." : "Checking phone number..."}
              </div>
            )}

            {existingProfile && checkedPhone === phone.trim() && !loadingMember && (
              <div className="mt-3 flex items-center gap-3 rounded-xl border border-brand/25 bg-brand/6 px-3.5 py-3">
                <div className="grid size-9 shrink-0 place-items-center rounded-full bg-brand/15 font-display text-[12px] font-bold text-brand">
                  {(existingProfile.full_name || name)
                    .trim()
                    .split(/\s+/)
                    .filter(Boolean)
                    .slice(0, 2)
                    .map((w) => w[0]?.toUpperCase())
                    .join("")}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[13.5px] font-bold">
                    Existing member: {existingProfile.full_name || "Unnamed"}
                  </div>
                  <div className="text-[12px] text-muted-foreground">
                    {computeMemberExistsDialog(existingSubs).message}
                  </div>
                </div>
              </div>
            )}

            <SectionLabel>Membership</SectionLabel>
            {hasSelectableExistingSub && (
              <div className="mb-3.5 flex flex-col gap-2">
                <div className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
                  Current &amp; Past Memberships
                </div>
                <div className="flex flex-col gap-1.5">
                  {existingSubs.map((s) => (
                    <SubHistoryRowView key={s.id} sub={s} onClick={() => setEditingSubId(s.id)} />
                  ))}
                </div>
                <button
                  type="button"
                  onClick={() => setShowNewMembership((v) => !v)}
                  className="mt-1 flex items-center justify-center gap-1.5 rounded-xl border border-dashed border-brand/40 py-2.5 text-[12.5px] font-bold text-brand"
                >
                  {showNewMembership ? "− Hide New Membership" : "+ Add New Membership"}
                </button>
              </div>
            )}
            {addingNewMembership ? (
              <div className="flex flex-col gap-3.5">
                <Dropdown
                  label="Pass Type *"
                  value={passId}
                  onChange={setPassId}
                  options={["", ...passes.map((p) => p.id)]}
                  optionLabel={(id) => {
                    if (!id) return "Select a pass";
                    const p = passes.find((x) => x.id === id)!;
                    return `${p.name}  ·  ${formatINR(p.price)}  ·  ${p.duration_days} days`;
                  }}
                  error={fieldErrors.pass}
                />
                <div className="grid grid-cols-1 gap-3.5 sm:grid-cols-3">
                  <Field label="Start Date *" type="date" value={startDate} onChange={setStartDate} />
                  <Field
                    label="Extra Days (optional)"
                    hint="e.g. 5"
                    value={extraDays}
                    onChange={(v) => setExtraDays(v.replace(/\D/g, ""))}
                    inputMode="numeric"
                  />
                  <InfoTile
                    label={extraDaysNum > 0 ? `End Date (+${extraDaysNum}d)` : "End Date (auto)"}
                    value={selectedPass && isValidYMD(startDate) ? prettyDate(endDate) : "-"}
                    valueClass="text-brand"
                  />
                </div>
              </div>
            ) : (
              targetExistingSub && (
                <div className="rounded-xl border border-border bg-background p-3.5 text-[13px] leading-relaxed">
                  Recording a payment against their current{" "}
                  <span className="font-bold text-brand">{targetExistingSub.gym_passes?.name ?? "membership"}</span>{" "}
                  ({prettyDate(targetExistingSub.start_date)} → {prettyDate(targetExistingSub.end_date)}).
                </div>
              )
            )}

            <SectionLabel>Payment Details</SectionLabel>
            <div className="flex flex-col gap-3.5">
              {addingNewMembership && (
                <>
                  <div className="grid grid-cols-1 gap-3.5 sm:grid-cols-2">
                    <Segmented label="Discount Type" value={isPercent} onChange={setIsPercent} options={["₹ Amount", "% Percent"]} />
                    <Field
                      label={isPercent ? "Discount %" : "Discount Amount (₹)"}
                      hint={isPercent ? "e.g. 10" : "e.g. 200"}
                      value={discount}
                      onChange={(v) => setDiscount(v.replace(/[^\d.]/g, ""))}
                      inputMode="decimal"
                      error={fieldErrors.discount}
                    />
                  </div>

                  {selectedPass && (
                    <div className="flex justify-around rounded-xl border border-border bg-background p-3.5">
                      <PriceStat label="ORIGINAL" value={formatINR(passPrice)} />
                      <PriceStat label="DISCOUNT" value={`-${formatINR(discountAmount)}`} className="text-energy" />
                      <PriceStat label="FINAL PRICE" value={formatINR(effectivePriceBasis)} bold />
                    </div>
                  )}
                </>
              )}

              <div className="flex flex-col gap-2.5">
                <div className="flex items-center justify-between">
                  <div className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">Installments</div>
                  <button type="button" onClick={addInstallmentRow} className="flex items-center gap-1 text-[12px] font-bold text-brand">
                    <Plus className="size-3.5" />
                    Add Installment
                  </button>
                </div>
                {installments.map((row, idx) => (
                  <div key={row.key} className="grid grid-cols-2 gap-2.5 rounded-xl border border-border bg-background p-3 sm:grid-cols-[1fr_1fr_1fr_1fr_auto] sm:items-end">
                    <Field
                      label={idx === 0 ? "Amount Paid Now (₹)" : `Installment ${idx + 1} (₹)`}
                      hint="e.g. 500"
                      value={row.amount}
                      onChange={(v) => updateInstallment(row.key, { amount: v.replace(/[^\d.]/g, "") })}
                      inputMode="decimal"
                    />
                    <Field label="Date" type="date" value={row.date} onChange={(v) => updateInstallment(row.key, { date: v })} max={toYMD(new Date())} />
                    <Dropdown label="Method" value={row.method} onChange={(v) => updateInstallment(row.key, { method: v })} options={PAYMENT_METHODS} optionLabel={(m) => m} />
                    <Field label="Note (optional)" hint="e.g. Paid by father" value={row.notes} onChange={(v) => updateInstallment(row.key, { notes: v })} />
                    {installments.length > 1 && (
                      <button
                        type="button"
                        onClick={() => removeInstallment(row.key)}
                        aria-label="Remove installment"
                        className="flex h-11 items-center justify-center rounded-xl border border-border text-muted-foreground hover:border-danger hover:text-danger"
                      >
                        <X className="size-4" />
                      </button>
                    )}
                  </div>
                ))}
                {fieldErrors.paidAmount && <div className="text-[11.5px] font-medium text-danger">{fieldErrors.paidAmount}</div>}
              </div>

              {(addingNewMembership ? selectedPass : targetExistingSub) && (
                <div className="flex flex-wrap justify-around gap-y-2 rounded-xl border border-brand/20 bg-brand/6 p-3.5">
                  <PriceStat label="TOTAL" value={formatINR(effectivePriceBasis)} />
                  {alreadyPaidBasis > 0 && <PriceStat label="ALREADY PAID" value={formatINR(alreadyPaidBasis)} />}
                  <PriceStat label="PAID NOW" value={formatINR(rawInstallmentsTotal)} className="text-brand" />
                  <PriceStat
                    label="BALANCE"
                    value={formatINR(Math.max(remainingBalance - rawInstallmentsTotal, 0))}
                    className={remainingBalance - rawInstallmentsTotal > 0 ? "text-energy" : "text-brand"}
                    bold
                  />
                </div>
              )}
            </div>

            <button
              type="submit"
              disabled={isSubmitting}
              className="btn-shine mt-7 flex w-full items-center justify-center gap-2 rounded-[14px] bg-brand py-3.5 text-[15px] font-bold text-on-brand disabled:opacity-50"
            >
              {!isSubmitting && <Check className="size-4" />}
              {isRenewing
                ? isSubmitting
                  ? addingNewMembership
                    ? "Renewing…"
                    : "Recording…"
                  : addingNewMembership
                    ? "Renew Membership"
                    : "Record Payment"
                : isSubmitting
                  ? "Adding…"
                  : "Add Member"}
            </button>
          </form>

          {isRenewing && (
            <div>
              <h2 className="mb-2.5 font-display text-[16px] font-bold">Payment History</h2>
              {ledgerSubs.length === 0 && ledgerPayments.length === 0 ? (
                <div className="rounded-[20px] border border-border bg-card px-6 py-10 text-center text-[13px] text-muted-foreground">
                  No activity recorded for this member yet.
                </div>
              ) : (
                <MemberDetailTables
                  rows={buildLedgerRows(ledgerSubs, ledgerPayments)}
                  openingDate={existingCreatedAt || toYMD(new Date())}
                />
              )}
            </div>
          )}
        </div>

        <MembersPickerPanel
          members={members}
          selectedId={existingProfile?.id ?? null}
          onSelect={(m) => selectMember({ id: m.id, full_name: m.full_name, phone: m.phone })}
        />
      </div>

      {/* Error dialog */}
      <Modal open={dialog?.kind === "error"} onClose={() => setDialog(null)}>
        {dialog?.kind === "error" && (
          <>
            <DialogHeader icon={AlertTriangle} tone="energy" title="Something Went Wrong" />
            <p className="mt-3 text-[14px] leading-relaxed text-muted-foreground">{dialog.message}</p>
            <button onClick={() => setDialog(null)} className="mt-5 w-full rounded-xl bg-brand py-2.5 text-[14px] font-bold text-on-brand">
              OK
            </button>
          </>
        )}
      </Modal>

      {/* Blocked duplicate */}
      <Modal open={dialog?.kind === "blockedDuplicate"} onClose={() => setDialog(null)}>
        {dialog?.kind === "blockedDuplicate" && (
          <>
            <DialogHeader icon={Ban} tone="energy" title="Duplicate Entry Blocked" />
            <p className="mt-3 text-[14px] leading-relaxed text-muted-foreground">
              A {dialog.passName} starting on {dialog.startDate} already exists for {dialog.memberName}.
            </p>
            <div className="mt-3 rounded-xl bg-danger/8 px-3.5 py-3 text-[12px] leading-relaxed text-danger">
              If the discount or amount was wrong on the original entry, edit it from the Subscriptions screen instead of creating a new one.
            </div>
            <button onClick={() => setDialog(null)} className="mt-5 w-full rounded-xl bg-brand py-2.5 text-[14px] font-bold text-on-brand">
              OK
            </button>
          </>
        )}
      </Modal>

      {/* Near duplicate warning */}
      <Modal open={dialog?.kind === "nearDuplicate"} onClose={() => setDialog(null)}>
        {dialog?.kind === "nearDuplicate" && (
          <>
            <DialogHeader icon={AlertTriangle} tone="sun" title="Possible Duplicate" />
            <p className="mt-3 text-[14px] leading-relaxed text-muted-foreground">
              {dialog.memberName} already has a {dialog.passName} that started on {dialog.existingStart} - within 7
              days of the date you&apos;re entering.
            </p>
            <div className="mt-3 rounded-xl bg-sun/10 px-3.5 py-3 text-[12px] leading-relaxed text-[#B8930A]">
              Only proceed if this is a genuine separate enrollment, not a re-entry of the same membership.
            </div>
            <div className="mt-5 flex gap-2.5">
              <button onClick={() => setDialog(null)} className="flex-1 rounded-xl border border-border py-2.5 text-[14px] font-semibold text-muted-foreground">
                Cancel
              </button>
              <button
                onClick={async () => {
                  const existing = await fetchExistingByPhone(phone.trim());
                  setDialog(null);
                  if (existing) {
                    setIsSubmitting(true);
                    await doInsertSubscription(existing);
                  }
                }}
                className="flex-1 rounded-xl bg-sun py-2.5 text-[14px] font-bold text-[#0F0F0F]"
              >
                Add Anyway
              </button>
            </div>
          </>
        )}
      </Modal>

      {/* Member exists */}
      <Modal open={dialog?.kind === "memberExists"} onClose={() => setDialog(null)}>
        {dialog?.kind === "memberExists" && (
          <>
            <div className="flex items-center gap-3">
              <div className="grid size-11 shrink-0 place-items-center rounded-full bg-brand/15 font-display text-[15px] font-bold text-brand">
                {(dialog.profile.full_name || name)
                  .trim()
                  .split(/\s+/)
                  .filter(Boolean)
                  .slice(0, 2)
                  .map((w) => w[0]?.toUpperCase())
                  .join("")}
              </div>
              <div className="min-w-0 flex-1">
                <div className="truncate text-[16px] font-bold">{dialog.profile.full_name || name}</div>
                <div className="text-[13px] text-muted-foreground">{dialog.profile.phone || phone}</div>
              </div>
              <span className="shrink-0 rounded-full bg-brand/12 px-2.5 py-1 text-[11px] font-semibold text-brand">
                Existing
              </span>
            </div>

            {dialog.subs.length > 0 && (
              <>
                <div className="mt-4 text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
                  Subscription History
                </div>
                <div className="mt-2 flex max-h-[190px] flex-col gap-1.5 overflow-y-auto">
                  {dialog.subs.map((s) => (
                    <SubHistoryRowView key={s.id} sub={s} />
                  ))}
                </div>
              </>
            )}

            <div className={`mt-3.5 rounded-[10px] border px-3 py-2.5 text-[13px] leading-relaxed ${TONE_CLASSES[dialog.tone].bg} ${TONE_CLASSES[dialog.tone].border} ${TONE_CLASSES[dialog.tone].text}`}>
              {dialog.message}
            </div>

            <div className="mt-4 flex gap-2.5">
              <button onClick={() => setDialog(null)} className="flex-1 rounded-xl border border-border py-2.5 text-[14px] font-semibold text-muted-foreground">
                Cancel
              </button>
              <button
                onClick={async () => {
                  const profile = dialog.profile;
                  const suggested = dialog.suggestedStart;
                  setDialog(null);
                  // Sync the real record (name/gender/address/history/ledger)
                  // before writing to it - the form's fields up to this point
                  // may just be whatever was typed before this surprise
                  // "already exists" discovery, not a deliberate edit.
                  await loadMemberIdentity(profile);
                  if (suggested) setStartDate(suggested);
                  handleAddSubscriptionToExisting(profile);
                }}
                className={`flex-1 rounded-xl py-2.5 text-[14px] font-bold text-[#0F0F0F] ${dialog.tone === "brand" ? "bg-brand text-white" : dialog.tone === "sun" ? "bg-sun" : "bg-energy text-white"
                  }`}
              >
                {dialog.actionLabel}
              </button>
            </div>
          </>
        )}
      </Modal>

      {/* Success */}
      <Modal open={dialog?.kind === "success"} onClose={() => { }} dismissible={false}>
        {dialog?.kind === "success" && (
          <>
            <DialogHeader icon={Check} tone="brand" title={dialog.existingAccount ? "Subscription Added!" : "Member Added!"} />
            <p className="mt-3 text-[14px] text-foreground">
              {dialog.existingAccount
                ? `A new subscription has been added for ${dialog.name}.`
                : `${dialog.name} has been added successfully.`}
            </p>

            <div className="mt-4 flex justify-around rounded-xl bg-background p-3">
              <PriceStat label="TOTAL" value={formatINR(dialog.total)} />
              <PriceStat label="PAID" value={formatINR(dialog.paid)} className="text-brand" />
              <PriceStat label="BALANCE" value={formatINR(dialog.balance)} className={dialog.balance > 0 ? "text-energy" : "text-brand"} bold />
            </div>

            <div className="mt-4 flex flex-col gap-2.5">
              {!dialog.existingAccount && dialog.email && (
                <CredentialTile label="Login Email" value={dialog.email} />
              )}
              {!dialog.existingAccount && dialog.password && (
                <CredentialTile label="Temp Password" value={dialog.password} />
              )}
              <CredentialTile label="Pass Expires" value={prettyDate(dialog.endDate)} copyable={false} />
            </div>

            <div className="mt-4 flex items-start gap-2 rounded-xl border border-brand/20 bg-brand/8 px-3 py-2.5 text-[11px] leading-relaxed text-brand">
              <Info className="mt-0.5 size-3.5 shrink-0" />
              {dialog.existingAccount
                ? "Member logs in with their existing credentials."
                : "Share these credentials with the member. They can reset the password anytime."}
            </div>

            <div className="mt-5 flex gap-2.5">
              <button
                onClick={() => {
                  setDialog(null);
                  resetForm();
                }}
                className="flex-1 rounded-xl border border-border py-2.5 text-[14px] font-semibold text-muted-foreground"
              >
                Add Another
              </button>
              <button
                onClick={() => {
                  setDialog(null);
                  resetForm();
                }}
                className="flex-1 rounded-xl bg-brand py-2.5 text-[14px] font-bold text-on-brand"
              >
                Done
              </button>
            </div>
          </>
        )}
      </Modal>

      <EditMemberModal
        member={editingSubId && existingProfile ? existingProfile : null}
        passes={passes}
        targetSubscriptionId={editingSubId}
        onClose={() => setEditingSubId(null)}
        onSaved={async () => {
          if (existingProfile) await loadMemberIdentity(existingProfile);
          router.refresh();
        }}
      />
    </>
  );
}

function SectionLabel({ children, first }: { children: React.ReactNode; first?: boolean }) {
  return (
    <div className={`${first ? "mt-5" : "mt-7"} font-display text-[13px] font-bold uppercase tracking-[0.06em] text-brand`}>
      {children}
    </div>
  );
}

function Field({
  label,
  hint,
  value,
  onChange,
  onBlur,
  inputMode,
  type,
  max,
  error,
}: {
  label: string;
  hint?: string;
  value: string;
  onChange: (v: string) => void;
  onBlur?: () => void;
  inputMode?: React.HTMLAttributes<HTMLInputElement>["inputMode"];
  type?: string;
  max?: string;
  error?: string;
}) {
  return (
    <label className="block">
      <div className="mb-1.5 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">{label}</div>
      <input
        type={type ?? "text"}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onBlur={onBlur}
        placeholder={hint}
        inputMode={inputMode}
        max={max}
        aria-invalid={!!error}
        className={`h-11 w-full rounded-xl border bg-background px-3.5 text-[13.5px] font-medium outline-none placeholder:font-normal placeholder:text-muted-foreground/60 ${error ? "border-danger focus:border-danger" : "border-border focus:border-brand"
          }`}
      />
      {error && <div className="mt-1 text-[11.5px] font-medium text-danger">{error}</div>}
    </label>
  );
}

function Dropdown<T extends string>({
  label,
  value,
  onChange,
  options,
  optionLabel,
  error,
}: {
  label: string;
  value: T;
  onChange: (v: T) => void;
  options: T[];
  optionLabel: (v: T) => string;
  error?: string;
}) {
  return (
    <label className="block">
      <div className="mb-1.5 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">{label}</div>
      <div className="relative">
        <select
          value={value}
          onChange={(e) => onChange(e.target.value as T)}
          aria-invalid={!!error}
          className={`h-11 w-full appearance-none rounded-xl border bg-background px-3.5 pr-9 text-[13.5px] font-medium outline-none ${error ? "border-danger focus:border-danger" : "border-border focus:border-brand"
            }`}
        >
          {options.map((o) => (
            <option key={o} value={o}>
              {optionLabel(o)}
            </option>
          ))}
        </select>
        <ChevronDown className="pointer-events-none absolute right-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
      </div>
      {error && <div className="mt-1 text-[11.5px] font-medium text-danger">{error}</div>}
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

function Segmented({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: boolean;
  onChange: (v: boolean) => void;
  options: [string, string];
}) {
  return (
    <div>
      <div className="mb-1.5 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">{label}</div>
      <div className="flex gap-2">
        <button
          type="button"
          onClick={() => onChange(false)}
          aria-pressed={!value}
          className={`flex-1 rounded-xl border py-2.5 text-[12.5px] font-bold ${!value ? "border-brand bg-brand text-on-brand" : "border-border text-muted-foreground"
            }`}
        >
          {options[0]}
        </button>
        <button
          type="button"
          onClick={() => onChange(true)}
          aria-pressed={value}
          className={`flex-1 rounded-xl border py-2.5 text-[12.5px] font-bold ${value ? "border-brand bg-brand text-on-brand" : "border-border text-muted-foreground"
            }`}
        >
          {options[1]}
        </button>
      </div>
    </div>
  );
}

function PriceStat({ label, value, className, bold }: { label: string; value: string; className?: string; bold?: boolean }) {
  return (
    <div className="text-center">
      <div className="text-[9px] font-semibold uppercase tracking-wide text-muted-foreground">{label}</div>
      <div className={`num mt-1 font-display text-[15px] ${bold ? "font-bold" : "font-semibold"} ${className ?? ""}`}>{value}</div>
    </div>
  );
}

function DialogHeader({ icon: Icon, tone, title }: { icon: React.ComponentType<{ className?: string }>; tone: "brand" | "sun" | "energy"; title: string }) {
  return (
    <div className="flex items-center gap-3">
      <span className={`grid size-9 shrink-0 place-items-center rounded-full ${TONE_CLASSES[tone].bg}`}>
        <Icon className={`size-[18px] ${TONE_CLASSES[tone].text}`} />
      </span>
      <div className="text-[17px] font-bold">{title}</div>
    </div>
  );
}

// `onClick` is only passed where the caller already knows exactly which
// subscription this is (e.g. the currently-loaded member's own history) -
// the memberExists dialog's read-only preview of a phone-matched stranger's
// history renders this without it, staying a plain non-interactive row.
function SubHistoryRowView({ sub, onClick }: { sub: MemberSubscription; onClick?: () => void }) {
  const now = new Date();
  let badgeClass = "bg-muted text-muted-foreground";
  let badgeLabel = sub.status || "Unknown";

  if (sub.end_date) {
    const end = parseYMD(sub.end_date.slice(0, 10));
    if (sub.status === "active" && end > now) {
      const days = Math.floor((end.getTime() - now.getTime()) / 86_400_000);
      if (days <= 7) {
        badgeClass = "bg-energy/15 text-energy";
        badgeLabel = `${days}d left`;
      } else {
        badgeClass = "bg-brand/15 text-brand";
        badgeLabel = "Active";
      }
    } else {
      badgeClass = "bg-muted text-muted-foreground";
      badgeLabel = "Expired";
    }
  }

  const inner = (
    <>
      <div className="min-w-0">
        <div className="truncate text-[13px] font-semibold">{sub.gym_passes?.name ?? "Pass"}</div>
        <div className="text-[12px] text-muted-foreground">
          {sub.start_date ? prettyDate(sub.start_date) : "–"} → {sub.end_date ? prettyDate(sub.end_date) : "–"}
        </div>
      </div>
      <div className="flex shrink-0 items-center gap-2">
        <span className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${badgeClass}`}>{badgeLabel}</span>
        {onClick && <Pencil className="size-3.5 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />}
      </div>
    </>
  );

  if (onClick) {
    return (
      <button
        type="button"
        onClick={onClick}
        className="group flex w-full items-center justify-between rounded-lg bg-foreground/[0.04] px-3 py-2.5 text-left transition-colors hover:bg-foreground/[0.08]"
      >
        {inner}
      </button>
    );
  }

  return <div className="flex items-center justify-between rounded-lg bg-foreground/[0.04] px-3 py-2.5">{inner}</div>;
}

function CredentialTile({ label, value, copyable = true }: { label: string; value: string; copyable?: boolean }) {
  return (
    <div className="flex items-center gap-3 rounded-xl border border-border/60 bg-background px-3 py-2.5">
      <div className="min-w-0 flex-1">
        <div className="text-[9px] font-semibold uppercase tracking-wide text-muted-foreground">{label}</div>
        <div className="mt-0.5 truncate text-[13px] font-semibold">{value}</div>
      </div>
      {copyable && (
        <button
          type="button"
          onClick={() => navigator.clipboard.writeText(value)}
          className="shrink-0 text-muted-foreground"
          aria-label={`Copy ${label}`}
        >
          <Copy className="size-4" />
        </button>
      )}
    </div>
  );
}
