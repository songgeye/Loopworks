"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { ApiError, apiFetch } from "@/lib/api";

type Stock = {
  material_id: number;
  name: string;
  quantity_kg: number;
  stock_target: number | string | null;
};

const card = "rounded-3xl border border-card-line bg-card text-foreground";
const secondaryButton =
  "inline-flex items-center justify-center gap-2 rounded-2xl border border-card-line bg-card-field px-4 py-3 text-lg text-foreground hover:bg-foreground/10";
const primaryButton = "rounded-2xl bg-accent px-6 py-3 text-lg font-bold text-accent-ink";

const formatKg = (n: number) => n.toLocaleString("ja-JP", { maximumFractionDigits: 2 });

const toTarget = (value: Stock["stock_target"]): number | null => {
  if (value === null || value === undefined) return null;
  const n = Number(value);
  return Number.isFinite(n) && n > 0 ? n : null;
};

export default function StockPage() {
  const [stocks, setStocks] = useState<Stock[] | null>(null);
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

  if (needLogin) {
    return (
      <div className={`${card} mx-auto max-w-4xl space-y-4 p-6`}>
        <p className="text-xl">ログインが必要です。</p>
        <Link href="/login" className={`${primaryButton} inline-block`}>
          ログインへ
        </Link>
      </div>
    );
  }

  const total = (stocks ?? []).reduce((sum, s) => sum + s.quantity_kg, 0);

  return (
    <div className="mx-auto max-w-4xl space-y-4">
      <header className={`${card} flex items-center justify-between gap-4 px-6 py-5`}>
        <div>
          <p className="text-sm font-semibold text-accent-text">在庫管理</p>
          <h1 className="text-3xl font-bold">在庫の一覧</h1>
        </div>
        <button type="button" onClick={() => setReloadKey((k) => k + 1)} className={secondaryButton}>
          再読み込み
        </button>
      </header>

      {stocks && (
        <div className={`${card} px-6 py-4 text-lg text-foreground/60`}>
          {stocks.length} 種類 ／ 在庫の合計{" "}
          <span className="text-2xl font-bold text-accent-text">{formatKg(total)}</span> kg
        </div>
      )}

      {error && (
        <p role="alert" className="rounded-2xl border border-red-400/40 bg-card px-4 py-3 text-lg text-red-700 dark:text-red-300">
          {error}
        </p>
      )}

      {stocks === null && !error && <div className={`${card} p-6 text-xl`}>読み込み中...</div>}
      {stocks && stocks.length === 0 && <div className={`${card} p-6 text-xl text-foreground/60`}>材料が登録されていません</div>}

      <ul className="space-y-4">
        {(stocks ?? []).map((s) => {
          const target = toTarget(s.stock_target);
          const negative = s.quantity_kg < 0;
          const percent = target ? Math.min(100, Math.max(0, (s.quantity_kg / target) * 100)) : 0;
          const reached = target !== null && s.quantity_kg >= target;

          return (
            <li key={s.material_id} className={`${card} p-5 sm:p-6`}>
              <div className="flex items-start justify-between gap-4">
                <p className="text-2xl font-bold">{s.name}</p>
                <p className={`text-3xl font-bold ${negative ? "text-red-700 dark:text-red-300" : "text-accent-text"}`}>
                  {formatKg(s.quantity_kg)} <span className="text-lg">kg</span>
                </p>
              </div>

              {negative && (
                <p className="mt-2 text-lg text-red-700 dark:text-red-300">在庫がマイナスです。入庫・出庫の記録を確認してください</p>
              )}

              {target !== null && (
                <div className="mt-3">
                  <div className="h-3 overflow-hidden rounded-full bg-card-field" aria-hidden="true">
                    <div className="h-full rounded-full bg-accent" style={{ width: `${percent}%` }} />
                  </div>
                  <p className="mt-1 flex justify-between text-base text-foreground/60">
                    <span>目標 {formatKg(target)} kg</span>
                    <span>{reached ? "目標に達しています" : `目標まで あと ${formatKg(target - s.quantity_kg)} kg`}</span>
                  </p>
                </div>
              )}
            </li>
          );
        })}
      </ul>
    </div>
  );
}