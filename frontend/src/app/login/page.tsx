"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api";
import { login } from "@/lib/auth";

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      await login(username, password);
      router.push("/");
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        setError("ユーザー名またはパスワードが違います");
      } else {
        setError("通信に失敗しました。しばらくしてからもう一度お試しください");
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center p-4">
      <form onSubmit={handleSubmit} className="w-full max-w-sm space-y-6">
        <h1 className="text-2xl font-bold">ログイン</h1>

        <label className="block text-lg">
          ユーザー名
          <input
            type="text"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            autoComplete="username"
            required
            className="mt-2 w-full rounded border bg-white p-3 text-xl text-black"
          />
        </label>

        <label className="block text-lg">
          パスワード
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
            className="mt-2 w-full rounded border bg-white p-3 text-xl text-black"
          />
        </label>

        {error && (
          <p role="alert" className="text-lg text-red-500">
            {error}
          </p>
        )}

        <button
          type="submit"
          disabled={loading}
          className="w-full rounded bg-blue-600 p-4 text-xl text-white disabled:opacity-50"
        >
          {loading ? "ログイン中..." : "ログイン"}
        </button>
      </form>
    </main>
  );
}