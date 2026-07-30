import { AdminSidebar } from "@/components/admin/sidebar";
import { createClient } from "@/lib/supabase/server";

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  let fullName: string | null = null;
  if (user) {
    const { data: profile } = await supabase
      .from("profiles")
      .select("full_name")
      .eq("id", user.id)
      .maybeSingle();
    fullName = profile?.full_name ?? null;
  }

  return (
    <div className="flex min-h-screen flex-col md:flex-row">
      <AdminSidebar name={fullName ?? "Admin"} email={user?.email ?? ""} />
      <main className="mx-auto w-full max-w-[1180px] flex-1 px-5 py-7 md:px-8">{children}</main>
    </div>
  );
}
