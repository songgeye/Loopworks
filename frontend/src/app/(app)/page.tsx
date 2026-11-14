"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { ApiError, apiFetch } from "@/lib/api";
import { formatKg } from "@/lib/format";
import StockDonut, { SLICE_COLORS } from "@/components/stock/StockDonut";

type Item = { id: number; material_name: string; quantity_kg: number; declared_kg: number | null };
type Row = {
  id: number;
  recorded_at: string;
  counterparty: { name: string };
  staff: { name: string };
  items: Item[];
  total_kg: number;
  cancelled: boolean;
};
type TodayResponse = { inbounds: Row[]; total_count: number; total_kg: number };

const card = "rounded-3xl border border-card-line bg-card text-foreground";
const primaryButton = "rounded-2xl bg-accent px-6 py-3 text-lg font-bold text-accent-ink";

const declaredDiff = (items: Item[]) => {
  const withDeclared = items.filter((i) => i.declared_kg !== null);
  if (withDeclared.length === 0) return null;
  const diff = withDeclared.reduce((sum, i) => sum + i.quantity_kg - (i.declared_kg ?? 0), 0);
  const rounded = Math.round(diff * 100) / 100;
  return rounded === 0 ? null : rounded;
};

const formatTime = (iso: string) =>
  new Date(iso).toLocaleTimeString("ja-JP", { hour: "2-digit", minute: "2-digit" }); // 例: 15:32

export default function HomePage() {
  const [data, setData] = useState<TodayResponse | null>(null);
  const [todayLabel, setTodayLabel] = useState("");
  const [needLogin, setNeedLogin] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      const now = new Date();
      const today = now.toLocaleDateString("sv-SE");
      try {
        const result = await apiFetch<TodayResponse>(`/inbounds?from=${today}&to=${today}`);
        if (cancelled) return;
        setTodayLabel(now.toLocaleDateString("ja-JP", { month: "long", day: "numeric", weekday: "short" }));
        setData(result);
        setError(null);
      } catch (err) {
        if (cancelled) return;
        if (err instanceof ApiError && err.status === 401) setNeedLogin(true);
        else setError("今日の記録の読み込みに失敗しました。しばらくしてからもう一度お試しください");
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, []);

  if (needLogin) {
    return (
      <div className={`${card} space-y-4 p-6`}>
        <p className="text-xl">ログインが必要です。</p>
        <Link href="/login" className={`${primaryButton} inline-block`}>
          ログインへ
        </Link>
      </div>
    );
  }

  const rows = data?.inbounds ?? [];
  const recent = rows.slice(0, 5);
  const active = rows.filter((r) => !r.cancelled);

  const totals = new Map<string, { kg: number; records: Set<number> }>();
  for (const row of active) {
    for (const item of row.items) {
      const t = totals.get(item.material_name) ?? { kg: 0, records: new Set<number>() };
      t.kg += item.quantity_kg;
      t.records.add(row.id);
      totals.set(item.material_name, t);
    }
  }
  const byMaterial = [...totals.entries()]
    .map(([name, t]) => ({ name, kg: t.kg, count: t.records.size }))
    .sort((a, b) => b.kg - a.kg);
  const maxKg = byMaterial[0]?.kg ?? 0;
  const sumKg = byMaterial.reduce((sum, m) => sum + m.kg, 0);
  const slices = byMaterial.map((m, i) => ({ name: m.name, value: m.kg, color: SLICE_COLORS[i % SLICE_COLORS.length] }));
  return (
    <div className="space-y-4">
      <header className={`${card} flex items-center justify-between gap-4 px-6 py-5`}>
        <div>
          <p className="text-sm font-semibold text-accent-text">Loopworks</p>
          <h1 className="text-3xl font-bold">ホーム</h1>
        </div>
        {todayLabel && <p className="text-xl text-foreground/60">{todayLabel}</p>}
      </header>

      {error && (
        <p role="alert" className="rounded-2xl border border-red-400/40 bg-card px-4 py-3 text-lg text-red-700 dark:text-red-300">
          {error}
        </p>
      )}

      <div className="grid gap-4 sm:grid-cols-2">
        <div className={`${card} p-6`}>
          <p className="text-lg text-foreground/60">今日の入庫の累計重量</p>
          <p className="mt-2 text-5xl font-bold text-accent-text">
            {data ? formatKg(data.total_kg) : "-"} <span className="text-xl text-foreground/60">kg</span>
          </p>
        </div>
        <div className={`${card} p-6`}>
          <p className="text-lg text-foreground/60">今日の入庫の記録件数</p>
          <p className="mt-2 text-5xl font-bold">
            {data ? data.total_count : "-"} <span className="text-xl text-foreground/60">件</span>
          </p>
        </div>
      </div>

      <Link href="/inbounds/new" className="block rounded-3xl bg-accent px-6 py-8 text-center text-2xl font-bold text-accent-ink">
        ＋ 入庫を登録する
      </Link>

      <section className={card}>
        <div className="flex items-center justify-between px-6 py-5">
          <h2 className="text-xl font-bold">最近の記録</h2>
          <Link href="/inbounds" className="text-lg text-foreground/60 hover:text-foreground">
            すべて見る ›
          </Link>
        </div>
        {data === null && !error && <p className="border-t border-card-line px-6 py-5 text-lg">読み込み中...</p>}
        {data && recent.length === 0 && (
          <p className="border-t border-card-line px-6 py-5 text-lg text-foreground/60">今日の入庫は、まだありません</p>
        )}
        <ul>
          {recent.map((row) => {
            const diff = declaredDiff(row.items);
            return (
              <li
                key={row.id}
                className={`flex items-center gap-4 border-t border-card-line px-6 py-4 ${row.cancelled ? "opacity-60" : ""}`}
              >
                <span className="w-16 shrink-0 text-lg text-foreground/60">{formatTime(row.recorded_at)}</span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-xl font-bold">
                    {row.items.map((i) => i.material_name).join("、")}
                    {row.cancelled && (
                      <span className="ml-3 rounded-full border border-card-line px-3 py-0.5 align-middle text-sm font-normal">
                        取り消し済み
                      </span>
                    )}
                  </p>
                  <p className="truncate text-base text-foreground/60">
                    {row.counterparty.name} ／ {row.staff.name}
                    {diff !== null && ` ／ 申告との差 ${diff > 0 ? "+" : ""}${formatKg(diff)} kg`}
                  </p>
                </div>
                <p className={`shrink-0 text-2xl font-bold text-accent-text ${row.cancelled ? "line-through" : ""}`}>
                  {formatKg(row.total_kg)} <span className="text-base">kg</span>
                </p>
              </li>
            );
          })}
        </ul>
      </section>

      <div className="grid gap-4 lg:grid-cols-2">
        <section className={`${card} p-6`}>
          <h2 className="text-xl font-bold">今日の品目別累計</h2>
          {data && byMaterial.length === 0 && <p className="mt-3 text-lg text-foreground/60">今日の入庫は、まだありません</p>}
          <ul className="mt-3">
            {byMaterial.map((m) => (
              <li key={m.name} className="border-t border-card-line py-3">
                <div className="flex items-baseline justify-between gap-4">
                  <span className="text-xl font-bold">{m.name}</span>
                  <span>
                    <span className="text-2xl font-bold text-accent-text">{formatKg(m.kg)}</span> kg{" "}
                    <span className="text-base text-foreground/60">{m.count}件</span>
                  </span>
                </div>
                <div className="mt-2 h-2.5 overflow-hidden rounded-full bg-card-field" aria-hidden="true">
                  <div className="h-full rounded-full bg-accent" style={{ width: `${maxKg > 0 ? (m.kg / maxKg) * 100 : 0}%` }} />
                </div>
              </li>
            ))}
          </ul>
        </section>

        <section className={`${card} p-6`}>
          <h2 className="text-xl font-bold">今日の品目別構成比</h2>
          {sumKg === 0 ? (
            <p className="mt-3 text-lg text-foreground/60">表示できる記録がありません</p>
          ) : (
            <div className="mt-6 flex flex-col items-center gap-6 sm:flex-row sm:justify-center">
              <StockDonut slices={slices} total={sumKg} centerLabel={formatKg(sumKg)} />
              <ul className="space-y-2">
                {slices.map((s) => (
                  <li key={s.name} className="flex items-center gap-3 text-lg">
                    <span className="h-3 w-3 shrink-0 rounded-full" style={{ backgroundColor: s.color }} aria-hidden="true" />
                    <span className="min-w-28">{s.name}</span>
                    <span className="ml-auto font-bold">{((s.value / sumKg) * 100).toFixed(1)}%</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </section>
      </div>
    </div>
  );
}