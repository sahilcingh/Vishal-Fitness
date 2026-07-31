"use client";

import { useEffect, useState } from "react";
import { AlertCircle, ListChecks, Ticket, Timer, Wallet } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Modal } from "@/components/admin/modal";

type Pass = { id: string; name: string; price: number; duration_days: number; features: string[] | null };

export function PassFormModal({
  pass,
  open,
  onClose,
  onSaved,
}: {
  pass: Pass | null;
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [name, setName] = useState("");
  const [duration, setDuration] = useState("");
  const [price, setPrice] = useState("");
  const [features, setFeatures] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!open) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect -- reset the form to the newly-opened pass (or blank for "add") before render
    setName(pass?.name ?? "");
    setDuration(pass?.duration_days != null ? String(pass.duration_days) : "");
    setPrice(pass?.price != null ? String(pass.price) : "");
    setFeatures((pass?.features ?? []).join("\n"));
    setError(null);
  }, [open, pass]);

  async function handleSave() {
    const trimmedName = name.trim();
    const trimmedDuration = duration.trim();
    const trimmedPrice = price.trim();
    // parseInt/parseFloat parse a leading valid prefix and ignore the rest
    // (e.g. parseFloat("100..5") === 100), unlike Dart's int.tryParse /
    // double.tryParse which reject the whole string as malformed. The digit
    // filters on these fields still let a pasted value through with extra
    // dots, so validate the full string shape before parsing.
    const durationNum = /^\d+$/.test(trimmedDuration) ? parseInt(trimmedDuration, 10) : NaN;
    const priceNum = /^\d+(\.\d+)?$/.test(trimmedPrice) ? parseFloat(trimmedPrice) : NaN;

    if (!trimmedName) return setError("Please enter a name for this pass.");
    if (!Number.isFinite(durationNum) || durationNum <= 0) return setError("Duration must be at least 1 day.");
    if (durationNum > 365) return setError("Duration cannot exceed 365 days.");
    if (!Number.isFinite(priceNum) || priceNum <= 0) return setError("Price must be greater than ₹0.");
    if (priceNum > 100000) return setError("Price cannot exceed ₹1,00,000. Please verify the amount.");

    const featuresArray = features
      .split("\n")
      .map((s) => s.trim())
      .filter((s) => s.length > 0);

    // durationNum/priceNum are already range-checked above (1-365 days,
    // ₹0-1,00,000). NOTE: only client-side validated; add a CHECK constraint
    // on gym_passes.duration_days / gym_passes.price at the DB level for a
    // real backstop - a client calling the Supabase REST API directly could
    // still write an out-of-range value.
    const passData = {
      name: trimmedName,
      duration_days: durationNum,
      price: priceNum,
      features: featuresArray,
    };

    setError(null);
    setSaving(true);
    const supabase = createClient();
    try {
      const { error: dbError } = pass
        ? await supabase.from("gym_passes").update(passData).eq("id", pass.id)
        : await supabase.from("gym_passes").insert(passData);
      if (dbError) throw dbError;
      onSaved();
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      setError(`Could not save this pass: ${detail}`);
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal open={open} onClose={onClose} maxWidthClass="max-w-[480px]">
      <div className="text-[17px] font-bold">{pass ? "Edit Pass" : "Add New Pass"}</div>

      <div className="mt-4 flex flex-col gap-3">
        <FormField icon={Ticket} label="Name (e.g., 1 Month)" value={name} onChange={setName} />
        <div className="grid grid-cols-2 gap-3">
          <FormField
            icon={Timer}
            label="Days (e.g., 30)"
            value={duration}
            onChange={(v) => setDuration(v.replace(/\D/g, ""))}
            inputMode="numeric"
          />
          <FormField
            icon={Wallet}
            label="Price (₹)"
            value={price}
            onChange={(v) => setPrice(v.replace(/[^\d.]/g, ""))}
            inputMode="decimal"
          />
        </div>
        <label className="flex items-start gap-2.5 rounded-xl border border-border bg-card px-4 py-2.5">
          <ListChecks className="mt-0.5 size-[18px] shrink-0 text-muted-foreground" />
          <div className="min-w-0 flex-1">
            <div className="text-[11px] text-muted-foreground">Features (one per line)</div>
            <textarea
              value={features}
              onChange={(e) => setFeatures(e.target.value)}
              rows={5}
              className="mt-0.5 w-full resize-none bg-transparent text-[14px] font-medium outline-none"
            />
          </div>
        </label>
      </div>

      {error && (
        <div className="mt-4 flex items-start gap-2 rounded-xl bg-danger/10 px-3.5 py-3 text-[13px] text-danger">
          <AlertCircle className="mt-0.5 size-4 shrink-0" />
          {error}
        </div>
      )}

      <div className="mt-5 flex gap-2.5">
        <button
          type="button"
          onClick={onClose}
          className="flex-1 rounded-xl border border-border py-2.5 text-[14px] font-semibold text-muted-foreground"
        >
          Cancel
        </button>
        <button
          type="button"
          onClick={handleSave}
          disabled={saving}
          className="flex-1 rounded-xl bg-brand py-2.5 text-[14px] font-bold text-on-brand disabled:opacity-50"
        >
          {saving ? "Saving…" : "Save"}
        </button>
      </div>
    </Modal>
  );
}

function FormField({
  icon: Icon,
  label,
  value,
  onChange,
  inputMode,
}: {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  value: string;
  onChange: (v: string) => void;
  inputMode?: React.HTMLAttributes<HTMLInputElement>["inputMode"];
}) {
  return (
    <label className="flex items-center gap-2.5 rounded-xl border border-border bg-card px-4 py-2.5">
      <Icon className="size-[18px] shrink-0 text-muted-foreground" />
      <div className="min-w-0 flex-1">
        <div className="text-[11px] text-muted-foreground">{label}</div>
        <input
          value={value}
          onChange={(e) => onChange(e.target.value)}
          inputMode={inputMode}
          className="mt-0.5 w-full bg-transparent text-[14px] font-medium outline-none"
        />
      </div>
    </label>
  );
}
