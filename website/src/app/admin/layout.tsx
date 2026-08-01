import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { AdminSidebar } from "@/components/admin/sidebar";
import { PageTransition } from "@/components/page-transition";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = {
  robots: { index: false, follow: false },
};

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  // The proxy only checks for *any* authenticated session - it never verifies
  // role, so this is the actual admin gate. Without it, any authenticated
  // member could load every /admin/* page, same as the role check already
  // enforced at sign-in in LoginForm.
  if (!user) redirect("/login");

  const { data: profile } = await supabase.from("profiles").select("full_name, role").eq("id", user.id).maybeSingle();

  // A validly-authenticated member, just not an admin - send them to their
  // own portal rather than signing them out (that guard only applies to the
  // "Staff" sign-in path itself, in LoginForm).
  if (profile?.role !== "admin") redirect("/member/today");

  const fullName = profile?.full_name ?? null;

  return (
    <div className="flex min-h-screen flex-col md:flex-row">
      <AdminSidebar name={fullName ?? "Admin"} email={user?.email ?? ""} />
      <main className="mx-auto w-full max-w-[1180px] flex-1 px-5 py-7 md:px-8">
        <PageTransition>{children}</PageTransition>
      </main>
    </div>
  );
}
