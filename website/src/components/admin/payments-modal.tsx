"use client";

import { useEffect, useRef, useState } from "react";
import { Plus, Receipt, Loader2, X, Pencil, Trash2, Check } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { formatINR } from "@/lib/format";
import { Modal } from "@/components/admin/modal";
import { DateInput } from "@/components/admin/date-input";
import { logMemberEvent } from "@/lib/member-events";

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
  // null while adding a brand new payment; the payment's id while editing an
  // existing one - the same form below serves both, just pre-filled and
  // routed to an update instead of an insert.
  const [editingId, setEditingId] = useState<string | null>(null);
  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState("Cash");
  const [date, setDate] = useState(toYMD(new Date()));
  const [notes, setNotes] = useState("");
  const [isSaving, setIsSaving] = useState(false);
  // A ref, not just the isSaving state - state only disables the button
  // after a re-render commits, which a fast double-click can race past.
  // This check is synchronous, so the second call is rejected immediately.
  const isSavingRef = useRef(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Editable locally so Total/Balance react immediately, rather than waiting
  // on the parent to refetch and pass a new `discountAmount` prop down.
  const [discount, setDiscount] = useState(String(discountAmount));
  const [editingDiscount, setEditingDiscount] = useState(false);
  const [isSavingDiscount, setIsSavingDiscount] = useState(false);

  useEffect(() => {
    if (!open) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- reset to the newly-opened subscription's real value
    setDiscount(String(discountAmount));
    setEditingDiscount(false);
  }, [open, discountAmount]);

  useEffect(() => {
    if (!open || !subscriptionId) return;
    let cancelled = false;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- reset transient state for the newly-opened subscription before the fetch starts
    setLoading(true);
    setShowForm(false);
    setEditingId(null);
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

  const discountNum = Math.min(Math.max(parseFloat(discount) || 0, 0), passPrice);
  const totalFee = Math.max(passPrice - discountNum, 0);
  const totalPaid = payments.reduce((sum, p) => sum + (p.amount ?? 0), 0);
  const balance = totalFee - totalPaid;

  async function handleSaveDiscount() {
    if (!subscriptionId) return;
    setIsSavingDiscount(true);
    setError(null);
    const supabase = createClient();
    try {
      const { error: updateErr } = await supabase
        .from("subscriptions")
        .update({ discount_amount: discountNum })
        .eq("id", subscriptionId);
      if (updateErr) throw updateErr;
      if (discountNum !== discountAmount) {
        await logMemberEvent(supabase, {
          userId,
          subscriptionId,
          eventType: "subscription_edit",
          description: `Discount changed to ${formatINR(discountNum)}`,
        });
      }
      setDiscount(String(discountNum));
      setEditingDiscount(false);
      onRecorded();
    } catch (err) {
      const msg = (err as { message?: string } | null)?.message;
      setError(`Could not save the discount${msg ? `: ${msg}` : ". Please try again."}`);
    } finally {
      setIsSavingDiscount(false);
    }
  }

  async function refetchPayments() {
    const supabase = createClient();
    const { data } = await supabase
      .from("payments")
      .select("id, amount, payment_date, payment_method, notes")
      .eq("subscription_id", subscriptionId)
      .order("payment_date", { ascending: false });
    setPayments(data ?? []);
  }

  function closeForm() {
    setShowForm(false);
    setEditingId(null);
    setAmount("");
    setNotes("");
    setDate(toYMD(new Date()));
    setMethod("Cash");
    setError(null);
  }

  function openAddForm() {
    closeForm();
    setShowForm(true);
  }

  function openEditForm(payment: Payment) {
    setEditingId(payment.id);
    setAmount(String(payment.amount));
    setMethod(METHODS.find((m) => m.toLowerCase() === (payment.payment_method ?? "").toLowerCase()) ?? "Cash");
    setDate(payment.payment_date.slice(0, 10));
    setNotes(payment.notes ?? "");
    setError(null);
    setShowForm(true);
  }

  async function handleSubmitForm() {
    if (isSavingRef.current) return;
    const amt = parseFloat(amount);
    if (!amt || amt <= 0) {
      setError("Please enter a payment amount greater than ₹0.");
      return;
    }
    // Excludes the payment being edited from "already paid" so editing one
    // isn't blocked by its own pre-edit value.
    const otherPaid = payments.filter((p) => p.id !== editingId).reduce((sum, p) => sum + (p.amount ?? 0), 0);
    const balanceForThis = totalFee - otherPaid;
    if (amt > balanceForThis) {
      setError(`Payment of ${formatINR(amt)} exceeds the remaining balance of ${formatINR(balanceForThis)}.`);
      return;
    }
    setError(null);
    isSavingRef.current = true;
    setIsSaving(true);
    const supabase = createClient();
    // Re-clamped immediately before the write as a last line of defense -
    // the checks above already block submission, but this keeps the actual
    // write safe even if that gate is ever bypassed.
    // NOTE: only client-side validated; add a CHECK constraint on
    // payments.amount at the DB level for a real backstop.
    const safeAmount = Math.min(Math.max(amt, 0), balanceForThis);
    try {
      if (editingId) {
        const { error: updateErr } = await supabase
          .from("payments")
          .update({
            amount: safeAmount,
            payment_date: date,
            payment_method: method.toLowerCase(),
            notes: notes.trim() || null,
          })
          .eq("id", editingId);
        if (updateErr) throw updateErr;
        await logMemberEvent(supabase, {
          userId,
          subscriptionId,
          eventType: "payment_edit",
          description: `Edited payment to ${formatINR(safeAmount)} on ${prettyDate(date)}`,
        });
      } else {
        const { error: insertErr } = await supabase.from("payments").insert({
          subscription_id: subscriptionId,
          user_id: userId,
          amount: safeAmount,
          payment_date: date,
          payment_method: method.toLowerCase(),
          notes: notes.trim() || null,
        });
        if (insertErr) throw insertErr;
      }
      closeForm();
      await refetchPayments();
      onRecorded();
    } catch (err) {
      const msg = (err as { message?: string } | null)?.message;
      setError(`Could not ${editingId ? "update" : "record"} the payment${msg ? `: ${msg}` : ". Please try again."}`);
    } finally {
      isSavingRef.current = false;
      setIsSaving(false);
    }
  }

  async function handleDelete(payment: Payment) {
    if (
      !window.confirm(
        `Delete the ${formatINR(payment.amount)} payment from ${prettyDate(payment.payment_date)}? This cannot be undone.`,
      )
    ) {
      return;
    }
    setDeletingId(payment.id);
    setError(null);
    const supabase = createClient();
    try {
      const { error: delErr } = await supabase.from("payments").delete().eq("id", payment.id);
      if (delErr) throw delErr;
      await logMemberEvent(supabase, {
        userId,
        subscriptionId,
        eventType: "payment_delete",
        description: `Deleted ${formatINR(payment.amount)} payment from ${prettyDate(payment.payment_date)}`,
      });
      if (editingId === payment.id) closeForm();
      await refetchPayments();
      onRecorded();
    } catch (err) {
      const msg = (err as { message?: string } | null)?.message;
      setError(`Could not delete the payment${msg ? `: ${msg}` : ". Please try again."}`);
    } finally {
      setDeletingId(null);
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
              onClick={openAddForm}
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

      {editingDiscount ? (
        <div className="mt-2.5 flex items-center gap-2 rounded-xl border border-brand/30 bg-muted p-2.5">
          <label className="flex-1 rounded-lg border border-border bg-card px-3 py-2">
            <div className="text-[10px] text-muted-foreground">Discount (₹)</div>
            <input
              value={discount}
              onChange={(e) => setDiscount(e.target.value.replace(/[^\d.]/g, ""))}
              inputMode="decimal"
              className="mt-0.5 w-full bg-transparent text-[13px] font-semibold outline-none"
            />
          </label>
          <button
            type="button"
            onClick={() => {
              setDiscount(String(discountAmount));
              setEditingDiscount(false);
            }}
            className="rounded-lg border border-border px-3 py-2.5 text-[13px] font-semibold text-muted-foreground"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={handleSaveDiscount}
            disabled={isSavingDiscount}
            className="flex items-center gap-1 rounded-lg bg-brand px-3 py-2.5 text-[13px] font-bold text-on-brand disabled:opacity-50"
          >
            {isSavingDiscount ? <Loader2 className="size-3.5 animate-spin" /> : <Check className="size-3.5" />}
            Save
          </button>
        </div>
      ) : (
        <div className="mt-2.5 flex items-center justify-between rounded-xl border border-border bg-card px-3 py-2">
          <div className="text-[12px] text-muted-foreground">
            Discount: <span className="font-semibold text-foreground">{formatINR(discountNum)}</span>
          </div>
          <button
            type="button"
            onClick={() => setEditingDiscount(true)}
            className="flex items-center gap-1 text-[12px] font-semibold text-brand"
          >
            <Pencil className="size-3.5" />
            Edit
          </button>
        </div>
      )}

      {showForm && (
        <div className="mt-4 rounded-xl border border-brand/30 bg-muted p-4">
          <div className="text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
            {editingId ? "Edit Payment" : "Record Payment"}
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
          <DateInput
            value={date}
            onChange={setDate}
            className="mt-2.5 w-full rounded-lg border border-border bg-card px-3 py-2 text-[13px] font-semibold outline-none"
          />
          <label className="mt-2.5 block rounded-lg border border-border bg-card px-3 py-2">
            <div className="text-[10px] text-muted-foreground">Note (optional)</div>
            <input value={notes} onChange={(e) => setNotes(e.target.value)} className="mt-0.5 w-full bg-transparent text-[13px] font-medium outline-none" />
          </label>

          {error && <div className="mt-3 rounded-lg bg-danger/10 px-3 py-2 text-[12.5px] text-danger">{error}</div>}

          <div className="mt-3 flex gap-2.5">
            <button
              onClick={closeForm}
              className="flex-1 rounded-lg border border-border py-2.5 text-[13px] font-semibold text-muted-foreground"
            >
              Cancel
            </button>
            <button
              onClick={handleSubmitForm}
              disabled={isSaving}
              className="flex-[2] rounded-lg bg-brand py-2.5 text-[13px] font-bold text-on-brand disabled:opacity-50"
            >
              {isSaving ? "Saving…" : editingId ? "Save Changes" : "Record Payment"}
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
              <div
                key={p.id}
                className={`flex items-center gap-3 rounded-lg border px-3 py-2.5 ${editingId === p.id ? "border-brand/40 bg-brand/6" : "border-border bg-background"}`}
              >
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
                <div className="flex shrink-0 items-center gap-1">
                  <button
                    type="button"
                    onClick={() => openEditForm(p)}
                    aria-label="Edit payment"
                    className="grid size-7 place-items-center rounded-md text-muted-foreground hover:bg-muted hover:text-brand"
                  >
                    <Pencil className="size-3.5" />
                  </button>
                  <button
                    type="button"
                    onClick={() => handleDelete(p)}
                    disabled={deletingId === p.id}
                    aria-label="Delete payment"
                    className="grid size-7 place-items-center rounded-md text-muted-foreground hover:bg-danger/10 hover:text-danger disabled:opacity-50"
                  >
                    {deletingId === p.id ? <Loader2 className="size-3.5 animate-spin" /> : <Trash2 className="size-3.5" />}
                  </button>
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
