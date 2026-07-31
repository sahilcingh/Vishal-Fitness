"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { User, ShieldCheck, FileText, Trash2, LogOut, ChevronRight, Loader2 } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Modal } from "@/components/admin/modal";
import { EditProfileModal } from "@/components/member/edit-profile-modal";

export function SettingsSheet({
  open,
  onClose,
  name,
  photoUrl,
}: {
  open: boolean;
  onClose: () => void;
  name: string;
  photoUrl: string | null;
}) {
  const router = useRouter();
  const [editOpen, setEditOpen] = useState(false);
  const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSignOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/");
    router.refresh();
  }

  async function handleDeleteAccount() {
    setDeleteConfirmOpen(false);
    setDeleting(true);
    setError(null);
    const supabase = createClient();
    try {
      const { error: rpcErr } = await supabase.rpc("delete_user_account");
      if (rpcErr) throw rpcErr;
      await supabase.auth.signOut();
      router.push("/");
      router.refresh();
    } catch {
      setError("Could not delete your account. Please try again.");
      setDeleting(false);
    }
  }

  return (
    <>
      <Modal open={open} onClose={onClose} maxWidthClass="max-w-[400px]">
        <div className="text-[17px] font-bold">Settings &amp; Account</div>

        <div className="mt-4 flex flex-col">
          <SettingsItem
            icon={User}
            label="Edit Profile"
            onClick={() => {
              onClose();
              setEditOpen(true);
            }}
          />
          <SettingsItem icon={ShieldCheck} label="Privacy Policy" href="/member/privacy" onClick={onClose} />
          <SettingsItem icon={FileText} label="Terms of Service" href="/member/terms" onClick={onClose} />

          <div className="my-2.5 h-px bg-border" />

          <SettingsItem
            icon={deleting ? SpinningLoader : Trash2}
            label={deleting ? "Deleting…" : "Delete Account"}
            destructive
            disabled={deleting}
            onClick={() => setDeleteConfirmOpen(true)}
          />
          <SettingsItem icon={LogOut} label="Sign Out" destructive onClick={handleSignOut} />
        </div>

        {error && <div className="mt-3 rounded-xl bg-danger/10 px-3.5 py-3 text-[13px] text-danger">{error}</div>}
      </Modal>

      <Modal open={deleteConfirmOpen} onClose={() => setDeleteConfirmOpen(false)} maxWidthClass="max-w-[360px]">
        <div className="text-[17px] font-bold">Delete Account?</div>
        <p className="mt-2 text-[13px] text-muted-foreground">
          This will permanently delete your account and all data — workout history, check-ins, and profile
          information. This cannot be undone.
        </p>
        <div className="mt-5 flex justify-end gap-3">
          <button onClick={() => setDeleteConfirmOpen(false)} className="text-[13px] font-semibold text-brand">
            Keep Account
          </button>
          <button onClick={handleDeleteAccount} className="rounded-lg bg-danger px-4 py-2 text-[13px] font-bold text-white">
            Delete
          </button>
        </div>
      </Modal>

      <EditProfileModal open={editOpen} onClose={() => setEditOpen(false)} initialName={name} initialPhotoUrl={photoUrl} />
    </>
  );
}

function SpinningLoader({ className }: { className?: string }) {
  return <Loader2 className={`${className ?? ""} animate-spin`} />;
}

function SettingsItem({
  icon: Icon,
  label,
  onClick,
  href,
  destructive,
  disabled,
}: {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  onClick?: () => void;
  href?: string;
  destructive?: boolean;
  disabled?: boolean;
}) {
  const className = `flex w-full items-center gap-3 rounded-xl px-2.5 py-3 text-left text-[14px] font-medium hover:bg-muted disabled:opacity-50 ${
    destructive ? "text-danger" : "text-foreground"
  }`;

  const content = (
    <>
      <Icon className="size-[18px] shrink-0" />
      <span className="flex-1">{label}</span>
      <ChevronRight className="size-4 text-muted-foreground" />
    </>
  );

  if (href) {
    return (
      <Link href={href} onClick={onClick} className={className}>
        {content}
      </Link>
    );
  }

  return (
    <button type="button" onClick={onClick} disabled={disabled} className={className}>
      {content}
    </button>
  );
}
