"use client";

import { useRouter } from "next/navigation";
import { ArrowLeft } from "lucide-react";

const SECTIONS = [
  {
    title: "1. Data Collection",
    body: "We collect information you provide directly to us when you create an account, such as your name, email address, and workout preferences. We also store your workout logs, check-in history, and performance metrics to help you track your fitness journey.",
  },
  {
    title: "2. How We Use Data",
    body: "Your data is used to provide the core features of the app: generating your digital pass, logging your progress, and managing gym entries. We do not sell your personal data to third parties.",
  },
  {
    title: "3. Data Storage",
    body: "We use secure cloud infrastructure (Supabase) to store and protect your information. Your authentication is handled securely via encrypted protocols.",
  },
  {
    title: "4. Your Rights",
    body: 'You have the right to access, update, or delete your data at any time. You can use the "Delete Account" feature in Settings to permanently remove all your data from our systems.',
  },
  {
    title: "5. Updates",
    body: "We may update this policy from time to time. We will notify you of any significant changes by posting the new policy within the app.",
  },
];

export default function PrivacyPolicyPage() {
  const router = useRouter();

  function handleBack() {
    if (typeof window !== "undefined" && window.history.length > 1) {
      router.back();
    } else {
      router.push("/member/today");
    }
  }

  return (
    <div className="mx-auto max-w-[640px]">
      <div className="mb-6 flex items-center gap-3">
        <button
          type="button"
          onClick={handleBack}
          className="grid size-9 place-items-center rounded-xl border border-border bg-card"
          aria-label="Back"
        >
          <ArrowLeft className="size-4" />
        </button>
        <h1 className="font-display text-[24px] font-bold leading-none">Privacy Policy</h1>
      </div>

      {SECTIONS.map((s) => (
        <div key={s.title} className="mb-6">
          <h2 className="font-display text-[16px] font-bold text-brand">{s.title}</h2>
          <p className="mt-2 text-[14px] leading-relaxed text-foreground/80">{s.body}</p>
        </div>
      ))}

      <p className="mt-8 text-center text-[12px] text-muted-foreground">Last updated: April 2026</p>
    </div>
  );
}
