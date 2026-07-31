"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Pencil, UserRound } from "lucide-react";
import { initials } from "@/lib/utils";
import { EditMemberModal, type EditableMember } from "@/components/admin/edit-member-modal";

type Pass = { id: string; name: string; price: number; duration_days: number };

type RecentMember = EditableMember & {
  created_at: string;
  subscriptions: {
    id: string;
    pass_id: string | null;
    status: string;
    start_date: string;
    pass: { name: string | null } | null;
  }[];
};

function timeAgo(iso: string) {
  const diffMs = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diffMs / 60_000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d ago`;
  return new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
}

export function RecentAdditions({ members, passes }: { members: RecentMember[]; passes: Pass[] }) {
  const router = useRouter();
  const [editing, setEditing] = useState<RecentMember | null>(null);

  return (
    <>
      <div className="rounded-[20px] border border-border bg-card p-5 shadow-sm">
        <h3 className="font-display text-[16px] font-bold">Recent Additions</h3>
        <p className="mt-0.5 text-[12px] text-muted-foreground">Newest members — click to edit</p>

        {members.length === 0 ? (
          <p className="py-8 text-center text-[13px] text-muted-foreground">No members added yet.</p>
        ) : (
          <ul className="mt-4 flex flex-col gap-1.5">
            {members.map((m) => {
              const sub = m.subscriptions[0];
              return (
                <li key={m.id}>
                  <button
                    onClick={() => setEditing(m)}
                    className="group flex w-full items-center gap-3 rounded-xl px-2.5 py-2.5 text-left hover:bg-muted"
                  >
                    <span className="grid size-9 shrink-0 place-items-center rounded-full bg-brand/12 text-[12px] font-bold text-brand">
                      {m.full_name ? initials(m.full_name) : <UserRound className="size-4" />}
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-[13.5px] font-bold">{m.full_name || "Member"}</span>
                      <span className="block truncate text-[11.5px] text-muted-foreground">
                        {m.phone} {sub?.pass?.name ? `· ${sub.pass.name}` : ""}
                      </span>
                    </span>
                    <span className="shrink-0 text-[10.5px] text-muted-foreground">{timeAgo(m.created_at)}</span>
                    <Pencil className="size-3.5 shrink-0 text-muted-foreground opacity-0 group-hover:opacity-100" />
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      <EditMemberModal
        member={editing}
        passes={passes}
        onClose={() => setEditing(null)}
        onSaved={() => router.refresh()}
      />
    </>
  );
}
