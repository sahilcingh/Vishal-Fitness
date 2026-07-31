import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  images: {
    // Member photos are served from Supabase Storage's public bucket URLs,
    // whose hostname depends on the project ref (env-configured, not a
    // fixed value at build time) - allow any Supabase-hosted project.
    remotePatterns: [{ protocol: "https", hostname: "**.supabase.co" }],
  },
  async headers() {
    // Baseline hardening headers only. A full Content-Security-Policy is
    // deliberately NOT set here - it requires carefully allowlisting every
    // script/style/image source this app actually uses (Supabase REST/Storage,
    // next/font-served fonts, etc.) and getting it wrong would break the site.
    // That's a separate, more careful follow-up.
    return [
      {
        source: "/:path*",
        headers: [
          { key: "X-Frame-Options", value: "DENY" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
        ],
      },
    ];
  },
};

export default nextConfig;
