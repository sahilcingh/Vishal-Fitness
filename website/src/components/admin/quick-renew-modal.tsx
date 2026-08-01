"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2, Check, ArrowRight, UserX, ChevronDown } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { formatINR } from "@/lib/format";
import { Modal } from "@/components/admin/modal";

type Pass = { id: string; name: string; price: number; duration_days: number };
type Profile = { id: string; full_name: string | null; phone: string | null };
type SubHistoryRow = {
  id: string;
  start_date: string;
  end_date: string | null;
  status: string;
  pass: { name: string | null } | null;
};

const PAYMENT_METHODS = ["Cash", "UPI", "Card", "Bank Transfer", "Cheque"];

function toYMD(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
function parseYMD(s: string) {
  const [y, m, d] = s.split("-").map(Number);
  return new Date(y, m - 1, d);
}
function isValidYMD(s: string) {
  return /^\d{4}-\d{2}-\d{2}$/.test(s);
}
function addDays(s: string, days: number) {
  const d = parseYMD(s);
  d.setDate(d.getDate() + days);
  return toYMD(d);
}
function prettyDate(s: string) {
  return parseYMD(s).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
}

// Same message logic as AddMemberForm's computeMemberExistsDialog, minus the
// actionLabel/tone - the action here is always "Update Membership", so only
// the descriptive status line is needed.
function statusMessage(subs: SubHistoryRow[]): string {
  const now = new Date();
  let hasActive = false;
  let latestEnd: Date | null = null;
  for (const sub of subs) {
    if (sub.status === "active" && sub.end_date) {
      const end = parseYMD(sub.end_date);
      if (end > now) {
        hasActive = true;
        if (!latestEnd || end > latestEnd) latestEnd = end;
      }
    }
  }
  const daysLeft = latestEnd ? Math.floor((latestEnd.getTime() - now.getTime()) / 86_400_000) : 0;

  if (subs.length === 0) return "No membership history found - add their first pass below.";
  if (!hasActive) return "All previous memberships have expired - re-enroll them below.";
  if (daysLeft <= 7) return `Active pass expires in ${daysLeft} day${daysLeft === 1 ? "" : "s"}.`;
  if (daysLeft <= 30) return `Active pass has ${daysLeft} days remaining.`;
  return `Active pass still has ${daysLeft} days remaining - adding a new pass this early is unusual.`;
}

export function QuickRenewModal({ open, onClose, passes }: { open: boolean; onClose: () => void; passes: Pass[] }) {
  const router = useRouter();

  const [phone, setPhone] = useState("");
  const [checkingPhone, setCheckingPhone] = useState(false);
  const [hasChecked, setHasChecked] = useState(false);
  const [checkedPhone, setCheckedPhone] = useState("");
  const [existingProfile, setExistingProfile] = useState<Profile | null>(null);
  const [existingSubs, setExistingSubs] = useState<SubHistoryRow[]>([]);

  const [passId, setPassId] = useState("");
  const [startDate, setStartDate] = useState(toYMD(new Date()));
  const [extraDays, setExtraDays] = useState("");
  const [isPercent, setIsPercent] = useState(false);
  const [discount, setDiscount] = useState("");
  const [paidAmount, setPaidAmount] = useState("");
  const [paymentDate, setPaymentDate] = useState(toYMD(new Date()));
  const [paymentMethod, setPaymentMethod] = useState("Cash");
  const [notes, setNotes] = useState("");

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<{ name: string } | null>(null);

  function resetAll() {
    setPhone("");
    setCheckingPhone(false);
    setHasChecked(false);
    setCheckedPhone("");
    setExistingProfile(null);
    setExistingSubs([]);
    setPassId("");
    setStartDate(toYMD(new Date()));
    setExtraDays("");
    setIsPercent(false);
    setDiscount("");
    setPaidAmount("");
    setPaymentDate(toYMD(new Date()));
    setPaymentMethod("Cash");
    setNotes("");
    setError(null);
    setSuccess(null);
  }

  function handleClose() {
    resetAll();
    onClose();
  }

  async function checkPhone() {
    const trimmed = phone.trim();
    if (!/^\d{10}$/.test(trimmed)) return;
    // Already checked this exact number - skip re-querying. Without this
    // guard, clicking "Add as New Member" blurs the phone input, which
    // re-triggers this function; the resulting setCheckingPhone(true)
    // re-render removes the not-found block (and the button being clicked)
    // from the DOM between mousedown and click, so the click never lands.
    if (trimmed === checkedPhone && hasChecked) return;
    setCheckingPhone(true);
    setError(null);
    const supabase = createClient();
    try {
      const { data } = await supabase.from("profiles").select("id, full_name, phone").eq("phone", trimmed).limit(1);
      const found = (data?.[0] as Profile | undefined) ?? null;
      setExistingProfile(found);
      if (found) {
        const { data: subs } = await supabase
          .from("subscriptions")
          .select("id, start_date, end_date, status, pass:gym_passes(name)")
          .eq("user_id", found.id)
          .neq("status", "cancelled")
          .order("created_at", { ascending: false })
          .limit(5)
          .returns<SubHistoryRow[]>();
        setExistingSubs(subs ?? []);
      } else {
        setExistingSubs([]);
      }
    } finally {
      setHasChecked(true);
      setCheckedPhone(trimmed);
      setCheckingPhone(false);
    }
  }

  const selectedPass = passes.find((p) => p.id === passId) ?? null;
  const extraDaysNum = parseInt(extraDays, 10) || 0;
  const endDate =
    selectedPass && isValidYMD(startDate) ? addDays(startDate, selectedPass.duration_days + extraDaysNum) : startDate;
  const passPrice = selectedPass?.price ?? 0;
  const discountVal = parseFloat(discount) || 0;
  const discountAmount = isPercent
    ? Math.min(Math.max((passPrice * discountVal) / 100, 0), passPrice)
    : Math.min(Math.max(discountVal, 0), passPrice);
  const effectivePrice = Math.max(passPrice - discountAmount, 0);
  const paidAmountNum = parseFloat(paidAmount) || 0;
  const safePaidAmount = Math.min(Math.max(paidAmountNum, 0), effectivePrice);
  const balance = Math.max(effectivePrice - paidAmountNum, 0);

  async function handleUpdateMembership() {
    if (!existingProfile) return;
    if (!selectedPass) {
      setError("Please select a pass type.");
      return;
    }
    setError(null);
    setIsSubmitting(true);
    const supabase = createClient();
    try {
      const { data: exact } = await supabase
        .from("subscriptions")
        .select("id")
        .eq("user_id", existingProfile.id)
        .eq("pass_id", selectedPass.id)
        .eq("start_date", startDate)
        .neq("status", "cancelled")
        .limit(1);
      if (exact && exact.length > 0) {
        setError(
          `A ${selectedPass.name} starting on ${prettyDate(startDate)} already exists for this member. Edit it from the Subscriptions page instead.`,
        );
        setIsSubmitting(false);
        return;
      }

      const windowStart = addDays(startDate, -7);
      const windowEnd = addDays(startDate, 7);
      const { data: near } = await supabase
        .from("subscriptions")
        .select("id, start_date")
        .eq("user_id", existingProfile.id)
        .eq("pass_id", selectedPass.id)
        .neq("status", "cancelled")
        .gte("start_date", windowStart)
        .lte("start_date", windowEnd)
        .limit(1);
      if (near && near.length > 0) {
        const proceed = window.confirm(
          `${existingProfile.full_name || "This member"} already has a ${selectedPass.name} starting ${prettyDate(near[0].start_date)} - within 7 days of this date. Add this as a separate enrollment anyway?`,
        );
        if (!proceed) {
          setIsSubmitting(false);
          return;
        }
      }

      const { data: sub, error: subErr } = await supabase
        .from("subscriptions")
        .insert({
          user_id: existingProfile.id,
          pass_id: selectedPass.id,
          start_date: startDate,
          end_date: endDate,
          status: "active",
          discount_amount: discountAmount > 0 ? discountAmount : 0,
        })
        .select("id")
        .single();
      if (subErr || !sub) throw subErr;

      let paymentFailed = false;
      if (safePaidAmount > 0) {
        const { error: paymentErr } = await supabase.from("payments").insert({
          subscription_id: sub.id,
          user_id: existingProfile.id,
          amount: safePaidAmount,
          payment_date: paymentDate,
          payment_method: paymentMethod.toLowerCase(),
          notes: notes.trim() || "Payment at renewal",
        });
        paymentFailed = !!paymentErr;
      }

      router.refresh();

      if (paymentFailed) {
        setError(
          `Membership updated, but recording the ${formatINR(safePaidAmount)} payment failed - add it manually from the Subscriptions page.`,
        );
        setIsSubmitting(false);
        return;
      }

      setSuccess({ name: existingProfile.full_name || "Member" });
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      setError(`Could not update the membership: ${detail}`);
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <Modal open={open} onClose={handleClose} maxWidthClass="max-w-[440px]">
      {success ? (
        <>
          <div className="flex items-center gap-3">
            <span className="grid size-9 shrink-0 place-items-center rounded-full bg-brand/15">
              <Check className="size-[18px] text-brand" />
            </span>
            <div className="text-[17px] font-bold">Membership Updated!</div>
          </div>
          <p className="mt-3 text-[14px] text-foreground">A new subscription has been added for {success.name}.</p>
          <button
            onClick={handleClose}
            className="mt-5 w-full rounded-xl bg-brand py-2.5 text-[14px] font-bold text-on-brand"
          >
            Done
          </button>
        </>
      ) : (
        <>
          <div className="text-[17px] font-bold">Update Membership</div>
          <p className="mt-1 text-[13px] text-muted-foreground">Enter the member&apos;s phone number to look them up.</p>

          <label className="mt-4 block">
            <div className="mb-1.5 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">
              Phone Number
            </div>
            <input
              value={phone}
              onChange={(e) => {
                setPhone(e.target.value.replace(/\D/g, "").slice(0, 10));
                setHasChecked(false);
                setCheckedPhone("");
                setExistingProfile(null);
                setExistingSubs([]);
                setError(null);
              }}
              onBlur={checkPhone}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  checkPhone();
                }
              }}
              inputMode="numeric"
              placeholder="e.g. 9876543210"
              autoFocus
              className="h-11 w-full rounded-xl border border-border bg-background px-3.5 text-[13.5px] font-medium outline-none focus:border-brand"
            />
          </label>

          {checkingPhone && (
            <div className="mt-3 flex items-center gap-2 text-[12.5px] text-muted-foreground">
              <Loader2 className="size-3.5 animate-spin" />
              Checking...
            </div>
          )}

          {hasChecked && !checkingPhone && !existingProfile && (
            <>
              <div className="mt-3 flex items-center gap-3 rounded-xl border border-border bg-muted px-3.5 py-3">
                <UserX className="size-5 shrink-0 text-muted-foreground" />
                <div className="min-w-0 flex-1 text-[13px] text-muted-foreground">No member found with this number.</div>
              </div>
              <button
                onClick={() => router.push(`/admin/add-member?phone=${phone.trim()}`)}
                className="mt-3 flex w-full items-center justify-center gap-2 rounded-xl bg-brand px-4 py-2.5 text-[13px] font-bold text-on-brand"
              >
                Add as New Member
                <ArrowRight className="size-4" />
              </button>
            </>
          )}

          {existingProfile && (
            <>
              <div className="mt-3 flex items-center gap-3 rounded-xl border border-brand/25 bg-brand/6 px-3.5 py-3">
                <div className="grid size-9 shrink-0 place-items-center rounded-full bg-brand/15 font-display text-[12px] font-bold text-brand">
                  {(existingProfile.full_name || "M")
                    .trim()
                    .split(/\s+/)
                    .filter(Boolean)
                    .slice(0, 2)
                    .map((w) => w[0]?.toUpperCase())
                    .join("")}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[13.5px] font-bold">{existingProfile.full_name || "Unnamed member"}</div>
                  <div className="text-[12px] text-muted-foreground">{statusMessage(existingSubs)}</div>
                </div>
              </div>

              <div className="mt-4 flex flex-col gap-3">
                <MiniDropdown
                  label="Pass Type *"
                  value={passId}
                  onChange={setPassId}
                  options={["", ...passes.map((p) => p.id)]}
                  optionLabel={(id) => {
                    if (!id) return "Select a pass";
                    const p = passes.find((x) => x.id === id)!;
                    return `${p.name} · ${formatINR(p.price)} · ${p.duration_days} days`;
                  }}
                />
                <div className="grid grid-cols-2 gap-3">
                  <MiniField label="Start Date" type="date" value={startDate} onChange={setStartDate} />
                  <MiniField
                    label="Extra Days"
                    hint="e.g. 5"
                    value={extraDays}
                    onChange={(v) => setExtraDays(v.replace(/\D/g, ""))}
                    inputMode="numeric"
                  />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <MiniSegmented value={isPercent} onChange={setIsPercent} />
                  <MiniField
                    label={isPercent ? "Discount %" : "Discount (₹)"}
                    hint={isPercent ? "e.g. 10" : "e.g. 200"}
                    value={discount}
                    onChange={(v) => setDiscount(v.replace(/[^\d.]/g, ""))}
                    inputMode="decimal"
                  />
                </div>

                {selectedPass && (
                  <div className="flex justify-around rounded-xl border border-border bg-background p-3">
                    <MiniStat label="FINAL" value={formatINR(effectivePrice)} bold />
                    <MiniStat label="PAID" value={formatINR(paidAmountNum)} className="text-brand" />
                    <MiniStat label="BALANCE" value={formatINR(balance)} className={balance > 0 ? "text-energy" : "text-brand"} />
                  </div>
                )}

                <div className="grid grid-cols-2 gap-3">
                  <MiniField
                    label="Amount Paid (₹)"
                    hint="e.g. 1500"
                    value={paidAmount}
                    onChange={(v) => setPaidAmount(v.replace(/[^\d.]/g, ""))}
                    inputMode="decimal"
                  />
                  <MiniField label="Payment Date" type="date" value={paymentDate} onChange={setPaymentDate} max={toYMD(new Date())} />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <MiniDropdown
                    label="Payment Method"
                    value={paymentMethod}
                    onChange={setPaymentMethod}
                    options={PAYMENT_METHODS}
                    optionLabel={(m) => m}
                  />
                  <MiniField label="Note (optional)" hint="e.g. Paid by father" value={notes} onChange={setNotes} />
                </div>
              </div>

              {error && <div className="mt-4 rounded-xl bg-danger/10 px-3.5 py-3 text-[13px] text-danger">{error}</div>}

              <button
                onClick={handleUpdateMembership}
                disabled={isSubmitting || !selectedPass}
                className="mt-5 flex w-full items-center justify-center gap-2 rounded-xl bg-brand py-3 text-[14px] font-bold text-on-brand disabled:opacity-50"
              >
                {isSubmitting ? "Updating…" : "Update Membership"}
              </button>
            </>
          )}
        </>
      )}
    </Modal>
  );
}

function MiniField({
  label,
  hint,
  value,
  onChange,
  inputMode,
  type,
  max,
}: {
  label: string;
  hint?: string;
  value: string;
  onChange: (v: string) => void;
  inputMode?: React.HTMLAttributes<HTMLInputElement>["inputMode"];
  type?: string;
  max?: string;
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
        max={max}
        className="h-10 w-full rounded-xl border border-border bg-background px-3 text-[13px] font-medium outline-none placeholder:font-normal placeholder:text-muted-foreground/60 focus:border-brand"
      />
    </label>
  );
}

function MiniDropdown<T extends string>({
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
          className="h-10 w-full appearance-none rounded-xl border border-border bg-background px-3 pr-8 text-[13px] font-medium outline-none focus:border-brand"
        >
          {options.map((o) => (
            <option key={o} value={o}>
              {optionLabel(o)}
            </option>
          ))}
        </select>
        <ChevronDown className="pointer-events-none absolute right-2.5 top-1/2 size-3.5 -translate-y-1/2 text-muted-foreground" />
      </div>
    </label>
  );
}

function MiniSegmented({ value, onChange }: { value: boolean; onChange: (v: boolean) => void }) {
  return (
    <div>
      <div className="mb-1.5 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">Discount Type</div>
      <div className="flex gap-2">
        <button
          type="button"
          onClick={() => onChange(false)}
          aria-pressed={!value}
          className={`h-10 flex-1 rounded-xl border text-[12px] font-bold ${
            !value ? "border-brand bg-brand text-on-brand" : "border-border text-muted-foreground"
          }`}
        >
          ₹
        </button>
        <button
          type="button"
          onClick={() => onChange(true)}
          aria-pressed={value}
          className={`h-10 flex-1 rounded-xl border text-[12px] font-bold ${
            value ? "border-brand bg-brand text-on-brand" : "border-border text-muted-foreground"
          }`}
        >
          %
        </button>
      </div>
    </div>
  );
}

function MiniStat({ label, value, className, bold }: { label: string; value: string; className?: string; bold?: boolean }) {
  return (
    <div className="text-center">
      <div className="text-[9px] font-semibold uppercase tracking-wide text-muted-foreground">{label}</div>
      <div className={`num mt-1 font-display text-[14px] ${bold ? "font-bold" : "font-semibold"} ${className ?? ""}`}>{value}</div>
    </div>
  );
}
