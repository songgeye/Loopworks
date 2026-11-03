import Link from "next/link";

export default function HomePage() {
  return (
    <div className="mx-auto max-w-3xl space-y-4">
      <header className="rounded-3xl border border-card-line bg-card px-6 py-5 text-foreground">
        <p className="text-sm font-semibold text-accent-text">Loopworks</p>
        <h1 className="text-3xl font-bold">ホーム</h1>
      </header>

      <Link
        href="/inbounds/new"
        className="block rounded-3xl bg-accent px-6 py-8 text-center text-2xl font-bold text-accent-ink"
      >
        入庫を登録する
      </Link>
    </div>
  );
}