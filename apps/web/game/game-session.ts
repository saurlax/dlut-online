import type { CharacterState, Item } from "./character";

export type GameSession = {
  token: string;
  state: CharacterState & { profile: NonNullable<CharacterState["profile"]> };
  items: Item[];
};

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export async function request(path: string, token: string, body?: unknown) {
  const response = await fetch(path, {
    method: body ? "POST" : "GET",
    headers: { "Content-Type": "application/json", Authorization: token },
    body: body ? JSON.stringify(body) : undefined,
  });
  const value = await response.json();
  if (!response.ok) throw new ApiError(response.status, value.message || "请求失败");
  return value;
}

export function saveGameSession(session: GameSession) {
  sessionStorage.setItem("do-session", session.token);
  sessionStorage.setItem("do-game-session", JSON.stringify({...session, version: 2}));
}

export function readGameSession(): GameSession | null {
  const saved = sessionStorage.getItem("do-game-session");
  if (!saved) return null;
  const session = JSON.parse(saved);
  return session.version === 2 ? session : null;
}

export function clearGameSession() {
  sessionStorage.removeItem("do-session");
  sessionStorage.removeItem("do-game-session");
}
