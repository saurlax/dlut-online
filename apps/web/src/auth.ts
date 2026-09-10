import { ref } from "vue";

type Account = { id: string; display_name: string; email?: string };
type Session = { token: string; record: Account };
const storageKey = "do_account_session";
export const account = ref<Account | null>(null);
export const authReady = ref(false);
let token = "";

export class AuthError extends Error {
  constructor(public status: number, public fields: Record<string, { code?: string; message?: string }>) {
    super(status === 429 ? "操作过于频繁，请稍后重试。" : status >= 500 ? "服务暂时不可用，请稍后重试。" : "请求未完成，请检查填写的信息。");
  }
}

export async function request<T>(path: string, body: unknown, bearer = ""): Promise<T> {
  let response: Response;
  try {
    response = await fetch(path, {
      method: "POST", headers: { "Content-Type": "application/json", ...(bearer ? { Authorization: `Bearer ${bearer}` } : {}) },
      body: JSON.stringify(body), signal: AbortSignal.timeout(15000), cache: "no-store",
    });
  } catch { throw new Error("无法连接服务器，请检查网络后重试。"); }
  const data = response.status === 204 ? {} : await response.json();
  if (!response.ok) throw new AuthError(response.status, data.data ?? {});
  return data as T;
}

function save(session: Session) {
  token = session.token;
  account.value = session.record;
  try { sessionStorage.setItem(storageKey, token); } catch { /* The current page can still log in. */ }
}
export function logout() {
  token = "";
  account.value = null;
  try { sessionStorage.removeItem(storageKey); } catch { /* Storage may be disabled. */ }
}
export async function restoreSession() {
  try {
    const saved = sessionStorage.getItem(storageKey);
    if (saved) save(await request<Session>("/api/collections/users/auth-refresh", {}, saved));
  } catch { logout(); }
  finally { authReady.value = true; }
}
export async function login(email: string, password: string) {
  save(await request<Session>("/api/collections/users/auth-with-password", { identity: email.trim(), password }));
}
export async function approveGame(id: string) {
  return request<{ redirect_uri: string }>("/api/v1/auth/approve", { request: id }, token);
}
