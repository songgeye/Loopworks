"use client";

import { SyntheticEvent, useEffect, useState } from "react";
import { ApiError, apiFetch } from "@/lib/api";
import { formatKg } from "@/lib/format";

type Material = { material_id: number; name: string };
type Staff = { id: number; name: string };
type StockWarning = { material_id: number; name: string; shortage_kg: number };
type Props = { materials: Material[]; onDone: () => void };

const card = "rounded-3xl border border-card-line bg-card text-foreground";
const labelText = "block text-base text-foreground/60";
const field =
  "mt-2 w-full rounded-xl border border-card-line bg-card-field px-4 py-3 text-xl text-foreground focus:border-accent focus:outline-none";
const primaryButton = "rounded-2xl bg-accent px-6 py-3 text-lg font-bold text-accent-ink disabled:opacity-50";

export default function AdjustmentForm({ materials, onDone }: Props) {
  const [staffs, setStaffs] = useState<Staff[]>([]);
  const [materialId, setMaterialId] = useState("");
  const [direction, setDirection] = useState<"increase" | "decrease">("increase");
  const [quantityKg, setQuantityKg] = useState("");
  const [note, setNote] = useState("");
  const [staffId, setStaffId] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [warnings, setWarnings] = useState<StockWarning[]>([]);

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

  const canSubmit = materialId !== "" && staffId !== "" && Number(quantityKg) > 0 && note.trim() !== "" && !submitting;

  async function handleSubmit(e: SyntheticEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    setMessage(null);
    setWarnings([]);
    setSubmitting(true);
    try {
      const result = await apiFetch<{ id: number; warnings?: StockWarning[] }>("/adjustment_materials", {
        method: "POST",
        body: JSON.stringify({
          adjustment_material: {
            material_id: Number(materialId),
            staff_id: Number(staffId),
            direction,
            quantity_kg: Number(quantityKg),
            note: note.trim(),
          },
        }),
      });
      setMessage("在庫を調整しました");
      setWarnings(result.warnings ?? []);
      setQuantityKg("");
      setNote("");
      onDone();
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        setError("ログインが必要です。ログインし直してください");
      } else if (err instanceof ApiError && err.status === 403) {
        setError("在庫の調整は、管理者のみ行えます");
      } else if (err instanceof ApiError && err.status === 422) {
        const errors = (err.body as { errors?: string[] } | null)?.errors;
        setError(errors?.join("、") ?? "登録できませんでした");
      } else {
        setError("通信に失敗しました。しばらくしてからもう一度お試しください");
      }
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className={`${card} space-y-4 p-5 sm:p-6`}>
      <h2 className="text-xl font-bold">在庫を調整</h2>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <label className={labelText}>
          品目
          <select value={materialId} onChange={(e) => setMaterialId(e.target.value)} className={field}>
            <option value="">選択してください</option>
            {materials.map((m) => (
              <option key={m.material_id} value={m.material_id}>
                {m.name}
              </option>
            ))}
          </select>
        </label>

        <label className={labelText}>
          区分
          <select
            value={direction}
            onChange={(e) => setDirection(e.target.value as "increase" | "decrease")}
            className={field}
          >
            <option value="increase">増える(棚卸増・入庫忘れ)</option>
            <option value="decrease">減る(棚卸減・出庫忘れ)</option>
          </select>
        </label>

        <label className={labelText}>
          数量(kg)
          <input
            type="number"
            inputMode="decimal"
            min="0"
            step="0.01"
            value={quantityKg}
            onChange={(e) => setQuantityKg(e.target.value)}
            placeholder="0"
            className={field}
          />
        </label>

        <label className={labelText}>
          記録者
          <select value={staffId} onChange={(e) => setStaffId(e.target.value)} className={field}>
            <option value="">選択してください</option>
            {staffs.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </select>
        </label>
      </div>

      <label className={labelText}>
        理由(必須)
        <input
          type="text"
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="例: 11/10の棚卸しで、差が出たため"
          className={field}
        />
      </label>

      <button type="submit" disabled={!canSubmit} className={primaryButton}>
        {submitting ? "登録中..." : "登録する"}
      </button>

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
          <p className="font-bold">在庫が不足しています(調整は完了しています)</p>
          <ul className="mt-1 list-disc pl-6">
            {warnings.map((w) => (
              <li key={w.material_id}>
                {w.name}:{formatKg(w.shortage_kg)} kg 不足
              </li>
            ))}
          </ul>
        </div>
      )}
    </form>
  );
}