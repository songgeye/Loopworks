"use client";

import { SyntheticEvent, useEffect, useState } from "react";
import Link from "next/link"; // [Next.js] 画面遷移のリンク
import { ApiError, apiFetch } from "@/lib/api";

type Item = { id: number; material_name: string; quantity_kg: number; declared_kg: number | null };
type RecordRow = {
  id: number;
  recorded_at: string;
  slip_no: string | null;
  counterparty_pic_name: string | null;
  counterparty: { id: number; name: string };
  staff: { id: number; name: string };
  items: Item[];
  total_kg: number;
  cancelled: boolean;
  editable?: boolean;
};
type ListResponse = { [key: string]: unknown; total_count: number; total_kg: number };
type Staff = { id: number; name: string };
type StockWarning = { material_id: number; name: string; shortage_kg: number };
type Props = { basePath: "/inbounds" | "/outbounds"; eyebrow: string; title: string };

const card = "rounded-3xl border border-card-line bg-card text-foreground";
const labelText = "block text-base text-foreground/60";
const field =
  "mt-2 w-full rounded-xl border border-card-line bg-card-field px-4 py-3 text-xl text-foreground focus:border-accent focus:outline-none";
const secondaryButton =
  "inline-flex items-center justify-center gap-2 rounded-2xl border border-card-line bg-card-field px-4 py-3 text-lg text-foreground hover:bg-foreground/10 disabled:opacity-30";
const primaryButton = "rounded-2xl bg-accent px-6 py-3 text-lg font-bold text-accent-ink disabled:opacity-50";
const dangerButton =
  "rounded-2xl border border-red-400/40 bg-card-field px-4 py-3 text-lg text-red-700 hover:bg-foreground/10 disabled:opacity-30 dark:text-red-300";

const formatDateTime = (iso: string) =>
  new Date(iso).toLocaleString("ja-JP", { year: "numeric", month: "numeric", day: "numeric", hour: "2-digit", minute: "2-digit" });
const formatKg = (n: number) => n.toLocaleString("ja-JP", { maximumFractionDigits: 2 });
const formatDiff = (actual: number, declared: number) => {
    const diff = Math.round((actual - declared) * 100) / 100;
    return `${diff > 0 ? "+" : ""}${formatKg(diff)}`;
};

export default function RecordList({ basePath, eyebrow, title }: Props) {
  const listKey = basePath.slice(1);

  const [data, setData] = useState<ListResponse | null>(null);
  const [staffs, setStaffs] = useState<Staff[]>([]);
  const [fromInput, setFromInput] = useState("");
  const [toInput, setToInput] = useState("");
  const [applied, setApplied] = useState({ from: "", to: "" });
  const [reloadKey, setReloadKey] = useState(0);
  const [needLogin, setNeedLogin] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [warnings, setWarnings] = useState<StockWarning[]>([]);
  const [cancelTargetId, setCancelTargetId] = useState<number | null>(null);
  const [cancelStaffId, setCancelStaffId] = useState("");
  const [cancelling, setCancelling] = useState(false);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      const query = new URLSearchParams();
      if (applied.from) query.set("from", applied.from);
      if (applied.to) query.set("to", applied.to);
      const qs = query.toString();
      try {
        const result = await apiFetch<ListResponse>(`${basePath}${qs ? `?${qs}` : ""}`);
        if (cancelled) return;
        setData(result);
        setError(null);
      } catch (err) {
        if (cancelled) return;
        if (err instanceof ApiError && err.status === 401) setNeedLogin(true);
        else if (err instanceof ApiError && err.status === 403) setError("この画面は管理者のみ利用できます");
        else setError("データの読み込みに失敗しました。しばらくしてからもう一度お試しください");
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [basePath, applied, reloadKey]);

  useEffect(() => {
    let cancelled = false;
    async function loadStaffs() {
      try {
        const result = await apiFetch<Staff[]>("/staffs");
        if (!cancelled) setStaffs(result);
      } catch {
      }
    }
    loadStaffs();
    return () => {
      cancelled = true;
    };
  }, []);

  function handleFilter(e: SyntheticEvent<HTMLFormElement>) {
    e.preventDefault();
    setApplied({ from: fromInput, to: toInput });
  }

  function handleClear() {
    setFromInput("");
    setToInput("");
    setApplied({ from: "", to: "" });
  }

  function openCancel(id: number) {
    setCancelTargetId(id);
    setCancelStaffId("");
    setError(null);
    setMessage(null);
    setWarnings([]);
  }

  async function handleCancel(id: number) {
    setCancelling(true);
    setError(null);
    try {
      const result = await apiFetch<{ id: number; warnings?: StockWarning[] }>(
        `${basePath}/${id}?staff_id=${cancelStaffId}`,
        { method: "DELETE" },
      );
      setMessage(`No.${result.id} を取り消しました`);
      setWarnings(result.warnings ?? []);
      setCancelTargetId(null);
      setReloadKey((k) => k + 1);
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        setNeedLogin(true);
      } else if (err instanceof ApiError && err.status === 403) {
        setError("この記録は取り消せません(管理者以外は、当日の記録のみ取り消せます)");
      } else if (err instanceof ApiError && err.status === 422) {
        const errors = (err.body as { errors?: string[] } | null)?.errors;
        setError(errors?.join("、") ?? "取り消せませんでした");
      } else {
        setError("通信に失敗しました。しばらくしてからもう一度お試しください");
      }
    } finally {
      setCancelling(false);
    }
  }

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

  const rows = (data?.[listKey] as RecordRow[] | undefined) ?? [];

  return (
    <div className="mx-auto max-w-4xl space-y-4">
      <header className={`${card} flex items-center justify-between gap-4 px-6 py-5`}>
        <div>
          <p className="text-sm font-semibold text-accent-text">{eyebrow}</p>
          <h1 className="text-3xl font-bold">{title}</h1>
        </div>
        <Link href={`${basePath}/new`} className={secondaryButton}>
          新規登録
        </Link>
      </header>

      <form onSubmit={handleFilter} className={`${card} grid gap-4 p-5 sm:grid-cols-[1fr_1fr_auto] sm:items-end sm:p-6`}>
        <label className={labelText}>
          開始日
          <input type="date" value={fromInput} onChange={(e) => setFromInput(e.target.value)} className={field} />
        </label>
        <label className={labelText}>
          終了日
          <input type="date" value={toInput} onChange={(e) => setToInput(e.target.value)} className={field} />
        </label>
        <div className="flex gap-2">
          <button type="submit" className={primaryButton}>
            絞り込む
          </button>
          <button type="button" onClick={handleClear} className={secondaryButton}>
            クリア
          </button>
        </div>
      </form>

      {data && (
        <div className={`${card} px-6 py-4 text-lg text-foreground/60`}>
          該当 <span className="text-2xl font-bold text-foreground">{data.total_count}</span> 件 ／ 合計{" "}
          <span className="text-2xl font-bold text-accent-text">{formatKg(data.total_kg)}</span> kg
        </div>
      )}

      {error && (
        <p role="alert" className="rounded-2xl border border-red-400/40 bg-card px-4 py-3 text-lg text-red-700 dark:text-red-300">
          {error}
        </p>
      )}
      {message && (
        <p role="status" className="rounded-2xl border border-accent/40 bg-card px-4 py-3 text-lg text-accent-text">
          {message}
        </p>
      )}
      {warnings.length > 0 && (
        <div role="alert" className="rounded-2xl border border-amber-500/40 bg-card px-4 py-3 text-lg text-amber-700 dark:text-amber-300">
          <p className="font-bold">在庫が不足しています(取り消しは完了しています)</p>
          <ul className="mt-1 list-disc pl-6">
            {warnings.map((w) => (
              <li key={w.material_id}>
                {w.name}:{formatKg(w.shortage_kg)} kg 不足
              </li>
            ))}
          </ul>
        </div>
      )}

      {data === null && !error && <div className={`${card} p-6 text-xl`}>読み込み中...</div>}
      {data && rows.length === 0 && <div className={`${card} p-6 text-xl text-foreground/60`}>該当する記録はありません</div>}

      <ul className="space-y-4">
        {rows.map((row) => (
          <li key={row.id} className={`${card} p-5 sm:p-6 ${row.cancelled ? "opacity-60" : ""}`}>
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-base text-foreground/60">
                  {formatDateTime(row.recorded_at)} ／ No.{row.id}
                  {row.slip_no ? ` ／ 伝票 ${row.slip_no}` : ""}
                </p>
                <p className="mt-1 text-2xl font-bold">{row.counterparty.name}</p>
                <p className="text-base text-foreground/60">
                  記録者 {row.staff.name}
                  {row.counterparty_pic_name ? ` ／ 先方 ${row.counterparty_pic_name}` : ""}
                </p>
              </div>
              <p className={`text-3xl font-bold text-accent-text ${row.cancelled ? "line-through" : ""}`}>
                {formatKg(row.total_kg)} <span className="text-lg">kg</span>
              </p>
            </div>

            <ul className="mt-3 space-y-1 text-lg">
            {row.items.map((item) => (
                <li key={item.id} className="flex justify-between gap-4 border-t border-card-line pt-1">
                  <span>{item.material_name}</span>
                  <span className="text-right">
                    {formatKg(item.quantity_kg)} kg
                    {item.declared_kg !== null && (
                      <span className="ml-3 text-base text-foreground/60">
                        申告 {formatKg(item.declared_kg)} kg(差 {formatDiff(item.quantity_kg, item.declared_kg)} kg)
                      </span>
                    )}
                  </span>
                </li>
            ))}
            </ul>

            <div className="mt-4">
              {row.cancelled && <span className="rounded-full border border-card-line px-3 py-1 text-base">取り消し済み</span>}

              {!row.cancelled && row.editable !== false && cancelTargetId !== row.id && (
                <button type="button" onClick={() => openCancel(row.id)} className={dangerButton}>
                  取り消し
                </button>
              )}

              {cancelTargetId === row.id && (
                <div className="space-y-3 rounded-2xl border border-red-400/40 p-4">
                  <label className={labelText}>
                    取り消す人(記録者)
                    <select value={cancelStaffId} onChange={(e) => setCancelStaffId(e.target.value)} className={field}>
                      <option value="">選択してください</option>
                      {staffs.map((s) => (
                        <option key={s.id} value={s.id}>
                          {s.name}
                        </option>
                      ))}
                    </select>
                  </label>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => handleCancel(row.id)}
                      disabled={cancelling || cancelStaffId === ""}
                      className={dangerButton}
                    >
                      {cancelling ? "取り消し中..." : "この記録を取り消す"}
                    </button>
                    <button type="button" onClick={() => setCancelTargetId(null)} className={secondaryButton}>
                      やめる
                    </button>
                  </div>
                </div>
              )}
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}