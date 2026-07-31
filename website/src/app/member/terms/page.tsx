"use client";

import { useRouter } from "next/navigation";
import { ArrowLeft } from "lucide-react";

const SECTIONS = [
  {
    title: "1. Acceptance of Terms",
    body: "By creating an account and using the Vishal Fitness app, you agree to comply with and be bound by these Terms of Service. If you do not agree, please do not use the application.",
  },
  {
    title: "2. Gym Entry & Pass",
    body: "Your digital pass is personal to you and cannot be shared. Misuse of the QR code for unauthorized entry may result in account suspension.",
  },
  {
    title: "3. Health & Safety",
    body: "Fitness activities involve inherent risks. By using this app to log workouts or book classes, you acknowledge that you are in good health and have consulted with a medical professional if necessary. Vishal Fitness is not responsible for injuries sustained during training.",
  },
  {
    title: "4. Account Security",
    body: "You are responsible for maintaining the confidentiality of your account. You agree to notify us immediately of any unauthorized use of your account.",
  },
  {
    title: "5. Termination",
    body: "We reserve the right to terminate or suspend access to our service immediately, without prior notice, for any reason whatsoever, including breach of terms.",
  },
];

export default function TermsOfServicePage() {
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
        <h1 className="font-display text-[24px] font-bold leading-none">Terms of Service</h1>
      </div>

      {SECTIONS.map((s) => (
        <div key={s.title} className="mb-6">
          <h2 className="font-display text-[16px] font-bold text-energy">{s.title}</h2>
          <p className="mt-2 text-[14px] leading-relaxed text-foreground/80">{s.body}</p>
        </div>
      ))}

      <p className="mt-8 text-center text-[12px] text-muted-foreground">Last updated: April 2026</p>
    </div>
  );
}
