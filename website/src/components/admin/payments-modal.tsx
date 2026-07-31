"use client";

import { useEffect, useState } from "react";
import { Plus, Receipt, Loader2, CalendarDays, X } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { formatINR } from "@/lib/format";
import { Modal } from "@/components/admin/modal";

type Payment = {
  id: string;
  amount: number;
  payment_date: string;
  payment_method: string | null;
  notes: string | null;
};

const METHODS = ["Cash", "UPI", "Card"];

function toYMD(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
function prettyDate(s: string) {
  return new Date(s).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
}

export function PaymentsModal({
  open,
  onClose,
  onRecorded,
  subscriptionId,
  userId,
  memberName,
  passName,
  passPrice,
  discountAmount,
}: {
  open: boolean;
  onClose: () => void;
  onRecorded: () => void;
  subscriptionId: string | null;
  userId: string;
  memberName: string;
  passName: string;
  passPrice: number;
  discountAmount: number;
}) {
  const [loading, setLoading] = useState(true);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState("Cash");
  const [date, setDate] = useState(toYMD(new Date()));
  const [notes, setNotes] = useState("");
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open || !subscriptionId) return;
    let cancelled = false;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- reset transient state for the newly-opened subscription before the fetch starts
    setLoading(true);
    setShowForm(false);
    setAmount("");
    setNotes("");
    setDate(toYMD(new Date()));
    setMethod("Cash");
    setError(null);

    (async () => {
      const supabase = createClient();
      const { data } = await supabase
        .from("payments")
        .select("id, amount, payment_date, payment_method, notes")
        .eq("subscription_id", subscriptionId)
        .order("payment_date", { ascending: false });
      if (cancelled) return;
      setPayments(data ?? []);
      setLoading(false);
    })();

    return () => {
      cancelled = true;
    };
  }, [open, subscriptionId]);

  const totalFee = Math.max(passPrice - discountAmount, 0);
  const totalPaid = payments.reduce((sum, p) => sum + (p.amount ?? 0), 0);
  const balance = totalFee - totalPaid;

  async function handleRecord() {
    const amt = parseFloat(amount);
    if (!amt || amt <= 0) {
      setError("Please enter a payment amount greater than ₹0.");
      return;
    }
    if (amt > balance) {
      setError(`Payment of ${formatINR(amt)} exceeds the remaining balance of ${formatINR(balance)}.`);
      return;
    }
    setError(null);
    setIsSaving(true);
    const supabase = createClient();
    // Re-clamped immediately before the insert as a last line of defense -
    // the checks above already block submission, but this keeps the actual
    // write safe even if that gate is ever bypassed.
    // NOTE: only client-side validated; add a CHECK constraint on
    // payments.amount at the DB level for a real backstop.
    const safeAmount = Math.min(Math.max(amt, 0), balance);
    try {
      const { error: insertErr } = await supabase.from("payments").insert({
        subscription_id: subscriptionId,
        user_id: userId,
        amount: safeAmount,
        payment_date: date,
        payment_method: method.toLowerCase(),
        notes: notes.trim() || null,
      });
      if (insertErr) throw insertErr;
      setAmount("");
      setNotes("");
      setShowForm(false);
      setDate(toYMD(new Date()));
      setMethod("Cash");

      const { data } = await supabase
        .from("payments")
        .select("id, amount, payment_date, payment_method, notes")
        .eq("subscription_id", subscriptionId)
        .order("payment_date", { ascending: false });
      setPayments(data ?? []);
      onRecorded();
    } catch (err) {
      const msg = (err as { message?: string } | null)?.message;
      setError(`Could not record the payment${msg ? `: ${msg}` : ". Please try again."}`);
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <Modal open={open} onClose={onClose} maxWidthClass="max-w-[480px]">
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="text-[17px] font-bold">{memberName}</div>
          <div className="text-[13px] text-muted-foreground">{passName}</div>
        </div>
        <div className="flex shrink-0 items-center gap-2">
          {!showForm && (
            <button
              onClick={() => setShowForm(true)}
              className="flex items-center gap-1.5 rounded-lg bg-brand px-3 py-2 text-[13px] font-bold text-on-brand"
            >
              <Plus className="size-3.5" />
              Add
            </button>
          )}
          <button
            onClick={onClose}
            aria-label="Close"
            className="grid size-8 place-items-center rounded-lg text-muted-foreground hover:bg-muted"
          >
            <X className="size-4" />
          </button>
        </div>
      </div>

      <div className="mt-4 flex justify-around rounded-xl bg-background p-3">
        <SummaryCell label="TOTAL" value={formatINR(totalFee)} />
        <SummaryCell label="PAID" value={formatINR(totalPaid)} className="text-brand" />
        <SummaryCell label="BALANCE" value={formatINR(balance)} className={balance > 0 ? "text-energy" : "text-brand"} />
      </div>

      {showForm && (
        <div className="mt-4 rounded-xl border border-brand/30 bg-muted p-4">
          <div className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
            Record Payment
          </div>
          <div className="mt-3 grid grid-cols-2 gap-2.5">
            <label className="rounded-lg border border-border bg-card px-3 py-2">
              <div className="text-[10px] text-muted-foreground">Amount (₹)</div>
              <input
                value={amount}
                onChange={(e) => setAmount(e.target.value.replace(/[^\d.]/g, ""))}
                inputMode="decimal"
                className="mt-0.5 w-full bg-transparent text-[13px] font-semibold outline-none"
              />
            </label>
            <label className="rounded-lg border border-border bg-card px-3 py-2">
              <div className="text-[10px] text-muted-foreground">Method</div>
              <select value={method} onChange={(e) => setMethod(e.target.value)} className="mt-0.5 w-full bg-transparent text-[13px] font-semibold outline-none">
                {METHODS.map((m) => (
                  <option key={m} value={m}>
                    {m}
                  </option>
                ))}
              </select>
            </label>
          </div>
          <label className="mt-2.5 flex items-center gap-2 rounded-lg border border-border bg-card px-3 py-2">
            <CalendarDays className="size-4 shrink-0 text-muted-foreground" />
            <input type="date" value={date} onChange={(e) => setDate(e.target.value)} className="w-full bg-transparent text-[13px] font-semibold outline-none" />
          </label>
          <label className="mt-2.5 block rounded-lg border border-border bg-card px-3 py-2">
            <div className="text-[10px] text-muted-foreground">Note (optional)</div>
            <input value={notes} onChange={(e) => setNotes(e.target.value)} className="mt-0.5 w-full bg-transparent text-[13px] font-medium outline-none" />
          </label>

          {error && <div className="mt-3 rounded-lg bg-danger/10 px-3 py-2 text-[12.5px] text-danger">{error}</div>}

          <div className="mt-3 flex gap-2.5">
            <button
              onClick={() => {
                setShowForm(false);
                setError(null);
              }}
              className="flex-1 rounded-lg border border-border py-2.5 text-[13px] font-semibold text-muted-foreground"
            >
              Cancel
            </button>
            <button
              onClick={handleRecord}
              disabled={isSaving}
              className="flex-[2] rounded-lg bg-brand py-2.5 text-[13px] font-bold text-on-brand disabled:opacity-50"
            >
              {isSaving ? "Saving…" : "Record Payment"}
            </button>
          </div>
        </div>
      )}

      <div className="mt-4 max-h-[320px] overflow-y-auto">
        {loading ? (
          <div className="flex justify-center py-8">
            <Loader2 className="size-5 animate-spin text-brand" />
          </div>
        ) : payments.length === 0 ? (
          <p className="py-6 text-center text-[13px] text-muted-foreground">No payments recorded yet.</p>
        ) : (
          <div className="flex flex-col gap-2">
            {payments.map((p) => (
              <div key={p.id} className="flex items-center gap-3 rounded-lg border border-border bg-background px-3 py-2.5">
                <span className="grid size-9 shrink-0 place-items-center rounded-lg bg-brand/10">
                  <Receipt className="size-4 text-brand" />
                </span>
                <div className="min-w-0 flex-1">
                  <div className="text-[14px] font-bold">{formatINR(p.amount)}</div>
                  {p.notes && <div className="truncate text-[11.5px] text-muted-foreground">{p.notes}</div>}
                </div>
                <div className="shrink-0 text-right">
                  <div className="text-[10px] font-semibold uppercase text-muted-foreground">
                    {(p.payment_method ?? "cash").toUpperCase()}
                  </div>
                  <div className="mt-0.5 text-[11.5px] text-muted-foreground">{prettyDate(p.payment_date)}</div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </Modal>
  );
}

function SummaryCell({ label, value, className }: { label: string; value: string; className?: string }) {
  return (
    <div className="text-center">
      <div className="text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">{label}</div>
      <div className={`num mt-1 font-display text-[17px] font-bold ${className ?? ""}`}>{value}</div>
    </div>
  );
}
