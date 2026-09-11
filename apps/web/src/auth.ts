import { ref } from "vue";

type Account = { id: string; username: string; display_name: string; email: string; verified: boolean; created: string };
type Session = { token: string; record: Account };
const storageKey = "do_account_session";
export const account = ref<Account | null>(null);
export const authReady = ref(false);
export const authError = ref("");
let token = "";

export class AuthError extends Error {
  constructor(public status: number, public fields: Record<string, { code?: string; message?: string }>) {
    super(status === 429 ? "操作过于频繁，请稍后重试。" : status >= 500 ? "服务暂时不可用，请稍后重试。" : "请求未完成，请检查填写的信息。");
  }
}

export async function request<T>(path: string, body: unknown, bearer = "", method = "POST"): Promise<T> {
  let response: Response;
  try {
    response = await fetch(path, {
      method, headers: { "Content-Type": "application/json", ...(bearer ? { Authorization: `Bearer ${bearer}` } : {}) },
      body: JSON.stringify(body), signal: AbortSignal.timeout(15000), cache: "no-store",
    });
  } catch { throw new Error("无法连接服务器，请检查网络后重试。"); }
  const data = response.status === 204 ? {} : await response.json();
  if (!response.ok) throw new AuthError(response.status, data.data ?? {});
  return data as T;
}

function save(session: Session, persist = true) {
  token = session.token;
  account.value = session.record;
  if (!persist) return;
  try { localStorage.setItem(storageKey, token); sessionStorage.removeItem(storageKey); } catch { /* The current page can still log in. */ }
}
export function logout() {
  ++revision;
  authReady.value = true;
  authError.value = "";
  token = "";
  account.value = null;
  try { localStorage.removeItem(storageKey); sessionStorage.removeItem(storageKey); } catch { /* Storage may be disabled. */ }
}
let revision = 0;
export function restoreSession() { return restoreStoredSession(true); }
async function restoreStoredSession(persist: boolean) {
  const current = ++revision;
  authReady.value = false;
  authError.value = "";
  try {
    const saved = localStorage.getItem(storageKey) || sessionStorage.getItem(storageKey);
    if (saved) {
      const session = await request<Session>("/api/collections/users/auth-refresh", {}, saved);
      if (current === revision) save(session, persist);
    } else if (current === revision) { token = ""; account.value = null; }
  } catch (e) {
    if (current !== revision) return;
    if (e instanceof AuthError && (e.status === 401 || e.status === 403)) logout();
    else { account.value = null; authError.value = e instanceof Error ? e.message : "无法恢复登录状态。"; }
  } finally { if (current === revision) authReady.value = true; }
}
export async function login(email: string, password: string) {
  ++revision;
  save(await request<Session>("/api/collections/users/auth-with-password", { identity: email.trim(), password }));
  authError.value = "";
  authReady.value = true;
}
export async function updateDisplayName(displayName: string) {
  if (!account.value) throw new Error("请先登录。");
  const current = revision;
  const updated = await request<Account>(`/api/collections/users/records/${account.value.id}`, { display_name: displayName.trim() }, token, "PATCH");
  if (current === revision) account.value = updated;
}
export async function changeEmail(newEmail: string) {
  if (!account.value) throw new Error("请先登录。");
  await request("/api/collections/users/request-email-change", { newEmail: newEmail.trim() }, token);
}
window.addEventListener("storage", (event) => {
  if (event.key === storageKey || event.key === null) void restoreStoredSession(false);
});
