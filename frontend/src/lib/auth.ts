import { API_URL, ApiError, clearToken, getToken, setToken } from "@/lib/api";

const USER_KEY = "loopworks_user";


export type CurrentUser = {
  id: number;
  username: string;
  role: "admin" | "staff";
};

export function getUser(): CurrentUser | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = localStorage.getItem(USER_KEY);
    return raw ? (JSON.parse(raw) as CurrentUser) : null;
  } catch {
    return null;
  }
}

function saveUser(user: CurrentUser): void {
  try {
    localStorage.setItem(USER_KEY, JSON.stringify(user));
  } catch {
  }
}

export async function login(username: string, password: string): Promise<CurrentUser> {
  const res = await fetch(`${API_URL}/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ staff: { username, password } }),
  });
  if (!res.ok) throw new ApiError(res.status, null);

  const authorization = res.headers.get("Authorization");
  const token = authorization?.replace(/^Bearer\s+/i, "");
  if (!token) throw new Error("トークンを取得できませんでした");

  const user = (await res.json()) as CurrentUser;
  setToken(token);
  saveUser(user);
  return user;
}

export async function logout(): Promise<void> {
  const token = getToken();
  try {
    if (token) {
      await fetch(`${API_URL}/logout`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${token}` },
      });
    }
  } finally {
    clearToken();
    try {
      localStorage.removeItem(USER_KEY);
    } catch {
    }
  }
}