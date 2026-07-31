import type { Metadata } from "next";
import Script from "next/script";
import { Inter, Space_Grotesk } from "next/font/google";
import { ThemeProvider } from "@/components/theme-provider";
import { ThemeToggle } from "@/components/theme-toggle";
import "./globals.css";

const bodyFont = Inter({
  variable: "--font-body",
  subsets: ["latin"],
});

const displayFont = Space_Grotesk({
  variable: "--font-display",
  subsets: ["latin"],
  weight: ["400", "500", "700"],
});

export const metadata: Metadata = {
  // TODO: set real production URL once the site is deployed to its final domain.
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "https://www.vishalfitness.com"),
  title: "Vishal Fitness - Admin Portal",
  description: "Manage members, subscriptions, revenue and classes for Vishal Fitness.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${bodyFont.variable} ${displayFont.variable} h-full antialiased`}
      suppressHydrationWarning
    >
      <body className="min-h-full flex flex-col font-sans">
        {/* Light is always the default on a fresh page load - clears any
            previously-saved theme choice before next-themes' own hydration
            script (which reads that same "theme" key) gets a chance to run,
            so a prior visit's dark toggle never carries over. Toggling still
            works normally for the rest of that page's session - this only
            resets on the next real navigation/reload. */}
        <Script id="force-light-default" strategy="beforeInteractive">
          {`try { localStorage.removeItem("theme"); } catch (e) {}`}
        </Script>
        <ThemeProvider attribute="class" defaultTheme="light" enableSystem={false}>
          {children}
          {/* Rendered once, globally, so it sits in the same screen position
              on every page - public, login, admin, and member alike. */}
          <div className="fixed bottom-4 right-4 z-50">
            <ThemeToggle />
          </div>
        </ThemeProvider>
      </body>
    </html>
  );
}
