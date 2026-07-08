export function ConnectionBanner({ connected }: { connected: boolean }) {
  if (connected) return null;
  return (
    <div className="banner" role="status">
      Немає з&apos;єднання — показано останні відомі дані.
    </div>
  );
}
