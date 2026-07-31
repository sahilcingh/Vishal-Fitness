"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import {
  Search,
  ChevronDown,
  Key,
  Copy,
  Pencil,
  MoreHorizontal,
  Tag,
  CreditCard,
  Loader2,
  AlertTriangle,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { formatINR } from "@/lib/format";
import { initials } from "@/lib/utils";
import { Modal } from "@/components/admin/modal";
import { EditMemberModal, type EditableMember } from "@/components/admin/edit-member-modal";
import { PaymentsModal } from "@/components/admin/payments-modal";
import { Pagination, paginate } from "@/components/admin/pagination";

const PAGE_SIZE = 10;

export type SubscriptionRow = {
  id: string;
  start_date: string;
  end_date: string;
  status: string;
  user_id: string;
  discount_amount: number | null;
  pass_id: string | null;
  profiles: { full_name: string | null; phone: string | null; photo_url: string | null; time_slot: string | null } | null;
  gym_passes: { name: string | null; duration_days: number | null; price: number | null } | null;
  paid: number;
};

type Pass = { id: string; name: string; price: number; duration_days: number };

function membershipNo(userId: string) {
  return `MBR-${userId.replace(/-/g, "").slice(0, 6).toUpperCase()}`;
}
function prettyDate(s: string) {
  return new Date(s).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
}

export function SubscriptionsList({
  subscriptions,
  passes,
  nowMs,
}: {
  subscriptions: SubscriptionRow[];
  passes: Pass[];
  nowMs: number;
}) {
  const router = useRouter();
  const [search, setSearch] = useState("");
  const [selectedType, setSelectedType] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [expanded, setExpanded] = useState<Set<string>>(new Set());
  const [memberEmails, setMemberEmails] = useState<Record<string, string | null>>({});
  const [resetting, setResetting] = useState<Set<string>>(new Set());
  const [credentials, setCredentials] = useState<{ name: string; email: string; password: string } | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [discountFor, setDiscountFor] = useState<SubscriptionRow | null>(null);
  const [paymentsFor, setPaymentsFor] = useState<SubscriptionRow | null>(null);
  const [editingMember, setEditingMember] = useState<EditableMember | null>(null);

  const passTypes = useMemo(() => {
    const seen = new Set<string>();
    for (const s of subscriptions) {
      const name = s.gym_passes?.name;
      if (name) seen.add(name);
    }
    return Array.from(seen).sort();
  }, [subscriptions]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    const list = subscriptions.filter((s) => {
      const name = (s.profiles?.full_name ?? "").toLowerCase();
      const phone = (s.profiles?.phone ?? "").toLowerCase();
      const memberNo = membershipNo(s.user_id).toLowerCase();
      const matchesSearch = !q || name.includes(q) || phone.includes(q) || memberNo.includes(q);
      if (!matchesSearch) return false;
      if (selectedType && s.gym_passes?.name !== selectedType) return false;
      return true;
    });
    return [...list].sort((a, b) => (a.profiles?.full_name ?? "").localeCompare(b.profiles?.full_name ?? ""));
  }, [subscriptions, search, selectedType]);

  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const pageItems = useMemo(() => paginate(filtered, page, PAGE_SIZE), [filtered, page]);

  async function toggleExpand(sub: SubscriptionRow) {
    const next = new Set(expanded);
    if (next.has(sub.id)) {
      next.delete(sub.id);
    } else {
      next.add(sub.id);
      if (!(sub.user_id in memberEmails)) {
        const phone = sub.profiles?.phone;
        if (phone) {
          const supabase = createClient();
          const { data } = await supabase.rpc("get_email_by_phone", { phone_input: phone.replace(/\D/g, "") });
          setMemberEmails((m) => ({ ...m, [sub.user_id]: (data as string) ?? null }));
        } else {
          setMemberEmails((m) => ({ ...m, [sub.user_id]: null }));
        }
      }
    }
    setExpanded(next);
  }

  async function updateStatus(id: string, status: string) {
    // Suspending or cancelling is destructive (cuts the member's access) and
    // fires immediately from the menu — confirm before mutating.
    if (status === "suspended" && !window.confirm("Suspend this subscription? The member will lose access until it's reactivated.")) {
      return;
    }
    if (status === "cancelled" && !window.confirm("Cancel this subscription? This cannot be undone from here.")) {
      return;
    }
    const supabase = createClient();
    const { error } = await supabase.from("subscriptions").update({ status }).eq("id", id);
    if (error) {
      setErrorMessage(`Could not update the status: ${error.message}`);
      return;
    }
    router.refresh();
  }

  async function resetPassword(userId: string, name: string) {
    setResetting((s) => new Set(s).add(userId));
    const supabase = createClient();
    try {
      const { data, error } = await supabase.functions.invoke("reset-member-password", { body: { user_id: userId } });
      let result = data as { success?: boolean; temp_password?: string; error?: string } | null;
      if (error) {
        try {
          result = await (error as unknown as { context: Response }).context.json();
        } catch {
          result = { error: error.message };
        }
      }
      if (result?.success) {
        setCredentials({ name, email: memberEmails[userId] ?? "—", password: result.temp_password ?? "" });
      } else {
        setErrorMessage(result?.error ?? "Reset failed. Deploy the reset-member-password Edge Function first.");
      }
    } catch {
      setErrorMessage("Reset failed. Make sure the reset-member-password Edge Function is deployed.");
    } finally {
      setResetting((s) => {
        const next = new Set(s);
        next.delete(userId);
        return next;
      });
    }
  }

  return (
    <div>
      <div className="relative mb-3.5">
        <Search className="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <input
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
          placeholder="Search by name, phone or MBR..."
          className="w-full rounded-xl border border-border bg-card py-2.5 pl-10 pr-4 text-[14px] outline-none focus:border-brand"
        />
      </div>

      {passTypes.length > 0 && (
        <div className="mb-4 flex gap-2 overflow-x-auto pb-1">
          <FilterChip
            label="All"
            count={subscriptions.length}
            active={selectedType === null}
            onClick={() => {
              setSelectedType(null);
              setPage(1);
            }}
          />
          {passTypes.map((type) => (
            <FilterChip
              key={type}
              label={type}
              count={subscriptions.filter((s) => s.gym_passes?.name === type).length}
              active={selectedType === type}
              onClick={() => {
                setSelectedType(selectedType === type ? null : type);
                setPage(1);
              }}
            />
          ))}
        </div>
      )}

      {filtered.length === 0 ? (
        <p className="py-16 text-center text-[13px] text-muted-foreground">
          {search && selectedType
            ? `No results for "${search}" in ${selectedType}.`
            : search
              ? `No results for "${search}".`
              : selectedType
                ? `No results in ${selectedType}.`
                : "No subscriptions found."}
        </p>
      ) : (
        <div className="flex flex-col gap-2.5">
          {pageItems.map((sub) => {
            const isExpanded = expanded.has(sub.id);
            const profile = sub.profiles;
            const pass = sub.gym_passes;
            const endDate = new Date(sub.end_date);
            const daysLeft = Math.floor((endDate.getTime() - nowMs) / 86_400_000);
            const isExpired = daysLeft < 0 || sub.status === "expired";
            const totalFee = pass?.price ?? 0;
            const discountAmount = sub.discount_amount ?? 0;
            const effectivePrice = Math.max(totalFee - discountAmount, 0);
            const balance = effectivePrice - sub.paid;
            const name = profile?.full_name ?? "Unknown";
            const email = memberEmails[sub.user_id];
            const isResetting = resetting.has(sub.user_id);

            return (
              <div
                key={sub.id}
                className={`rounded-[20px] border bg-card ${isExpired ? "border-energy/40" : "border-border"}`}
              >
                <button onClick={() => toggleExpand(sub)} className="flex w-full flex-col gap-3 px-4 py-3.5 text-left">
                  <div className="flex items-center gap-3">
                    <span
                      className={`grid size-10 shrink-0 place-items-center overflow-hidden rounded-full text-[13px] font-bold ${
                        isExpired ? "bg-energy/12 text-energy" : "bg-brand/12 text-brand"
                      }`}
                    >
                      {profile?.photo_url ? (
                        <Image src={profile.photo_url} alt="" width={40} height={40} className="size-full object-cover" />
                      ) : (
                        initials(name)
                      )}
                    </span>
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-[14px] font-bold">{name}</div>
                      <div className="mt-0.5 flex items-center gap-1.5">
                        <span className="rounded bg-brand/8 px-1.5 py-0.5 text-[9px] font-bold text-brand">
                          {membershipNo(sub.user_id)}
                        </span>
                        <span className="truncate text-[11px] text-muted-foreground">{profile?.phone}</span>
                      </div>
                      {pass?.name && (
                        <span
                          className={`mt-1.5 inline-block rounded-full px-1.5 py-0.5 text-[9px] font-extrabold ${
                            isExpired ? "bg-energy/10 text-energy" : "bg-aqua/10 text-aqua"
                          }`}
                        >
                          {pass.name}
                        </span>
                      )}
                    </div>
                    <div className="flex shrink-0 flex-col items-end gap-1.5">
                      <span
                        className={`rounded-full px-2 py-1 text-[9.5px] font-bold ${
                          isExpired ? "bg-energy/10 text-energy" : "bg-brand/10 text-brand"
                        }`}
                      >
                        {sub.status.charAt(0).toUpperCase() + sub.status.slice(1)}
                      </span>
                      <ChevronDown className={`size-4 text-muted-foreground transition-transform ${isExpanded ? "rotate-180" : ""}`} />
                    </div>
                  </div>

                  <div className="flex rounded-lg bg-background py-1.5">
                    <MiniStat label="TOTAL" value={formatINR(effectivePrice)} />
                    <Divider />
                    <MiniStat label="DISC" value={discountAmount > 0 ? formatINR(discountAmount) : "—"} className={discountAmount > 0 ? "text-sun" : "text-muted-foreground"} />
                    <Divider />
                    <MiniStat label="PAID" value={formatINR(sub.paid)} className="text-brand" />
                    <Divider />
                    <MiniStat label="BAL" value={formatINR(balance)} className={balance > 0 ? "text-energy" : "text-brand"} />
                  </div>
                </button>

                {isExpanded && (
                  <div className="border-t border-border p-4">
                    <div className="grid grid-cols-2 gap-3">
                      <DetailCell label="PASS TYPE" value={pass?.name ?? "Custom"} />
                      <DetailCell label="DAYS LEFT" value={isExpired ? "Expired" : `${daysLeft} days`} valueClass={isExpired ? "text-energy" : ""} align="right" />
                    </div>
                    {profile?.time_slot && (
                      <div className="mt-3">
                        <DetailCell label="TIME SLOT" value={profile.time_slot} valueClass="text-brand" />
                      </div>
                    )}
                    <div className="mt-3 grid grid-cols-2 gap-3">
                      <DetailCell label="STARTED" value={prettyDate(sub.start_date.slice(0, 10) || sub.start_date)} />
                      <DetailCell label="ENDS" value={prettyDate(sub.end_date.slice(0, 10) || sub.end_date)} align="right" />
                    </div>

                    <div className="mt-3 flex items-center justify-between">
                      <DetailCell label="DISCOUNT" value={discountAmount > 0 ? `${formatINR(discountAmount)} off` : "None"} valueClass={discountAmount > 0 ? "text-brand" : ""} />
                      <button onClick={() => setDiscountFor(sub)} className="flex items-center gap-1.5 text-[12px] font-semibold text-brand">
                        <Tag className="size-3.5" />
                        Set
                      </button>
                    </div>

                    <div className="mt-3.5 flex items-center gap-3 rounded-xl bg-background p-3">
                      <div className="min-w-0 flex-1">
                        <div className="text-[9px] font-semibold uppercase tracking-wide text-muted-foreground">Payment</div>
                        <div className="mt-0.5 text-[13px] font-semibold">
                          <span className="text-brand">{formatINR(sub.paid)} paid</span>{" "}
                          <span className="text-muted-foreground">/ {formatINR(effectivePrice)}</span>
                        </div>
                        {balance > 0 ? (
                          <div className="text-[11px] text-energy">Balance {formatINR(balance)}</div>
                        ) : (
                          <div className="text-[11px] font-semibold text-brand">Fully Paid</div>
                        )}
                      </div>
                      <button
                        onClick={() => setPaymentsFor(sub)}
                        className="flex shrink-0 items-center gap-1.5 rounded-lg border border-brand px-3 py-2 text-[12px] font-semibold text-brand"
                      >
                        <CreditCard className="size-3.5" />
                        Received
                      </button>
                    </div>

                    <div className="mt-3.5 rounded-xl border border-brand/20 bg-brand/5 p-3">
                      <div className="flex items-center gap-1.5 text-[9px] font-extrabold uppercase tracking-wide text-brand">
                        <Key className="size-3" />
                        Login Credentials
                      </div>
                      <div className="mt-2.5 flex items-center gap-2">
                        <div className="min-w-0 flex-1">
                          <div className="text-[8px] font-semibold uppercase text-muted-foreground">Email</div>
                          {email === undefined ? (
                            <div className="mt-0.5 flex items-center gap-1.5 text-[12px] text-muted-foreground">
                              <Loader2 className="size-3 animate-spin" /> Loading…
                            </div>
                          ) : (
                            <div className="mt-0.5 truncate text-[12px] font-semibold">{email || "Not found"}</div>
                          )}
                        </div>
                        {email && (
                          <button
                            onClick={() => navigator.clipboard.writeText(email)}
                            className="shrink-0 rounded-md border border-border p-1.5 text-muted-foreground"
                            aria-label="Copy email"
                          >
                            <Copy className="size-3.5" />
                          </button>
                        )}
                      </div>
                      <button
                        onClick={() => resetPassword(sub.user_id, name)}
                        disabled={isResetting}
                        className="mt-2.5 flex w-full items-center justify-center gap-1.5 rounded-lg border border-energy/50 py-2 text-[12px] font-semibold text-energy disabled:opacity-50"
                      >
                        {isResetting ? <Loader2 className="size-3.5 animate-spin" /> : <Key className="size-3.5" />}
                        {isResetting ? "Resetting…" : "Reset Password"}
                      </button>
                    </div>

                    <div className="mt-3.5 flex items-center justify-between">
                      <button
                        onClick={() => setEditingMember({ id: sub.user_id, full_name: profile?.full_name ?? null, phone: profile?.phone ?? null })}
                        className="flex items-center gap-1.5 rounded-lg border border-border px-3 py-2 text-[12px] font-semibold"
                      >
                        <Pencil className="size-3.5" />
                        Edit Member
                      </button>
                      <StatusMenu id={sub.id} onChange={updateStatus} />
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      <Pagination page={page} totalPages={totalPages} onPageChange={setPage} />

      <EditMemberModal member={editingMember} passes={passes} onClose={() => setEditingMember(null)} onSaved={() => router.refresh()} />

      {discountFor && (
        <DiscountModal
          sub={discountFor}
          onClose={() => setDiscountFor(null)}
          onSaved={() => {
            setDiscountFor(null);
            router.refresh();
          }}
        />
      )}

      <PaymentsModal
        open={!!paymentsFor}
        onClose={() => setPaymentsFor(null)}
        onRecorded={() => router.refresh()}
        subscriptionId={paymentsFor?.id ?? null}
        userId={paymentsFor?.user_id ?? ""}
        memberName={paymentsFor?.profiles?.full_name ?? "Member"}
        passName={paymentsFor?.gym_passes?.name ?? "Pass"}
        passPrice={paymentsFor?.gym_passes?.price ?? 0}
        discountAmount={paymentsFor?.discount_amount ?? 0}
      />

      <Modal open={!!credentials} onClose={() => setCredentials(null)}>
        {credentials && (
          <>
            <div className="flex items-center gap-3">
              <span className="grid size-9 shrink-0 place-items-center rounded-full bg-brand/12">
                <Key className="size-[18px] text-brand" />
              </span>
              <div className="text-[17px] font-bold">New Credentials</div>
            </div>
            <p className="mt-3 text-[13px] text-muted-foreground">Share these with {credentials.name}:</p>
            <div className="mt-3 flex flex-col gap-2.5">
              <CredentialRow label="Login Email" value={credentials.email} />
              <CredentialRow label="New Password" value={credentials.password} />
            </div>
            <div className="mt-3.5 rounded-lg bg-sun/10 px-3 py-2.5 text-[11px] leading-relaxed text-[#B8930A]">
              Member must change this password on first login.
            </div>
            <button onClick={() => setCredentials(null)} className="mt-4 w-full rounded-xl bg-brand py-2.5 text-[14px] font-bold text-on-brand">
              Done
            </button>
          </>
        )}
      </Modal>

      <Modal open={!!errorMessage} onClose={() => setErrorMessage(null)}>
        {errorMessage && (
          <>
            <div className="flex items-center gap-3">
              <span className="grid size-9 shrink-0 place-items-center rounded-full bg-danger/12">
                <AlertTriangle className="size-[18px] text-danger" />
              </span>
              <div className="text-[17px] font-bold">Something Went Wrong</div>
            </div>
            <p className="mt-3 text-[14px] leading-relaxed text-muted-foreground">{errorMessage}</p>
            <button onClick={() => setErrorMessage(null)} className="mt-5 w-full rounded-xl bg-brand py-2.5 text-[14px] font-bold text-on-brand">
              OK
            </button>
          </>
        )}
      </Modal>
    </div>
  );
}

function FilterChip({ label, count, active, onClick }: { label: string; count: number; active: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      aria-pressed={active}
      className={`flex shrink-0 items-center gap-1.5 rounded-full border px-3 py-1.5 text-[12.5px] font-bold ${
        active ? "border-brand bg-brand text-white" : "border-border bg-card text-muted-foreground"
      }`}
    >
      {label}
      <span className={`num rounded-full px-1.5 py-0.5 text-[9px] font-extrabold ${active ? "bg-black/15" : "bg-brand/12 text-brand"}`}>{count}</span>
    </button>
  );
}

function MiniStat({ label, value, className }: { label: string; value: string; className?: string }) {
  return (
    <div className="flex-1 text-center">
      <div className="text-[8px] font-semibold uppercase tracking-wide text-muted-foreground">{label}</div>
      <div className={`num mt-0.5 font-display text-[13px] font-bold ${className ?? ""}`}>{value}</div>
    </div>
  );
}

function Divider() {
  return <div className="w-px bg-border" />;
}

function DetailCell({
  label,
  value,
  valueClass,
  align,
}: {
  label: string;
  value: string;
  valueClass?: string;
  align?: "right";
}) {
  return (
    <div className={align === "right" ? "text-right" : ""}>
      <div className="text-[9px] font-semibold uppercase tracking-wide text-muted-foreground">{label}</div>
      <div className={`mt-0.5 text-[13px] font-semibold ${valueClass ?? ""}`}>{value}</div>
    </div>
  );
}

function CredentialRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center gap-3 rounded-lg border border-border/60 bg-background px-3 py-2.5">
      <div className="min-w-0 flex-1">
        <div className="text-[9px] font-semibold uppercase tracking-wide text-muted-foreground">{label}</div>
        <div className="mt-0.5 truncate text-[13px] font-semibold">{value}</div>
      </div>
      <button
        onClick={() => navigator.clipboard.writeText(value)}
        className="shrink-0 text-muted-foreground"
        aria-label={`Copy ${label}`}
      >
        <Copy className="size-4" />
      </button>
    </div>
  );
}

function StatusMenu({ id, onChange }: { id: string; onChange: (id: string, status: string) => void }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="relative">
      <button onClick={() => setOpen((v) => !v)} className="flex items-center gap-1 text-[12px] text-muted-foreground">
        <MoreHorizontal className="size-[18px]" />
        Change status
      </button>
      {open && (
        <>
          <div className="fixed inset-0 z-10" onClick={() => setOpen(false)} />
          <div className="absolute right-0 z-20 mt-1.5 w-36 rounded-lg border border-border bg-card py-1 shadow-lg">
            {[
              { value: "active", label: "Mark Active" },
              { value: "suspended", label: "Suspend" },
              { value: "cancelled", label: "Cancel" },
            ].map((opt) => (
              <button
                key={opt.value}
                onClick={() => {
                  onChange(id, opt.value);
                  setOpen(false);
                }}
                className="block w-full px-3 py-2 text-left text-[13px] hover:bg-muted"
              >
                {opt.label}
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  );
}

function DiscountModal({ sub, onClose, onSaved }: { sub: SubscriptionRow; onClose: () => void; onSaved: () => void }) {
  const passPrice = sub.gym_passes?.price ?? 0;
  const [isPercent, setIsPercent] = useState(false);
  const [value, setValue] = useState(sub.discount_amount ? sub.discount_amount.toFixed(0) : "");
  const [error, setError] = useState<string | null>(null);

  async function apply(amount: number) {
    // NOTE: only client-side validated (handleApply below); there is no DB
    // CHECK constraint on subscriptions.discount_amount, so re-clamp here as
    // a last line of defense before the write goes out.
    const safeAmount = Math.min(Math.max(amount, 0), passPrice);
    const supabase = createClient();
    const { error: dbError } = await supabase.from("subscriptions").update({ discount_amount: safeAmount }).eq("id", sub.id);
    if (dbError) {
      setError("Could not save the discount. Please try again.");
      return;
    }
    onSaved();
  }

  function handleApply() {
    const val = parseFloat(value);
    if (isNaN(val) || val < 0) return setError("Please enter a valid discount value.");
    if (isPercent && val > 100) return setError("Discount percentage cannot exceed 100%.");
    if (!isPercent && val > passPrice) return setError(`Discount (${formatINR(val)}) cannot exceed the pass price (${formatINR(passPrice)}).`);
    apply(isPercent ? (passPrice * val) / 100 : val);
  }

  return (
    <Modal open onClose={onClose} maxWidthClass="max-w-[380px]">
      <div className="text-[16px] font-bold">Set Discount</div>
      <div className="mt-4 flex gap-2">
        <button
          onClick={() => setIsPercent(false)}
          aria-pressed={!isPercent}
          className={`flex-1 rounded-lg border py-2.5 text-[13px] font-semibold ${!isPercent ? "border-brand bg-brand text-white" : "border-border"}`}
        >
          ₹ Amount
        </button>
        <button
          onClick={() => setIsPercent(true)}
          aria-pressed={isPercent}
          className={`flex-1 rounded-lg border py-2.5 text-[13px] font-semibold ${isPercent ? "border-brand bg-brand text-white" : "border-border"}`}
        >
          % Percent
        </button>
      </div>
      <label className="mt-3 block rounded-lg border border-border px-3 py-2.5">
        <div className="text-[11px] text-muted-foreground">{isPercent ? "Discount %" : "Discount Amount"}</div>
        <input
          autoFocus
          value={value}
          onChange={(e) => setValue(e.target.value.replace(/[^\d.]/g, ""))}
          inputMode="decimal"
          className="mt-0.5 w-full bg-transparent text-[14px] font-semibold outline-none"
        />
      </label>
      {error && <div className="mt-3 rounded-lg bg-danger/10 px-3 py-2 text-[12.5px] text-danger">{error}</div>}
      <div className="mt-4 flex gap-2">
        <button onClick={onClose} className="flex-1 rounded-lg border border-border py-2.5 text-[13px] font-semibold text-muted-foreground">
          Cancel
        </button>
        <button onClick={() => apply(0)} className="flex-1 rounded-lg py-2.5 text-[13px] font-semibold text-energy">
          Remove
        </button>
        <button onClick={handleApply} className="flex-1 rounded-lg bg-brand py-2.5 text-[13px] font-bold text-on-brand">
          Apply
        </button>
      </div>
    </Modal>
  );
}
