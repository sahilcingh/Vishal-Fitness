import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { MemberShell } from "@/components/member/member-shell";

export const metadata: Metadata = {
  title: { default: "Member Portal - Vishal Fitness", template: "%s - Vishal Fitness" },
  robots: { index: false, follow: false },
};

export default async function MemberLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Same defense-in-depth pattern as admin/layout.tsx: the proxy only checks
  // for *any* session, so this is the real gate.
  if (!user) redirect("/login");

  const { data: profile } = await supabase
    .from("profiles")
    .select("full_name, role, photo_url")
    .eq("id", user.id)
    .maybeSingle();

  // An admin account has no member-facing data of its own - send them to
  // their real portal instead of showing an empty member experience.
  if (profile?.role === "admin") redirect("/admin");

  return (
    <MemberShell name={profile?.full_name ?? "Athlete"} email={user.email ?? ""} photoUrl={profile?.photo_url ?? null}>
      {children}
    </MemberShell>
  );
}
