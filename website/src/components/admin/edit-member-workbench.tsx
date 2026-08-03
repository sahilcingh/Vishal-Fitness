"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { Pencil, Loader2, UserRound, CreditCard, Trash2, AlertTriangle } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { formatINR } from "@/lib/format";
import { initials } from "@/lib/utils";
import { fetchMemberDetail, type MemberSubscriptionDetail, type MemberPaymentDetail } from "@/lib/member-detail";
import { buildLedgerRows } from "@/lib/member-ledger-rows";
import { MemberDetailTables } from "@/components/admin/member-ledger";
import { MembersPickerPanel, type PickerMember } from "@/components/admin/members-picker-panel";
import { EditMemberModal } from "@/components/admin/edit-member-modal";
import { PaymentsModal } from "@/components/admin/payments-modal";
import { Modal } from "@/components/admin/modal";

type Pass = { id: string; name: string; price: number; duration_days: number };

function membershipNo(userId: string) {
  return `MBR-${userId.replace(/-/g, "").slice(0, 6).toUpperCase()}`;
}
function parseYMD(s: string) {
  const [y, m, d] = s.slice(0, 10).split("-").map(Number);
  return new Date(y, m - 1, d);
}
function prettyDate(s: string) {
  return parseYMD(s).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" });
}

function statusBadge(sub: MemberSubscriptionDetail) {
  const now = new Date();
  if (sub.end_date) {
    const end = parseYMD(sub.end_date);
    if (sub.status === "active" && end > now) {
      const days = Math.floor((end.getTime() - now.getTime()) / 86_400_000);
      return days <= 7
        ? { label: `${days}d left`, className: "bg-energy/15 text-energy" }
        : { label: "Active", className: "bg-brand/15 text-brand" };
    }
  }
  return { label: sub.status === "cancelled" ? "Cancelled" : "Expired", className: "bg-muted text-muted-foreground" };
}

type Detail = { profile: Awaited<ReturnType<typeof fetchMemberDetail>>["profile"]; subscriptions: MemberSubscriptionDetail[]; payments: MemberPaymentDetail[] };

export function EditMemberWorkbench({ passes, members }: { passes: Pass[]; members: PickerMember[] }) {
  const router = useRouter();
  const [selected, setSelected] = useState<PickerMember | null>(null);
  const [detail, setDetail] = useState<Detail | null>(null);
  const [loading, setLoading] = useState(false);
  // null = closed; {} = editing profile (no specific subscription); {subId} = scoped to that subscription
  const [editModal, setEditModal] = useState<{ subId?: string } | null>(null);
  const [paymentsFor, setPaymentsFor] = useState<MemberSubscriptionDetail | null>(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [deleteConfirmText, setDeleteConfirmText] = useState("");

  async function loadDetail(userId: string) {
    setLoading(true);
    try {
      const supabase = createClient();
      const result = await fetchMemberDetail(supabase, userId);
      setDetail(result);
    } finally {
      setLoading(false);
    }
  }

  function handleSelect(m: PickerMember) {
    setSelected(m);
    setDetail(null);
    loadDetail(m.id);
  }

  async function handleDeleteMember() {
    if (!selected) return;
    setDeleting(true);
    setDeleteError(null);
    try {
      const supabase = createClient();
      const { data, error } = await supabase.functions.invoke("delete-member", { body: { user_id: selected.id } });
      let result = data as { success?: boolean; error?: string } | null;
      if (error) {
        try {
          result = await (error as unknown as { context: Response }).context.json();
        } catch {
          result = { error: error.message };
        }
      }
      if (!result?.success) {
        setDeleteError(result?.error ?? "Could not delete this member. Please try again.");
        return;
      }
      setShowDeleteConfirm(false);
      setSelected(null);
      setDetail(null);
      router.refresh();
    } catch (err) {
      const msg = (err as { message?: string } | null)?.message;
      setDeleteError(msg ? `Could not delete this member: ${msg}` : "Could not delete this member. Please try again.");
    } finally {
      setDeleting(false);
    }
  }

  const name = detail?.profile?.full_name ?? selected?.full_name ?? "Member";

  return (
    <>
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-[1fr_380px]">
        <div className="flex flex-col gap-6">
          {!selected ? (
            <div className="flex flex-col items-center gap-3 rounded-[20px] border border-border bg-card px-6 py-20 text-center">
              <UserRound className="size-9 text-muted-foreground" />
              <p className="text-[13px] text-muted-foreground">Search and select a member to view and edit their details.</p>
            </div>
          ) : loading ? (
            <div className="flex items-center justify-center rounded-[20px] border border-border bg-card py-20">
              <Loader2 className="size-6 animate-spin text-brand" />
            </div>
          ) : (
            <>
              <div className="rounded-[20px] border border-border bg-card p-6 shadow-sm sm:p-7">
                <div className="flex flex-wrap items-center justify-between gap-3">
                  <div className="flex items-center gap-3">
                    <span className="grid size-12 shrink-0 place-items-center overflow-hidden rounded-full border border-border bg-brand/12 text-[15px] font-bold text-brand">
                      {detail?.profile?.photo_url ? (
                        <Image src={detail.profile.photo_url} alt="" width={48} height={48} className="size-full object-cover" />
                      ) : (
                        initials(name)
                      )}
                    </span>
                    <div className="min-w-0">
                      <div className="truncate text-[17px] font-bold">{name}</div>
                      <div className="flex flex-wrap items-center gap-1.5 text-[12px] text-muted-foreground">
                        <span className="rounded bg-brand/8 px-1.5 py-0.5 text-[10px] font-bold text-brand">{membershipNo(selected.id)}</span>
                        {selected.phone && <span>{selected.phone}</span>}
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={() => setEditModal({})}
                      className="flex items-center gap-1.5 rounded-xl bg-brand px-4 py-2.5 text-[13px] font-bold text-on-brand"
                    >
                      <Pencil className="size-3.5" />
                      Edit Profile
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setDeleteError(null);
                        setDeleteConfirmText("");
                        setShowDeleteConfirm(true);
                      }}
                      className="flex items-center gap-1.5 rounded-xl border border-danger px-4 py-2.5 text-[13px] font-bold text-danger"
                    >
                      <Trash2 className="size-3.5" />
                      Delete Member
                    </button>
                  </div>
                </div>
              </div>

              <div>
                <h2 className="mb-2.5 font-display text-[16px] font-bold">
                  Subscriptions
                  <span className="num ml-2 rounded-full bg-muted px-2 py-0.5 text-[11px] font-bold text-muted-foreground">
                    {detail?.subscriptions.length ?? 0}
                  </span>
                </h2>
                {!detail || detail.subscriptions.length === 0 ? (
                  <div className="rounded-[20px] border border-border bg-card px-6 py-10 text-center text-[13px] text-muted-foreground">
                    No subscriptions yet.
                  </div>
                ) : (
                  <div className="flex flex-col gap-2">
                    {detail.subscriptions.map((sub) => {
                      const badge = statusBadge(sub);
                      return (
                        <div key={sub.id} className="flex items-center justify-between gap-3 rounded-[16px] border border-border bg-card px-4 py-3">
                          <div className="min-w-0">
                            <div className="truncate text-[13.5px] font-bold">{sub.gym_passes?.name ?? "Pass"}</div>
                            <div className="text-[12px] text-muted-foreground">
                              {prettyDate(sub.start_date)} → {prettyDate(sub.end_date)}
                              {sub.discount_amount ? ` · ${formatINR(sub.discount_amount)} off` : ""}
                            </div>
                          </div>
                          <div className="flex shrink-0 items-center gap-2.5">
                            <span className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${badge.className}`}>{badge.label}</span>
                            <button
                              type="button"
                              onClick={() => setPaymentsFor(sub)}
                              className="flex items-center gap-1.5 rounded-lg border border-brand px-2.5 py-1.5 text-[12px] font-semibold text-brand"
                            >
                              <CreditCard className="size-3.5" />
                              Payments
                            </button>
                            <button
                              type="button"
                              onClick={() => setEditModal({ subId: sub.id })}
                              className="flex items-center gap-1.5 rounded-lg border border-border px-2.5 py-1.5 text-[12px] font-semibold"
                            >
                              <Pencil className="size-3.5" />
                              Edit
                            </button>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>

              {detail && (detail.subscriptions.length > 0 || detail.payments.length > 0) && (
                <div>
                  <h2 className="mb-2.5 font-display text-[16px] font-bold">Payment History</h2>
                  <MemberDetailTables
                    rows={buildLedgerRows(detail.subscriptions, detail.payments)}
                    openingDate={detail.profile?.created_at ?? new Date().toISOString()}
                  />
                </div>
              )}
            </>
          )}
        </div>

        <MembersPickerPanel members={members} selectedId={selected?.id ?? null} onSelect={handleSelect} />
      </div>

      <EditMemberModal
        member={editModal && selected ? { id: selected.id, full_name: selected.full_name, phone: selected.phone } : null}
        passes={passes}
        targetSubscriptionId={editModal?.subId}
        section={editModal?.subId ? "membership" : "profile"}
        onClose={() => setEditModal(null)}
        onSaved={async () => {
          if (selected) await loadDetail(selected.id);
          router.refresh();
        }}
      />

      <PaymentsModal
        open={!!paymentsFor}
        onClose={() => setPaymentsFor(null)}
        onRecorded={async () => {
          if (selected) await loadDetail(selected.id);
          router.refresh();
        }}
        subscriptionId={paymentsFor?.id ?? null}
        userId={selected?.id ?? ""}
        memberName={name}
        passName={paymentsFor?.gym_passes?.name ?? "Pass"}
        passPrice={paymentsFor?.pass_price ?? 0}
        discountAmount={paymentsFor?.discount_amount ?? 0}
      />

      <Modal open={showDeleteConfirm} onClose={() => !deleting && setShowDeleteConfirm(false)}>
        <div className="flex items-center gap-3">
          <span className="grid size-9 shrink-0 place-items-center rounded-full bg-danger/12">
            <AlertTriangle className="size-[18px] text-danger" />
          </span>
          <div className="text-[17px] font-bold">Permanently delete {name}?</div>
        </div>
        <p className="mt-3 text-[14px] leading-relaxed text-muted-foreground">
          This deletes their login, profile, subscriptions, and every payment they&apos;ve ever made -{" "}
          <span className="font-semibold text-foreground">everywhere on the site</span>, including past Daily Revenue
          and Overview totals for the months those payments were in. There is no undo, no recovery, and no trace left
          afterward.
        </p>
        <label className="mt-4 block">
          <div className="mb-1.5 text-[10px] font-semibold uppercase tracking-wide text-muted-foreground">
            Type DELETE to confirm
          </div>
          <input
            value={deleteConfirmText}
            onChange={(e) => setDeleteConfirmText(e.target.value)}
            placeholder="DELETE"
            className="h-11 w-full rounded-xl border border-border bg-background px-3.5 text-[13.5px] font-medium outline-none focus:border-danger"
          />
        </label>
        {deleteError && <div className="mt-3 rounded-lg bg-danger/10 px-3 py-2 text-[12.5px] text-danger">{deleteError}</div>}
        <div className="mt-5 flex gap-2.5">
          <button
            type="button"
            onClick={() => setShowDeleteConfirm(false)}
            disabled={deleting}
            className="flex-1 rounded-xl border border-border py-2.5 text-[14px] font-semibold text-muted-foreground disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={handleDeleteMember}
            disabled={deleting || deleteConfirmText.trim().toUpperCase() !== "DELETE"}
            className="flex-1 rounded-xl bg-danger py-2.5 text-[14px] font-bold text-white disabled:opacity-50"
          >
            {deleting ? "Deleting…" : "Permanently Delete"}
          </button>
        </div>
      </Modal>
    </>
  );
}
