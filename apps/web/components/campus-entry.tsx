"use client";
import { useEffect, useRef, useState } from "react";
import * as Dialog from "@radix-ui/react-dialog";
import PocketBase, { BaseAuthStore } from "pocketbase";
import { GameButton } from "./game-button";
import PixelText from "./pixel-text";
import GameDialogClose from "./game-dialog-close";
import { drawCharacter, initialAppearance, type Appearance, type CharacterState, type Gender, type Item } from "../game/character";
import { request, ApiError, clearGameSession, saveGameSession } from "../game/game-session";
import "../app/campus/wardrobe.css";

export default function CampusEntry({portal}:{portal:HTMLElement|null}) {
  const [open,setOpen]=useState(false);
  const [busy,setBusy]=useState(false);
  const [error,setError]=useState("");
  const [token,setToken]=useState("");
  const [authenticated,setAuthenticated]=useState(false);
  const [email,setEmail]=useState("");
  const [password,setPassword]=useState("");
  const [register,setRegister]=useState(false);
  const [items,setItems]=useState<Item[]>([]);
  const [oidcEnabled,setOidcEnabled]=useState(false);
  const [ready,setReady]=useState(false);
  const [accountMode,setAccountMode]=useState(false);
  const manageAccount=useRef(false);
  const [account,setAccount]=useState<{email:string;oidcBound:boolean}|null>(null);
  const [character,setCharacter]=useState<CharacterState|null>(null);
  const entering=useRef(false);
  const [appearance,setAppearance]=useState<Appearance>(initialAppearance);
  const [name,setName]=useState("");
  const [gender,setGender]=useState<Gender>("unspecified");
  const [bottom,setBottom]=useState("trousers");
  const [hat,setHat]=useState(false);
  const [color,setColor]=useState(0);
  const previewCanvas=<canvas className="character-preview" aria-label="角色预览" ref={canvas=>{
    if(canvas) drawCharacter(canvas,appearance,[{key:"shirt",color},{key:bottom,color},{key:"sneakers",color},...(hat?[{key:"cap",color}]:[])],0,0,gender);
  }} />;

  useEffect(()=>{
    const saved=sessionStorage.getItem("do-session");
    if(!saved) return;
    void run(async()=>{
      const auth=await request("/api/collections/users/auth-refresh",saved,{});
      sessionStorage.setItem("do-session",auth.token);
      setToken(auth.token);setAuthenticated(true);
    });
  },[]);

  async function run(action:()=>Promise<void>) {
    setBusy(true);setError("");
    try { await action(); }
    catch(e) {
      if(e instanceof ApiError && e.status===401) {
        clearGameSession();setToken("");setAuthenticated(false);
      }
      setError((e as Error).message);
    } finally { setBusy(false); }
  }
  function finish(state:CharacterState,catalog:Item[],authToken:string) {
    if(!state.profile || !entering.current || manageAccount.current) return;
    saveGameSession({token:authToken,state:{...state,profile:state.profile},items:catalog});
    window.location.assign("/campus/");
  }
  async function acceptLogin(authToken:string,catalog:Item[]=items) {
    sessionStorage.setItem("do-session",authToken);
    setAuthenticated(true);
    const [state,details]:[CharacterState,{email:string;oidcBound:boolean}]=await Promise.all([
      request("/api/v1/character",authToken),request("/api/v1/account",authToken),
    ]);
    setToken(authToken);
    setCharacter(state);setAccount(details);
    if(!state.profile) {setGender(state.defaults!.gender);setName(Array.from(state.defaults!.name).slice(0,20).join(""));}
    finish(state,catalog,authToken);
  }
  function begin(manage:boolean) {
    manageAccount.current=manage;setAccountMode(manage);
    entering.current=authenticated && !manage;
    setOpen(true);setToken("");setReady(false);
    void run(async()=>{
      sessionStorage.removeItem("do-game-session");
      const [catalog,methods]=await Promise.all([
        request("/api/collections/items/records?perPage=100",""),
        request("/api/collections/users/auth-methods",""),
      ]);
      setItems(catalog.items);setReady(true);
      setOidcEnabled(methods.oauth2.providers.some((provider:{name:string})=>provider.name==="oidc"));
      const saved=sessionStorage.getItem("do-session");
      if(!saved) return;
      const auth=await request("/api/collections/users/auth-refresh",saved,{});
      await acceptLogin(auth.token,catalog.items);
      if(!entering.current && !manageAccount.current) setOpen(false);
    });
  }
  async function login() {
    await run(async()=>{
      if(register) await request("/api/collections/users/records","",{email,password,passwordConfirm:password});
      const auth=await request("/api/collections/users/auth-with-password","",{identity:email,password});
      setPassword("");
      await acceptLogin(auth.token);
      if(!manageAccount.current) {entering.current=false;setOpen(false);}
    });
  }
  function loginOIDC(bind=false) {
    const authorizationTab=window.open("about:blank","_blank");
    if(!authorizationTab) {setError("无法打开统一认证标签页，请允许此站点打开新标签页");return;}
    authorizationTab.opener=null;
    const pb=new PocketBase(window.location.origin,new BaseAuthStore());
    if(bind) pb.authStore.save(token);
    void run(async()=>{
      try {
        const auth=await pb.collection("users").authWithOAuth2({provider:"oidc",urlCallback:url=>{authorizationTab.location.replace(url);}});
        await acceptLogin(auth.token);
        if(!bind && !manageAccount.current) {entering.current=false;setOpen(false);}
      } finally {authorizationTab.close();}
    });
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
  return <Dialog.Root open={open} onOpenChange={next=>{if(!next) entering.current=false;setOpen(next);}}>
    <GameButton className="campus-entry" appearance="primary" disabled={busy} onClick={()=>begin(false)}>{authenticated ? "进入校园" : "登录"}</GameButton>
    {authenticated && <GameButton disabled={busy} onClick={()=>begin(true)}>账号</GameButton>}
    <Dialog.Portal container={portal}>
      <Dialog.Overlay className="game-dialog-overlay" />
      <Dialog.Content className="game-dialog wardrobe" aria-describedby={undefined}>
        <header className="game-dialog-header">
          <Dialog.Title><PixelText>{token && !accountMode ? "创建角色" : "账号"}</PixelText></Dialog.Title>
          <GameDialogClose />
        </header>
        <div className="wardrobe-content" aria-busy={busy}>
          {!token ? (
              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  void login();
                }}
              >
                {oidcEnabled && <GameButton className="sso-login" appearance="primary" disabled={busy || !ready} onClick={()=>loginOIDC()}>大工统一认证</GameButton>}
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
                <GameButton type="submit" disabled={busy || !ready}>
                  {register ? "注册并登录" : "登录"}
                </GameButton>
                <GameButton disabled={busy || !ready} onClick={() => setRegister(!register)}>
                  {register ? "已有账号" : "注册账号"}
                </GameButton>
              </form>
          ) : accountMode ? (<>
            <PixelText wrap>{account!.email}</PixelText>
            {oidcEnabled && (account!.oidcBound ? <PixelText>统一认证已绑定</PixelText> : <GameButton disabled={busy} onClick={()=>loginOIDC(true)}>绑定统一认证</GameButton>)}
            <GameButton disabled={busy} onClick={()=>{manageAccount.current=false;setAccountMode(false);finish(character!,items,token);}}>进入校园</GameButton>
          </>) : (<>
                  {oidcEnabled && (account!.oidcBound ? <PixelText>统一认证已绑定</PixelText> : <GameButton disabled={busy} onClick={()=>loginOIDC(true)}>绑定统一认证</GameButton>)}
                  {previewCanvas}
                  <form
                    onSubmit={(e) => {
                      e.preventDefault();
                      void run(async () =>
                        finish(
                          await request("/api/v1/character", token, {
                            name,
                            gender,
                            appearance,
                            bottom,
                            hat,
                            color,
                          }),
                          items,
                          token,
                        ),
                      );
                    }}
                  >
                    <label>
                      <PixelText>用户名</PixelText>
                      <input
                        aria-label="用户名"
                        required
                        value={name}
                        onChange={(e) => setName(Array.from(e.target.value).slice(0,20).join(""))}
                      />
                    </label>
                    <div className="character-gender" role="group" aria-label="角色性别">
                      {([['male','男'],['female','女'],['unspecified','未指定']] as const).map(([value,label])=><GameButton key={value} aria-pressed={gender===value} disabled={busy} onClick={()=>setGender(value)}>{label}</GameButton>)}
                    </div>
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
                    <GameButton type="submit" disabled={busy || !ready}>
                      确认创建
                    </GameButton>
                  </form>
          </>)}
          {error && <p role="alert"><PixelText wrap>{error}</PixelText></p>}
        </div>
      </Dialog.Content>
    </Dialog.Portal>
  </Dialog.Root>;
}
