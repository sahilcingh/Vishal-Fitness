import { AdminSidebar } from "@/components/admin/sidebar";

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col md:flex-row">
      <AdminSidebar />
      <main className="mx-auto w-full max-w-[1180px] flex-1 px-5 py-7 md:px-8">{children}</main>
    </div>
  );
}
