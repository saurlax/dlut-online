"use client";
import { useEffect, useRef, useState } from "react";
import * as Dialog from "@radix-ui/react-dialog";
import PocketBase, { BaseAuthStore } from "pocketbase";
import { GameButton } from "../../components/game-button";
import PixelText from "../../components/pixel-text";
import GameDialogClose from "../../components/game-dialog-close";
import {
  drawCharacter,
  initialAppearance,
  type Appearance,
  type Item,
  type CharacterState,
} from "../../game/character";
import "../../components/game-dialog.css";
import "./wardrobe.css";
import { Hotbar, InventoryPanel, PointerItem, type CarriedItem } from "./inventory-panel";

async function request(path: string, token: string, body?: unknown) {
  const r = await fetch(path, {
    method: body ? "POST" : "GET",
    headers: { "Content-Type": "application/json", Authorization: token },
    body: body ? JSON.stringify(body) : undefined,
  });
  const value = await r.json();
  if (!r.ok) throw new Error(value.message || "请求失败");
  return value;
}
export default function Wardrobe({
  portal,
  onCharacter,
}: {
  portal: HTMLElement | null;
  onCharacter: (s: CharacterState, items: Item[]) => void;
}) {
  const [open, setOpen] = useState(false),
    [token, setToken] = useState(""),
    [email, setEmail] = useState(""),
    [password, setPassword] = useState(""),
    [register, setRegister] = useState(false);
  const [state, setState] = useState<CharacterState>({
      profile: null,
      inventory: [],
      capacity: 0,
    }),
    [items, setItems] = useState<Item[]>([]),
    [appearance, setAppearance] = useState<Appearance>(initialAppearance),
    [name, setName] = useState(""),
    [bottom, setBottom] = useState("trousers"),
    [hat, setHat] = useState(false),
    [color, setColor] = useState(0),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  const [selected, setSelected] = useState("hotbar:0");
  const [active, setActive] = useState("hotbar:0");
  const [carried, setCarried] = useState<CarriedItem | null>(null);
  const [oidcEnabled, setOidcEnabled] = useState(false);
  function changeOpen(next:boolean) { setCarried(null);setOpen(next); }
  const preview = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const saved = sessionStorage.getItem("do-session");
    if (!saved) return;
    void (async () => {
      try {
        const auth = await request(
          "/api/collections/users/auth-refresh",
          saved,
          {},
        );
        const catalog = await request(
          "/api/collections/items/records?perPage=100",
          "",
        );
        const current = await request("/api/v1/character", auth.token);
        sessionStorage.setItem("do-session", auth.token);
        setToken(auth.token);
        setItems(catalog.items);
        publish(current, catalog.items);
      } catch (e) {
        setError((e as Error).message);
      }
    })();
  }, []);

  const publish = (s: CharacterState, catalog: Item[]) => {
    setState(s);
    onCharacter(s, catalog);
  };
  useEffect(() => {
    if (!open) return;
    void request("/api/collections/items/records?perPage=100", "")
      .then((r) => setItems(r.items))
      .catch((e) => setError(e.message));
    void request("/api/collections/users/auth-methods", "")
      .then((methods) => setOidcEnabled(methods.oauth2.providers.some((provider: {name:string}) => provider.name === "oidc")))
      .catch((e) => setError(e.message));
  }, [open]);
  useEffect(() => {
    if (!preview.current || (state.profile && !items.length)) return;
    const wear = state.profile
      ? state.inventory
          .filter((v) => v.id !== (open ? carried?.id : undefined) && !v.slotId.startsWith("hotbar:") && !v.slotId.startsWith("bag:"))
          .map((v) => ({
            key: items.find((i) => i.id === v.itemId)!.key,
            color: v.color,
          }))
      : [
          { key: "shirt", color },
          { key: bottom, color },
          { key: "sneakers", color },
          ...(hat ? [{ key: "cap", color }] : []),
        ];
    drawCharacter(
      preview.current,
      state.profile?.appearance || appearance,
      wear,
    );
  }, [open, appearance, state, items, color, bottom, hat, carried]);
  async function run(fn: () => Promise<void>) {
    setBusy(true);
    setError("");
    try {
      await fn();
      return true;
    } catch (e) {
      setError((e as Error).message);
      return false;
    } finally {
      setBusy(false);
    }
  }
  async function login() {
    await run(async () => {
      if (register)
        await request("/api/collections/users/records", "", {
          email,
          password,
          passwordConfirm: password,
        });
      const auth = await request(
        "/api/collections/users/auth-with-password",
        "",
        { identity: email, password },
      );
      setPassword("");
      await acceptLogin(auth.token);
    });
  }
  async function acceptLogin(authToken: string) {
    setToken(authToken);
    sessionStorage.setItem("do-session", authToken);
    publish(await request("/api/v1/character", authToken), items);
  }
  function loginOIDC() {
    const pb = new PocketBase(window.location.origin, new BaseAuthStore());
    void run(async () => {
      const auth = await pb.collection("users").authWithOAuth2({provider: "oidc"});
      await acceptLogin(auth.token);
    });
  }
  useEffect(() => {
    function keydown(e: KeyboardEvent) {
      if (e.repeat || e.ctrlKey || e.metaKey || e.altKey || (e.target as HTMLElement).closest('input,textarea,select,[contenteditable="true"]')) return;
      if (e.code === "KeyI") {
        if (!open && document.querySelector('[role="dialog"]')) return;
        e.preventDefault(); if (!open) setSelected(active); changeOpen(!open);
      } else if (!document.querySelector('[role="dialog"]') && /^Digit[0-9]$/.test(e.code)) {
        const index = (Number(e.code.slice(-1)) + 9) % 10;
        e.preventDefault(); setActive(`hotbar:${index}`);
      }
    }
    document.addEventListener("keydown",keydown);
    return () => document.removeEventListener("keydown",keydown);
  },[open,active]);
  const previewCanvas = <canvas ref={preview} className="character-preview" aria-label="角色预览" />;
  function moveItem(id:string,slotId:string) {
    return run(async()=>publish(await request("/api/v1/character/move",token,{id,slotId}),items));
  }
  const choices: [keyof Appearance, string, number][] = [
    ["skin", "肤色", 4],
    ["face", "脸型", 2],
    ["hair", "发型", 4],
    ["hairColor", "发色", 4],
    ["eyes", "眼睛", 3],
    ["nose", "鼻子", 2],
    ["mouth", "嘴巴", 2],
    ["brows", "眉毛", 2],
    ["beard", "胡须", 2],
    ["freckles", "雀斑", 2],
  ];
  return (
    <Dialog.Root open={open} onOpenChange={changeOpen}>
      <Hotbar carriedId={open ? carried?.id : undefined} state={state} items={items} active={active} onSelect={setActive} onOpen={()=>{setSelected(active);changeOpen(true);}} />
      {open && carried && portal && <PointerItem carried={carried} state={state} items={items} host={portal} />}
      <Dialog.Portal container={portal}>
        <Dialog.Overlay className={`game-dialog-overlay${carried ? " inventory-carrying" : ""}`} />
        <Dialog.Content
          className={`game-dialog wardrobe${state.profile ? " wardrobe-inventory" : ""}${carried ? " inventory-carrying" : ""}`}
          aria-describedby={undefined}
        >
          <header className="game-dialog-header">
            <Dialog.Title>
              <PixelText>
                {!token ? "账号" : state.profile ? "背包" : "创建角色"}
              </PixelText>
            </Dialog.Title>
            <GameDialogClose />
          </header>
          <div className="wardrobe-content">
            {!token ? (
              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  void login();
                }}
              >
                {oidcEnabled && <GameButton className="sso-login" appearance="primary" disabled={busy} onClick={loginOIDC}>大工统一认证</GameButton>}
                <label>
                  <PixelText>邮箱</PixelText>
                  <input
                    aria-label="邮箱"
                    type="email"
                    autoComplete="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                  />
                </label>
                <label>
                  <PixelText>密码</PixelText>
                  <input
                    aria-label="密码"
                    type="password"
                    autoComplete={
                      register ? "new-password" : "current-password"
                    }
                    minLength={8}
                    required
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                  />
                </label>
                <GameButton type="submit" disabled={busy}>
                  {register ? "注册并登录" : "登录"}
                </GameButton>
                <GameButton onClick={() => setRegister(!register)}>
                  {register ? "已有账号" : "注册账号"}
                </GameButton>
              </form>
            ) : (
              <>
                {!state.profile ? (
                  <>
                  {previewCanvas}
                  <form
                    onSubmit={(e) => {
                      e.preventDefault();
                      void run(async () =>
                        publish(
                          await request("/api/v1/character", token, {
                            name,
                            appearance,
                            bottom,
                            hat,
                            color,
                          }),
                          items,
                        ),
                      );
                    }}
                  >
                    <label>
                      <PixelText>名字</PixelText>
                      <input
                        aria-label="名字"
                        required
                        maxLength={20}
                        value={name}
                        onChange={(e) => setName(e.target.value)}
                      />
                    </label>
                    {choices.map(([key, label, count]) => (
                      <GameButton
                        key={key}
                        aria-label={label}
                        onClick={() =>
                          setAppearance({
                            ...appearance,
                            [key]: (appearance[key] + 1) % count,
                          })
                        }
                      >{`${label} ${appearance[key] + 1}`}</GameButton>
                    ))}
                    <GameButton
                      onClick={() => setColor((color + 1) % 4)}
                    >{`衣物颜色 ${color + 1}`}</GameButton>
                    <GameButton
                      onClick={() =>
                        setBottom(bottom === "skirt" ? "trousers" : "skirt")
                      }
                    >
                      {bottom === "skirt" ? "短裙" : "长裤"}
                    </GameButton>
                    <GameButton onClick={() => setHat(!hat)}>
                      {hat ? "戴帽子" : "不戴帽子"}
                    </GameButton>
                    <GameButton type="submit" disabled={busy}>
                      确认创建
                    </GameButton>
                  </form>
                  </>
                ) : (
                  <>
                    <InventoryPanel state={state} items={items} selected={selected} setSelected={setSelected} busy={busy} onMove={moveItem} carried={carried} onCarry={setCarried} onActivate={setActive}
                      preview={previewCanvas} />
                  </>
                )}
              </>
            )}
            {error && (
              <p role="alert">
                <PixelText wrap>{error}</PixelText>
              </p>
            )}
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
