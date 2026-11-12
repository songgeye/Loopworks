"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { ApiError, apiFetch } from "@/lib/api";
import { formatKg } from "@/lib/format";
import { useRole } from "@/lib/useRole";
import AdjustmentForm from "@/components/stock/AdjustmentForm";
import StockDonut, { SLICE_COLORS } from "@/components/stock/StockDonut";

type Stock = { material_id: number; name: string; quantity_kg: number };
type Summary = { counterparty_id: number; name: string; total_kg: number; count: number };

const card = "rounded-3xl border border-card-line bg-card text-foreground";
const primaryButton = "rounded-2xl bg-accent px-6 py-3 text-lg font-bold text-accent-ink";

export default function StockPage() {
  const isAdmin = useRole() === "admin";

  const [stocks, setStocks] = useState<Stock[] | null>(null);
  const [summaries, setSummaries] = useState<Summary[] | null>(null);
  const [summaryError, setSummaryError] = useState(false);
  const [needLogin, setNeedLogin] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const result = await apiFetch<Stock[]>("/current_materials");
        if (cancelled) return;
        setStocks(result);
        setError(null);
      } catch (err) {
        if (cancelled) return;
        if (err instanceof ApiError && err.status === 401) setNeedLogin(true);
        else setError("在庫の読み込みに失敗しました。しばらくしてからもう一度お試しください");
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [reloadKey]);

  useEffect(() => {
    if (!isAdmin) return;
    let cancelled = false;
    async function loadSummaries() {
      try {
        const result = await apiFetch<{ summaries: Summary[] }>("/counterparty_inbound_summaries");
        if (cancelled) return;
        setSummaries(result.summaries);
        setSummaryError(false);
      } catch {
        if (!cancelled) setSummaryError(true);
      }
    }
    loadSummaries();
    return () => {
      cancelled = true;
    };
  }, [isAdmin, reloadKey]);

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

  const list = stocks ?? [];
  const total = list.reduce((sum, s) => sum + s.quantity_kg, 0);
  const negativeCount = list.filter((s) => s.quantity_kg < 0).length;
  const maxQuantity = Math.max(0, ...list.map((s) => s.quantity_kg));

  const slices = list
    .map((s, i) => ({ name: s.name, value: s.quantity_kg, color: SLICE_COLORS[i % SLICE_COLORS.length] }))
    .filter((s) => s.value > 0);
  const positiveTotal = slices.reduce((sum, s) => sum + s.value, 0);

  return (
    <div className="space-y-4">
      <header className={`${card} flex items-center justify-between gap-4 px-6 py-5`}>
        <div>
          <p className="text-sm font-semibold text-accent-text">在庫管理</p>
          <h1 className="text-3xl font-bold">在庫一覧</h1>
        </div>
        {isAdmin && (
          <Link href="/outbounds/new" className={primaryButton}>
            ＋ 出庫を登録
          </Link>
        )}
      </header>

      {isAdmin && stocks && <AdjustmentForm materials={stocks} onDone={() => setReloadKey((k) => k + 1)} />}

      {error && (
        <p role="alert" className="rounded-2xl border border-red-400/40 bg-card px-4 py-3 text-lg text-red-700 dark:text-red-300">
          {error}
        </p>
      )}
      {stocks === null && !error && <div className={`${card} p-6 text-xl`}>読み込み中...</div>}

      {stocks && (
        <>
          <div className="grid gap-4 sm:grid-cols-2">
            <div className={`${card} p-6`}>
              <p className="text-lg text-foreground/60">在庫の累計重量(全品目合計)</p>
              <p className="mt-2 text-5xl font-bold text-accent-text">
                {formatKg(total)} <span className="text-xl text-foreground/60">kg</span>
              </p>
            </div>
            <div className={`${card} p-6`}>
              <p className="text-lg text-foreground/60">マイナス在庫の品目数</p>
              <p className={`mt-2 text-5xl font-bold ${negativeCount > 0 ? "text-red-700 dark:text-red-300" : ""}`}>
                {negativeCount} <span className="text-xl text-foreground/60">品目</span>
              </p>
            </div>
          </div>

          {isAdmin && (
            <section className={`${card} p-6`}>
              <h2 className="text-xl font-bold">持込元別の累計受入重量(全期間)</h2>
              {summaryError && <p className="mt-3 text-lg text-red-700 dark:text-red-300">読み込みに失敗しました</p>}
              {summaries && summaries.length === 0 && <p className="mt-3 text-lg text-foreground/60">入庫の記録がありません</p>}
              <ul className="mt-3 grid gap-x-8 sm:grid-cols-2">
                {(summaries ?? []).map((s) => (
                  <li key={s.counterparty_id} className="flex items-baseline justify-between gap-4 border-t border-card-line py-3">
                    <span className="text-xl font-bold">{s.name}</span>
                    <span>
                      <span className="text-2xl font-bold text-accent-text">{formatKg(s.total_kg)}</span> kg{" "}
                      <span className="text-base text-foreground/60">{s.count}件</span>
                    </span>
                  </li>
                ))}
              </ul>
            </section>
          )}

          <div className="grid gap-4 lg:grid-cols-2">
            <section className={`${card} p-6`}>
              <h2 className="text-xl font-bold">品目別の在庫</h2>
              {list.length === 0 && <p className="mt-3 text-lg text-foreground/60">材料が登録されていません</p>}
              <ul className="mt-3">
                {list.map((s) => {
                  const negative = s.quantity_kg < 0;
                  const percent = maxQuantity > 0 && !negative ? (s.quantity_kg / maxQuantity) * 100 : 0;
                  return (
                    <li key={s.material_id} className="border-t border-card-line py-3">
                      <div className="flex items-baseline justify-between gap-4">
                        <span className="text-xl font-bold">{s.name}</span>
                        <span className={negative ? "text-red-700 dark:text-red-300" : "text-accent-text"}>
                          <span className="text-2xl font-bold">{formatKg(s.quantity_kg)}</span> kg
                        </span>
                      </div>
                      <div className="mt-2 h-2.5 overflow-hidden rounded-full bg-card-field" aria-hidden="true">
                        <div className="h-full rounded-full bg-accent" style={{ width: `${percent}%` }} />
                      </div>
                      {negative && (
                        <p className="mt-1 text-base text-red-700 dark:text-red-300">
                          在庫がマイナスです。入庫・出庫の記録を確認してください
                        </p>
                      )}
                    </li>
                  );
                })}
              </ul>
            </section>

            <section className={`${card} p-6`}>
              <h2 className="text-xl font-bold">在庫全体の構成比</h2>
              {positiveTotal === 0 ? (
                <p className="mt-3 text-lg text-foreground/60">表示できる在庫がありません</p>
              ) : (
                <div className="mt-6 flex flex-col items-center gap-6 sm:flex-row sm:justify-center">
                  <StockDonut slices={slices} total={positiveTotal} centerLabel={formatKg(positiveTotal)} />
                  <ul className="space-y-2">
                    {slices.map((s) => (
                      <li key={s.name} className="flex items-center gap-3 text-lg">
                        <span className="h-3 w-3 shrink-0 rounded-full" style={{ backgroundColor: s.color }} aria-hidden="true" />
                        <span className="min-w-28">{s.name}</span>
                        <span className="ml-auto font-bold">{((s.value / positiveTotal) * 100).toFixed(1)}%</span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </section>
          </div>
        </>
      )}
    </div>
  );
}