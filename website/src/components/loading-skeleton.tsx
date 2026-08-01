// Shown instantly on navigation (via loading.tsx) while the real page's data
// fetch is still in flight - generic on purpose, since it has to work as a
// placeholder for every page shape in a section (grids, tables, forms).
export function LoadingSkeleton() {
  return (
    <div className="animate-pulse">
      <div className="mb-6 flex items-center gap-3">
        <div className="size-9 rounded-xl bg-muted" />
        <div className="h-6 w-40 rounded-md bg-muted" />
      </div>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {Array.from({ length: 6 }, (_, i) => (
          <div key={i} className="h-32 rounded-[20px] border border-border bg-card p-5">
            <div className="h-4 w-2/3 rounded bg-muted" />
            <div className="mt-3 h-3 w-1/2 rounded bg-muted" />
            <div className="mt-6 h-3 w-full rounded bg-muted" />
          </div>
        ))}
      </div>
    </div>
  );
}
