"use client";

import { SyntheticEvent, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { Plus, Trash2 } from "lucide-react";
import { ApiError, apiFetch } from "@/lib/api";

type Counterparty = { id: number; name: string };
type Staff = { id: number; name: string };
type Material = { id: number; name: string };
type StockWarning = { material_id: number; name: string; shortage_kg: number };
type Row = { key: number; materialId: string; quantityKg: string; declaredKg: string };
const emptyRow = (key: number): Row => ({ key, materialId: "", quantityKg: "", declaredKg: "" });

const card = "rounded-3xl border border-card-line bg-card text-foreground";
const labelText = "block text-base text-foreground/60";
const field =
  "mt-2 w-full rounded-xl border border-card-line bg-card-field px-4 py-3 text-xl text-foreground placeholder:text-foreground/30 focus:border-accent focus:outline-none";
const secondaryButton =
  "inline-flex items-center gap-2 rounded-2xl border border-card-line bg-card-field px-4 py-3 text-lg text-foreground hover:bg-foreground/10 disabled:opacity-30";
const primaryButton =
  "rounded-2xl bg-accent px-6 py-4 text-xl font-bold text-accent-ink disabled:opacity-50";

export default function NewOutboundPage() {
  const [counterparties, setCounterparties] = useState<Counterparty[]>([]);
  const [staffs, setStaffs] = useState<Staff[]>([]);
  const [materials, setMaterials] = useState<Material[]>([]);
  const [loadingData, setLoadingData] = useState(true);
  const [needLogin, setNeedLogin] = useState(false);

  const [counterpartyId, setCounterpartyId] = useState("");
  const [staffId, setStaffId] = useState("");
  const [picName, setPicName] = useState("");
  const [slipNo, setSlipNo] = useState("");
  const nextKey = useRef(1);
  const [rows, setRows] = useState<Row[]>([emptyRow(0)]);

  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [warnings, setWarnings] = useState<StockWarning[]>([]);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const [c, s, m] = await Promise.all([
          apiFetch<Counterparty[]>("/counterparties"),
          apiFetch<Staff[]>("/staffs"),
          apiFetch<Material[]>("/materials"),
        ]);
        if (cancelled) return;
        setCounterparties(c);
        setStaffs(s);
        setMaterials(m);
      } catch (err) {
        if (cancelled) return;
        if (err instanceof ApiError && err.status === 401) setNeedLogin(true);
        else setError("データの読み込みに失敗しました。しばらくしてからもう一度お試しください");
      } finally {
        if (!cancelled) setLoadingData(false);
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, []);

  function updateRow(key: number, patch: Partial<Row>) {
    setRows((prev) => prev.map((r) => (r.key === key ? { ...r, ...patch } : r)));
  }
  function addRow() {
    setRows((prev) => [...prev, emptyRow(nextKey.current++)]);
  }
  function removeRow(key: number) {
    setRows((prev) => (prev.length === 1 ? prev : prev.filter((r) => r.key !== key)));
  }

  const totalKg = rows.reduce((sum, r) => sum + (Number(r.quantityKg) || 0), 0);

  async function handleSubmit(e: SyntheticEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    setMessage(null);
    setWarnings([]);
    setSubmitting(true);
    try {
      const result = await apiFetch<{ id: number; warnings?: StockWarning[] }>("/outbounds", {
        method: "POST",
        body: JSON.stringify({
          outbound: {
            counterparty_id: Number(counterpartyId),
            staff_id: Number(staffId),
            counterparty_pic_name: picName || null,
            slip_no: slipNo || null,
            outbounds_materials_attributes: rows.map((r) => ({
              material_id: Number(r.materialId),
              quantity_kg: Number(r.quantityKg),
              declared_kg: r.declaredKg === "" ? null : Number(r.declaredKg),
            })),
          },
        }),
      });
      setMessage(`出庫を登録しました(No.${result.id})`);
      setWarnings(result.warnings ?? []);
      setCounterpartyId("");
      setPicName("");
      setSlipNo("");
      nextKey.current = 1;
      setRows([emptyRow(0)]);
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        setNeedLogin(true);
      } else if (err instanceof ApiError && err.status === 403) {
        setError("出庫の登録は管理者のみ行えます。管理者でログインしてください");
      } else if (err instanceof ApiError && err.status === 422) {
        const errors = (err.body as { errors?: string[] } | null)?.errors;
        setError(errors?.join("、") ?? "入力内容に誤りがあります");
      } else {
        setError("通信に失敗しました。しばらくしてからもう一度お試しください");
      }
    } finally {
      setSubmitting(false);
    }
  }

  if (loadingData) {
    return <div className={`${card} p-6 text-xl`}>読み込み中...</div>;
  }

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

  return (
    <div className="space-y-4">
      <header className={`${card} px-6 py-5`}>
        <p className="text-sm font-semibold text-accent-text">出庫管理</p>
        <h1 className="text-3xl font-bold">出庫の登録</h1>
      </header>

      <form onSubmit={handleSubmit} className="space-y-4">
        <section className={`${card} grid gap-4 p-5 sm:grid-cols-2 sm:p-6`}>
          <label className={labelText}>
            取引先
            <select value={counterpartyId} onChange={(e) => setCounterpartyId(e.target.value)} required className={field}>
              <option value="">選択してください</option>
              {counterparties.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </label>

          <label className={labelText}>
            記録者
            <select value={staffId} onChange={(e) => setStaffId(e.target.value)} required className={field}>
              <option value="">選択してください</option>
              {staffs.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </label>

          <label className={labelText}>
            先方の担当者名(任意)
            <input type="text" value={picName} onChange={(e) => setPicName(e.target.value)} className={field} />
          </label>

          <label className={labelText}>
            伝票番号(任意)
            <input type="text" value={slipNo} onChange={(e) => setSlipNo(e.target.value)} className={field} />
          </label>
        </section>

        <section className={`${card} p-5 sm:p-6`}>
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-bold">品目</h2>
            <button type="button" onClick={addRow} className={secondaryButton}>
              <Plus size={20} />
              品目を追加
            </button>
          </div>

          <div className="mt-2 divide-y divide-card-line">
            {rows.map((row, index) => (
              <div key={row.key} className="grid gap-3 py-4 md:grid-cols-[1.6fr_1fr_1fr_auto] md:items-end">
                <label className={labelText}>
                  品目 {index + 1}
                  <select
                    value={row.materialId}
                    onChange={(e) => updateRow(row.key, { materialId: e.target.value })}
                    required
                    className={field}
                  >
                    <option value="">選択してください</option>
                    {materials.map((m) => (
                      <option key={m.id} value={m.id}>
                        {m.name}
                      </option>
                    ))}
                  </select>
                </label>

                <label className={labelText}>
                  数量(kg)
                  <input
                    type="number"
                    inputMode="decimal"
                    step="0.01"
                    min="0.01"
                    value={row.quantityKg}
                    onChange={(e) => updateRow(row.key, { quantityKg: e.target.value })}
                    required
                    className={field}
                  />
                </label>

                <label className={labelText}>
                  申告数量(kg)(任意)
                  <input
                    type="number"
                    inputMode="decimal"
                    step="0.01"
                    min="0"
                    value={row.declaredKg}
                    onChange={(e) => updateRow(row.key, { declaredKg: e.target.value })}
                    className={field}
                  />
                </label>

                <button
                  type="button"
                  onClick={() => removeRow(row.key)}
                  disabled={rows.length === 1}
                  aria-label={`品目 ${index + 1} を削除`}
                  className={`${secondaryButton} justify-center`}
                >
                  <Trash2 size={22} />
                </button>
              </div>
            ))}
          </div>
        </section>

        <div className={`${card} px-6 py-4 text-lg text-foreground/60`}>
          品目 <span className="text-2xl font-bold text-foreground">{rows.length}</span> 件 ／ 合計{" "}
          <span className="text-2xl font-bold text-accent-text">
            {totalKg.toLocaleString("ja-JP", { maximumFractionDigits: 2 })}
          </span>{" "}
          kg
        </div>

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
            <p className="font-bold">在庫が不足しています(登録は完了しています)</p>
            <ul className="mt-1 list-disc pl-6">
              {warnings.map((w) => (
                <li key={w.material_id}>
                  {w.name}:{w.shortage_kg.toLocaleString("ja-JP", { maximumFractionDigits: 2 })} kg 不足
                </li>
              ))}
            </ul>
          </div>
        )}

        <button type="submit" disabled={submitting} className={`${primaryButton} w-full`}>
          {submitting ? "登録中..." : "登録する"}
        </button>
      </form>
    </div>
  );
}