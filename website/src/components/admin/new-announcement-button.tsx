"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Plus } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { Modal } from "@/components/admin/modal";

// Mirrors _showAddAnnouncementDialog() in admin_announcements_screen.dart:
// a Title field + 3-line Message field, inserted as
// { title, message, created_by } with no explicit is_active (DB default applies).
const TITLE_MAX = 120;
const MESSAGE_MAX = 500;

export function NewAnnouncementButton({ createdBy }: { createdBy: string | null }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function close() {
    setOpen(false);
    setTitle("");
    setMessage("");
    setError(null);
  }

  async function handlePost() {
    // Flutter only checks raw (untrimmed) emptiness before allowing the post,
    // which lets a whitespace-only title/message through and then trims it to
    // an empty string on insert. Guard against that here instead of copying
    // the bug forward.
    if (!title.trim() || !message.trim()) return;

    setIsSubmitting(true);
    setError(null);
    const supabase = createClient();
    try {
      // The inputs' maxLength attributes are HTML-only and trivially bypassed
      // via devtools/a direct REST call — re-truncate here right before the
      // payload is built so an oversized value can't reach the DB through
      // this form. NOTE: only client-side validated; add a CHECK constraint
      // (or column length limit) on announcements.title / .message at the DB
      // level for a real backstop.
      const { error: insertError } = await supabase.from("announcements").insert({
        title: title.trim().slice(0, TITLE_MAX),
        message: message.trim().slice(0, MESSAGE_MAX),
        created_by: createdBy,
      });
      if (insertError) throw insertError;
      close();
      router.refresh();
    } catch (err) {
      const detail = err instanceof Error ? err.message : String(err);
      setError(`Could not post the announcement: ${detail}`);
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        className="flex items-center gap-2 rounded-xl bg-brand px-4 py-2.5 text-[13px] font-bold text-on-brand"
      >
        <Plus className="size-[15px]" />
        New Announcement
      </button>

      <Modal open={open} onClose={close}>
        <div className="text-[17px] font-bold">New Announcement</div>

        <div className="mt-4 flex flex-col gap-3">
          <label className="flex flex-col gap-1.5">
            <span className="text-[11px] text-muted-foreground">Title</span>
            <input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              maxLength={TITLE_MAX}
              className="rounded-xl border border-border bg-background px-3.5 py-2.5 text-[14px] font-medium outline-none focus:border-brand"
            />
          </label>
          <label className="flex flex-col gap-1.5">
            <span className="text-[11px] text-muted-foreground">Message</span>
            <textarea
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              rows={3}
              maxLength={MESSAGE_MAX}
              className="resize-none rounded-xl border border-border bg-background px-3.5 py-2.5 text-[14px] font-medium outline-none focus:border-brand"
            />
          </label>
        </div>

        {error && (
          <div className="mt-3 rounded-xl bg-danger/10 px-3.5 py-2.5 text-[13px] text-danger">{error}</div>
        )}

        <div className="mt-5 flex justify-end gap-2.5">
          <button
            onClick={close}
            className="rounded-xl border border-border px-4 py-2.5 text-[13px] font-semibold text-muted-foreground"
          >
            Cancel
          </button>
          <button
            onClick={handlePost}
            disabled={isSubmitting || !title.trim() || !message.trim()}
            className="rounded-xl bg-brand px-4 py-2.5 text-[13px] font-bold text-on-brand disabled:opacity-50"
          >
            {isSubmitting ? "Posting…" : "Post"}
          </button>
        </div>
      </Modal>
    </>
  );
}
