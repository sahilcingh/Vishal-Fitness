// Server Components run on whatever timezone the deploy host uses (Vercel
// defaults to UTC), but every "today"/"this month" boundary in this app needs
// to reflect the gym's actual local day (India, IST, UTC+5:30, no DST) — not
// the server's OS timezone. `new Date()` + local getters (getFullYear/
// getMonth/getDate/getHours) silently give the wrong calendar day for part of
// every night once deployed.
//
// Two different needs, two different functions — do not mix them up:
//   - nowInIST() gives you a Date whose LOCAL GETTERS (getFullYear, getMonth,
//     getDate, getHours, getDay, ...) read as IST wall-clock time. Use it for
//     "what calendar day/hour is it right now" — display text, weekday
//     checks, or as the y/m/d input to istMidnightMs() below.
//     Its own .getTime()/.toISOString() are NOT a real instant — constructing
//     a Date from plain numbers always interprets them via the server's own
//     timezone, so do not use this for timestamp comparisons.
//   - istMidnightMs(year, month, day) gives you the real, correct epoch
//     millisecond value for midnight IST on that calendar day — safe to feed
//     into `.toISOString()` / compare against a timestamptz column.
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

export function nowInIST(): Date {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Kolkata",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).formatToParts(new Date());

  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value ?? "0");
  // Intl can report hour "24" for midnight with hour12:false — normalize to 0.
  const hour = get("hour") % 24;

  return new Date(get("year"), get("month") - 1, get("day"), hour, get("minute"), get("second"));
}

export function istMidnightMs(year: number, month: number, day: number): number {
  return Date.UTC(year, month, day) - IST_OFFSET_MS;
}

// Which IST calendar day does this arbitrary timestamp fall on — for
// bucketing rows (check-ins, workouts) by "day" the way a person in India
// would read them, regardless of server timezone.
export function istDayKey(iso: string): string {
  // en-CA formats as YYYY-MM-DD directly.
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Kolkata" }).format(new Date(iso));
}
