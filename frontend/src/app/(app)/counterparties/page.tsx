"use client";

import { SyntheticEvent, useEffect, useState } from "react";
import Link from "next/link";
import { ApiError, apiFetch } from "@/lib/api";
import { useRole } from "@/lib/useRole";

type PartyType = "corporate" | "individual";
type Counterparty = { id: number; name: string; party_type: PartyType };

const PARTY_LABELS: Record<PartyType, string> = { corporate: "法人", individual: "個人" };

const card = "rounded-3xl border border-card-line bg-card text-foreground";
const labelText = "block text-base text-foreground/60";
const field =
  "mt-2 w-full rounded-xl border border-card-line bg-card-field px-4 py-3 text-xl text-foreground focus:border-accent focus:outline-none";
const secondaryButton =
  "inline-flex items-center justify-center gap-2 rounded-2xl border border-card-line bg-card-field px-4 py-3 text-lg text-foreground hover:bg-foreground/10 disabled:opacity-30";
const primaryButton = "rounded-2xl bg-accent px-6 py-3 text-lg font-bold text-accent-ink disabled:opacity-50";
const dangerButton =
  "rounded-2xl border border-red-400/40 bg-card-field px-4 py-3 text-lg text-red-700 hover:bg-foreground/10 disabled:opacity-30 dark:text-red-300";

export default function CounterpartiesPage() {
  const isAdmin = useRole() === "admin";

  const [list, setList] = useState<Counterparty[] | null>(null);
  const [needLogin, setNeedLogin] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [busy, setBusy] = useState(false);

  const [showCreate, setShowCreate] = useState(false);
  const [createName, setCreateName] = useState("");
  const [createType, setCreateType] = useState<PartyType>("corporate");

  const [editingId, setEditingId] = useState<number | null>(null);
  const [editName, setEditName] = useState("");
  const [editType, setEditType] = useState<PartyType>("corporate");

  const [deactivatingId, setDeactivatingId] = useState<number | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const result = await apiFetch<Counterparty[]>("/counterparties");
        if (cancelled) return;
        setList(result);
      } catch (err) {
        if (cancelled) return;
        if (err instanceof ApiError && err.status === 401) setNeedLogin(true);
        else setError("取引先の読み込みに失敗しました。しばらくしてからもう一度お試しください");
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [reloadKey]);

  useEffect(() => {
    if (!message) return;
    const timer = setTimeout(() => setMessage(null), 4000);
    return () => clearTimeout(timer);
  }, [message]);

  function showError(err: unknown, fallback: string) {
    if (err instanceof ApiError && err.status === 401) {
      setNeedLogin(true);
    } else if (err instanceof ApiError && err.status === 403) {
      setError("この操作は、管理者のみ行えます");
    } else if (err instanceof ApiError && err.status === 404) {
      setError("対象が見つかりません。一覧を読み直してください");
      setReloadKey((k) => k + 1);
    } else if (err instanceof ApiError && err.status === 422) {
      const errors = (err.body as { errors?: string[] } | null)?.errors;
      setError(errors?.join("、") ?? fallback);
    } else {
      setError("通信に失敗しました。しばらくしてからもう一度お試しください");
    }
  }

  async function handleCreate(e: SyntheticEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    setMessage(null);
    setBusy(true);
    try {
      const name = createName.trim();
      await apiFetch("/counterparties", {
        method: "POST",
        body: JSON.stringify({ counterparty: { name, party_type: createType } }),
      });
      setMessage(`「${name}」を登録しました`);
      setCreateName("");
      setCreateType("corporate");
      setShowCreate(false);
      setReloadKey((k) => k + 1);
    } catch (err) {
      showError(err, "登録できませんでした");
    } finally {
      setBusy(false);
    }
  }

  function startEdit(c: Counterparty) {
    setEditingId(c.id);
    setEditName(c.name);
    setEditType(c.party_type);
    setDeactivatingId(null);
    setError(null);
    setMessage(null);
  }

  async function handleSave(id: number) {
    setError(null);
    setMessage(null);
    setBusy(true);
    try {
      await apiFetch(`/counterparties/${id}`, {
        method: "PATCH",
        body: JSON.stringify({ counterparty: { name: editName.trim(), party_type: editType } }),
      });
      setMessage("更新しました");
      setEditingId(null);
      setReloadKey((k) => k + 1);
    } catch (err) {
      showError(err, "更新できませんでした");
    } finally {
      setBusy(false);
    }
  }

  async function handleDeactivate(c: Counterparty) {
    setError(null);
    setMessage(null);
    setBusy(true);
    try {
      await apiFetch(`/counterparties/${c.id}`, { method: "DELETE" });
      setMessage(`「${c.name}」を無効化しました`);
      setDeactivatingId(null);
      setReloadKey((k) => k + 1);
    } catch (err) {
      showError(err, "無効化できませんでした");
    } finally {
      setBusy(false);
    }
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
      <header className={`${card} flex items-center justify-between gap-4 px-6 py-5`}>
        <div>
          <p className="text-sm font-semibold text-accent-text">マスタ管理</p>
          <h1 className="text-3xl font-bold">取引先</h1>
        </div>
        {isAdmin && (
          <button type="button" onClick={() => setShowCreate((v) => !v)} className={secondaryButton}>
            {showCreate ? "閉じる" : "＋ 新規登録"}
          </button>
        )}
      </header>

      {!isAdmin && (
        <p className={`${card} px-6 py-4 text-lg text-foreground/60`}>取引先の登録・編集・無効化は、管理者のみ行えます</p>
      )}

      {isAdmin && showCreate && (
        <form onSubmit={handleCreate} className={`${card} grid gap-4 p-5 sm:grid-cols-[1fr_200px_auto] sm:items-end sm:p-6`}>
          <label className={labelText}>
            名前
            <input type="text" value={createName} onChange={(e) => setCreateName(e.target.value)} className={field} />
          </label>
          <label className={labelText}>
            区分
            <select value={createType} onChange={(e) => setCreateType(e.target.value as PartyType)} className={field}>
              <option value="corporate">法人</option>
              <option value="individual">個人</option>
            </select>
          </label>
          <button type="submit" disabled={busy || createName.trim() === ""} className={primaryButton}>
            {busy ? "登録中..." : "登録する"}
          </button>
        </form>
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

      {list === null && !error && <div className={`${card} p-6 text-xl`}>読み込み中...</div>}
      {list && list.length === 0 && <div className={`${card} p-6 text-xl text-foreground/60`}>取引先が登録されていません</div>}

      {list && list.length > 0 && (
        <section className={card}>
          <p className="px-6 py-4 text-lg text-foreground/60">
            <span className="text-2xl font-bold text-foreground">{list.length}</span> 件
          </p>
          <ul>
            {list.map((c) => (
              <li key={c.id} className="border-t border-card-line px-6 py-4">
                {editingId === c.id ? (
                  <div className="grid gap-4 sm:grid-cols-[1fr_200px_auto] sm:items-end">
                    <label className={labelText}>
                      名前
                      <input type="text" value={editName} onChange={(e) => setEditName(e.target.value)} className={field} />
                    </label>
                    <label className={labelText}>
                      区分
                      <select value={editType} onChange={(e) => setEditType(e.target.value as PartyType)} className={field}>
                        <option value="corporate">法人</option>
                        <option value="individual">個人</option>
                      </select>
                    </label>
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={() => handleSave(c.id)}
                        disabled={busy || editName.trim() === ""}
                        className={primaryButton}
                      >
                        {busy ? "保存中..." : "保存"}
                      </button>
                      <button type="button" onClick={() => setEditingId(null)} className={secondaryButton}>
                        やめる
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className="flex flex-wrap items-center justify-between gap-4">
                    <div className="flex items-center gap-3">
                      <span className="text-2xl font-bold">{c.name}</span>
                      <span className="rounded-full border border-card-line px-3 py-0.5 text-base text-foreground/60">
                        {PARTY_LABELS[c.party_type] ?? c.party_type}
                      </span>
                    </div>
                    {isAdmin && deactivatingId !== c.id && (
                      <div className="flex gap-2">
                        <button type="button" onClick={() => startEdit(c)} className={secondaryButton}>
                          編集
                        </button>
                        <button
                          type="button"
                          onClick={() => {
                            setDeactivatingId(c.id);
                            setEditingId(null);
                            setError(null);
                            setMessage(null);
                          }}
                          className={dangerButton}
                        >
                          無効化
                        </button>
                      </div>
                    )}
                    {isAdmin && deactivatingId === c.id && (
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="text-lg text-red-700 dark:text-red-300">
                          無効化すると、登録フォームの選択肢から消えます(過去の記録は残ります)
                        </span>
                        <button type="button" onClick={() => handleDeactivate(c)} disabled={busy} className={dangerButton}>
                          {busy ? "無効化中..." : "無効化する"}
                        </button>
                        <button type="button" onClick={() => setDeactivatingId(null)} className={secondaryButton}>
                          やめる
                        </button>
                      </div>
                    )}
                  </div>
                )}
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}