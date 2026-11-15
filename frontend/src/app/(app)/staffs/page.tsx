"use client";

import { SyntheticEvent, useEffect, useState } from "react";
import Link from "next/link";
import { ApiError, apiFetch } from "@/lib/api";
import { useRole } from "@/lib/useRole";
import PasswordInput from "@/components/PasswordInput";

type Role = "admin" | "staff";
type StaffRow = { id: number; name: string; username?: string; role?: Role };

const ROLE_LABELS: Record<Role, string> = { admin: "管理者", staff: "スタッフ" };

const card = "rounded-3xl border border-card-line bg-card text-foreground";
const labelText = "block text-base text-foreground/60";
const field =
  "mt-2 w-full rounded-xl border border-card-line bg-card-field px-4 py-3 text-xl text-foreground focus:border-accent focus:outline-none";
const secondaryButton =
  "inline-flex items-center justify-center gap-2 rounded-2xl border border-card-line bg-card-field px-4 py-3 text-lg text-foreground hover:bg-foreground/10 disabled:opacity-30";
const primaryButton = "rounded-2xl bg-accent px-6 py-3 text-lg font-bold text-accent-ink disabled:opacity-50";
const dangerButton =
  "rounded-2xl border border-red-400/40 bg-card-field px-4 py-3 text-lg text-red-700 hover:bg-foreground/10 disabled:opacity-30 dark:text-red-300";

export default function StaffsPage() {
  const role = useRole();
  const isAdmin = role === "admin";

  const [staffs, setStaffs] = useState<StaffRow[] | null>(null);
  const [needLogin, setNeedLogin] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [busy, setBusy] = useState(false);

  const [showCreate, setShowCreate] = useState(false);
  const [createName, setCreateName] = useState("");
  const [createUsername, setCreateUsername] = useState("");
  const [createRole, setCreateRole] = useState<Role>("staff");
  const [createPassword, setCreatePassword] = useState("");

  const [editingId, setEditingId] = useState<number | null>(null);
  const [editName, setEditName] = useState("");
  const [editRole, setEditRole] = useState<Role>("staff");
  const [editPassword, setEditPassword] = useState("");
  const [deactivatingId, setDeactivatingId] = useState<number | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const result = await apiFetch<StaffRow[]>("/staffs");
        if (cancelled) return;
        setStaffs(result);
        setError(null);
      } catch (err) {
        if (cancelled) return;
        if (err instanceof ApiError && err.status === 401) setNeedLogin(true);
        else setError("データの読み込みに失敗しました。しばらくしてからもう一度お試しください");
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
      setError("対象のスタッフが見つかりません。一覧を更新しました");
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
      await apiFetch("/staffs", {
        method: "POST",
        body: JSON.stringify({
          staff: {
            name: createName.trim(),
            username: createUsername.trim(),
            role: createRole,
            password: createPassword,
          },
        }),
      });
      setMessage(`「${createName.trim()}」を登録しました`);
      setCreateName("");
      setCreateUsername("");
      setCreateRole("staff");
      setCreatePassword("");
      setShowCreate(false);
      setReloadKey((k) => k + 1);
    } catch (err) {
      showError(err, "登録できませんでした");
    } finally {
      setBusy(false);
    }
  }

  function startEdit(s: StaffRow) {
    setEditingId(s.id);
    setEditName(s.name);
    setEditRole(s.role ?? "staff");
    setEditPassword("");
    setDeactivatingId(null);
    setError(null);
    setMessage(null);
  }

  async function handleSave(id: number) {
    setError(null);
    setMessage(null);
    setBusy(true);
    try {
      await apiFetch(`/staffs/${id}`, {
        method: "PATCH",
        body: JSON.stringify({
          staff: {
            name: editName.trim(),
            role: editRole,
            ...(editPassword ? { password: editPassword } : {}),
          },
        }),
      });
      setMessage(`「${editName.trim()}」を更新しました`);
      setEditingId(null);
      setReloadKey((k) => k + 1);
    } catch (err) {
      showError(err, "更新できませんでした");
    } finally {
      setBusy(false);
    }
  }

  async function handleDeactivate(s: StaffRow) {
    setError(null);
    setMessage(null);
    setBusy(true);
    try {
      await apiFetch(`/staffs/${s.id}`, { method: "DELETE" });
      setMessage(`「${s.name}」を無効化しました`);
      setDeactivatingId(null);
      setReloadKey((k) => k + 1);
    } catch (err) {
      showError(err, "無効化できませんでした");
      setDeactivatingId(null);
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

  const canCreate = createName.trim() !== "" && createUsername.trim() !== "" && createPassword !== "" && !busy;
  const canSave = editName.trim() !== "" && !busy;

  return (
    <div className="space-y-4">
      <header className={`${card} flex items-center justify-between gap-4 px-6 py-5`}>
        <div>
          <p className="text-sm font-semibold text-accent-text">マスタ</p>
          <h1 className="text-3xl font-bold">スタッフ</h1>
        </div>
        {isAdmin && (
          <button
            type="button"
            onClick={() => {
              setShowCreate((v) => !v);
              setEditingId(null);
            }}
            className={secondaryButton}
          >
            {showCreate ? "閉じる" : "＋ スタッフを追加"}
          </button>
        )}
      </header>

      {!isAdmin && (
        <p className={`${card} px-6 py-4 text-lg text-foreground/60`}>
          スタッフの追加・編集・無効化は、管理者のみ行えます。
        </p>
      )}

      {isAdmin && showCreate && (
        <form onSubmit={handleCreate} className={`${card} space-y-4 p-5 sm:p-6`}>
          <h2 className="text-xl font-bold">スタッフを追加</h2>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className={labelText}>
              名前
              <input type="text" value={createName} onChange={(e) => setCreateName(e.target.value)} className={field} />
            </label>
            <label className={labelText}>
              ユーザー名(ログイン用)
              <input
                type="text"
                value={createUsername}
                onChange={(e) => setCreateUsername(e.target.value)}
                autoComplete="off"
                className={field}
              />
            </label>
            <label className={labelText}>
              権限
              <select value={createRole} onChange={(e) => setCreateRole(e.target.value as Role)} className={field}>
                <option value="staff">スタッフ</option>
                <option value="admin">管理者</option>
              </select>
            </label>
            <label className={labelText}>
              パスワード
              <PasswordInput
                value={createPassword}
                onChange={(e) => setCreatePassword(e.target.value)}
                autoComplete="new-password"
                className={field}
              />
            </label>
          </div>
          <button type="submit" disabled={!canCreate} className={primaryButton}>
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

      {staffs === null && !error && <div className={`${card} p-6 text-xl`}>読み込み中...</div>}
      {staffs && staffs.length === 0 && <div className={`${card} p-6 text-xl text-foreground/60`}>スタッフはいません</div>}

      <ul className="space-y-4">
        {staffs?.map((s) => (
          <li key={s.id} className={`${card} p-5 sm:p-6`}>
            {editingId === s.id ? (
              // 編集中の行
              <div className="space-y-4">
                <div className="grid gap-4 sm:grid-cols-3">
                  <label className={labelText}>
                    名前
                    <input type="text" value={editName} onChange={(e) => setEditName(e.target.value)} className={field} />
                  </label>
                  <label className={labelText}>
                    権限
                    <select value={editRole} onChange={(e) => setEditRole(e.target.value as Role)} className={field}>
                      <option value="staff">スタッフ</option>
                      <option value="admin">管理者</option>
                    </select>
                  </label>
                  <label className={labelText}>
                    新しいパスワード(変える場合のみ)
                    <PasswordInput
                      value={editPassword}
                      onChange={(e) => setEditPassword(e.target.value)}
                      autoComplete="new-password"
                      className={field}
                    />
                  </label>
                </div>
                <p className="text-base text-foreground/60">ユーザー名: {s.username}(変更できません)</p>
                <div className="flex gap-2">
                  <button type="button" onClick={() => handleSave(s.id)} disabled={!canSave} className={primaryButton}>
                    {busy ? "保存中..." : "保存する"}
                  </button>
                  <button type="button" onClick={() => setEditingId(null)} className={secondaryButton}>
                    やめる
                  </button>
                </div>
              </div>
            ) : (
              <div className="flex flex-wrap items-center justify-between gap-4">
                <div>
                  <p className="text-2xl font-bold">{s.name}</p>
                  {isAdmin && (
                    <p className="text-base text-foreground/60">
                      {s.username} ／ {s.role ? ROLE_LABELS[s.role] : ""}
                    </p>
                  )}
                </div>

                {isAdmin && deactivatingId !== s.id && (
                  <div className="flex gap-2">
                    <button type="button" onClick={() => startEdit(s)} className={secondaryButton}>
                      編集
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setDeactivatingId(s.id);
                        setError(null);
                        setMessage(null);
                      }}
                      className={dangerButton}
                    >
                      無効化
                    </button>
                  </div>
                )}

                {isAdmin && deactivatingId === s.id && (
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="text-lg">無効化すると、ログインできなくなります。</span>
                    <button type="button" onClick={() => handleDeactivate(s)} disabled={busy} className={dangerButton}>
                      {busy ? "処理中..." : "無効化する"}
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
    </div>
  );
}