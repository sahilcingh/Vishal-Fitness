export type InstallmentInput = { amountNum: number };

// Clamps each row's amount against what's left of `cap` after every row
// before it - a cumulative clamp, not a per-row one, so N individually-
// plausible amounts can never sum past the cap even though each one alone
// might fit within it. NOTE: only client-side validated; add a CHECK
// constraint on payments.amount at the DB level for a real backstop.
export function clampInstallments<T extends InstallmentInput>(rows: T[], cap: number): (T & { safeAmount: number })[] {
  return rows.reduce<(T & { safeAmount: number })[]>((acc, r) => {
    const used = acc.reduce((sum, x) => sum + x.safeAmount, 0);
    const room = Math.max(cap - used, 0);
    const safeAmount = Math.min(Math.max(r.amountNum, 0), room);
    return [...acc, { ...r, safeAmount }];
  }, []);
}
