export function formatINR(amount: number): string {
  return `₹${Math.round(amount).toLocaleString("en-IN")}`;
}

// Compact Indian-style denomination (thousand/lakh) for tight spaces like
// chart bar labels, where formatINR's full grouped digits don't fit.
export function formatINRCompact(amount: number): string {
  const abs = Math.abs(amount);
  if (abs >= 10_00_000) return `₹${(amount / 10_00_000).toFixed(abs >= 1_00_00_000 ? 0 : 1)}L`;
  if (abs >= 1_000) return `₹${(amount / 1_000).toFixed(abs >= 10_000 ? 0 : 1)}k`;
  return `₹${Math.round(amount)}`;
}
