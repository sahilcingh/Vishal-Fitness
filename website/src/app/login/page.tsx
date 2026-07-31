import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { AuthScreen } from "@/components/login/auth-screen";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Sign In - Vishal Fitness",
  description: "Sign in to your Vishal Fitness member or staff account to book classes, view your digital pass, and manage your membership.",
};

export default async function LoginPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user) {
    const { data: profile } = await supabase.from("profiles").select("role").eq("id", user.id).maybeSingle();
    redirect(profile?.role === "admin" ? "/admin" : "/member/today");
  }

  return <AuthScreen />;
}
