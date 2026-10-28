"use client";
import { useEffect, useRef, useState } from "react";
import * as Dialog from "@radix-ui/react-dialog";
import PocketBase, { BaseAuthStore, ClientResponseError } from "pocketbase";
import { GameButton } from "./game-button";
import PixelText from "./pixel-text";
import AccountForm from "./account-form";
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
  const [passwordConfirm,setPasswordConfirm]=useState("");
  const [code,setCode]=useState("");
  const [cooldown,setCooldown]=useState(0);
  const [register,setRegister]=useState(false);
  const [onboardingTicket,setOnboardingTicket]=useState("");
  const [onboarding,setOnboarding]=useState(false);
  const [items,setItems]=useState<Item[]>([]);
  const [oidcEnabled,setOidcEnabled]=useState(false);
  const [ready,setReady]=useState(false);
  const [accountMode,setAccountMode]=useState(false);
  const manageAccount=useRef(false);
  const [account,setAccount]=useState<{email:string;oidcBound:boolean;oidcSubject:string}|null>(null);
  const [character,setCharacter]=useState<CharacterState|null>(null);
  const entering=useRef(false);
  useEffect(()=>{ if(cooldown<=0) return; const timer=window.setTimeout(()=>setCooldown(cooldown-1),1000); return ()=>window.clearTimeout(timer); },[cooldown]);
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
    const ticket=sessionStorage.getItem("do-sso-onboarding-ticket");
    if(ticket) {
      setOnboarding(true);
      setOpen(true);setRegister(true);
      setOnboardingTicket(ticket);
      void run(async()=>{
        await request("/api/v1/sso/onboarding/inspect","",{ticket});
        await loadEntryData();
      });
      return;
    }
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
    window.location.assign("/game/");
  }
  async function acceptLogin(authToken:string,catalog:Item[]=items) {
    sessionStorage.setItem("do-session",authToken);
    setAuthenticated(true);
    const [state,details]:[CharacterState,{email:string;oidcBound:boolean;oidcSubject:string}]=await Promise.all([
      request("/api/v1/character",authToken),request("/api/v1/account",authToken),
    ]);
    setToken(authToken);
    setCharacter(state);setAccount(details);
    if(!state.profile) {setGender(state.defaults!.gender);setName(Array.from(state.defaults!.name).slice(0,20).join(""));}
    finish(state,catalog,authToken);
  }
  async function loadEntryData() {
    const [catalog,methods]=await Promise.all([
      request("/api/collections/items/records?perPage=100",""),
      request("/api/collections/users/auth-methods",""),
    ]);
    setItems(catalog.items);setReady(true);
    setOidcEnabled(methods.oauth2.providers.some((provider:{name:string})=>provider.name==="oidc"));
    return catalog.items as Item[];
  }
  function begin(manage:boolean) {
    manageAccount.current=manage;setAccountMode(manage);
    entering.current=authenticated && !manage;
    setOpen(true);setToken("");setReady(false);
    void run(async()=>{
      sessionStorage.removeItem("do-game-session");
      const catalog=await loadEntryData();
      const saved=sessionStorage.getItem("do-session");
      if(!saved) return;
      const auth=await request("/api/collections/users/auth-refresh",saved,{});
      await acceptLogin(auth.token,catalog);
      if(!entering.current && !manageAccount.current) setOpen(false);
    });
  }
  function enterGuest() {
    void run(async()=>{
      const guest=await request('/api/v1/guest','',{});
      const catalog:Item[]=[{id:'shirt',key:'shirt',name:'校园衬衫',slotId:'top',capacity:0},{id:'trousers',key:'trousers',name:'长裤',slotId:'bottom',capacity:0},{id:'sneakers',key:'sneakers',name:'运动鞋',slotId:'feet',capacity:0}];
      saveGameSession({token:guest.token,guest:{expiresAt:guest.expiresAt},items:catalog,state:{profile:{name:guest.name,gender:'unspecified',appearance:initialAppearance},inventory:catalog.map(item=>({id:item.id,itemId:item.id,slotId:item.slotId,color:0})),capacity:0}});
      window.location.assign('/game/');
    });
  }
  async function login() {
    await run(async()=>{
      if(register) {
        if(password!==passwordConfirm) throw new Error("两次输入的密码不一致");
        await request("/api/v1/registration","",{email,password,passwordConfirm,code});
      }
      const auth=await request("/api/collections/users/auth-with-password","",{identity:email,password});
      setPassword("");setPasswordConfirm("");setCode("");
      if(onboardingTicket) {
        await request("/api/v1/sso/onboarding/complete",auth.token,{ticket:onboardingTicket});
        sessionStorage.removeItem("do-sso-onboarding-ticket");
        setOnboardingTicket("");setOnboarding(false);
        await acceptLogin(auth.token);
        setOpen(false);
        return;
      }
      await acceptLogin(auth.token);
      if(!manageAccount.current) {entering.current=false;setOpen(false);}
    });
  }
  function sendCode() {
    const input=document.querySelector<HTMLInputElement>('input[aria-label="邮箱"]');
    if(!input?.reportValidity()) return;
    void run(async()=>{await request("/api/v1/registration/code","",{email});setCooldown(60);});
  }
  function loginOIDC(bind=false) {
    const authorizationTab=window.open("about:blank","_blank");
    if(!authorizationTab) {setError("无法打开统一认证标签页，请允许此站点打开新标签页");return;}
    authorizationTab.opener=null;
    const pb=new PocketBase(window.location.origin,new BaseAuthStore());
    if(bind) pb.authStore.save(token);
    void run(async()=>{
      try {
        if(!bind) await request("/api/v1/sso/onboarding/start","",{});
        const auth=await pb.collection("users").authWithOAuth2({provider:"oidc",urlCallback:url=>{authorizationTab.location.replace(url);}});
        await acceptLogin(auth.token);
        if(!bind && !manageAccount.current) {entering.current=false;setOpen(false);}
      } catch(e) {
        if(e instanceof ClientResponseError && e.response.code==="sso_onboarding_required") {
          const ticket=e.response.data.ticket as string;
          sessionStorage.setItem("do-sso-onboarding-ticket",ticket);
          setOnboardingTicket(ticket);setOnboarding(true);setRegister(true);setOpen(true);
          return;
        }
        throw e;
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
  return <Dialog.Root open={open} onOpenChange={next=>{
    if(!next) {
      entering.current=false;
      if(onboarding) {sessionStorage.removeItem("do-sso-onboarding-ticket");setOnboardingTicket("");setOnboarding(false);setRegister(false);setError("");}
    }
    setOpen(next);
  }}>
    <GameButton className="campus-entry" appearance="primary" disabled={busy} onClick={()=>begin(false)}>{authenticated ? "进入校园" : "登录"}</GameButton>
    {!authenticated && <GameButton disabled={busy} onClick={enterGuest}>游客进入</GameButton>}
    {authenticated && <GameButton disabled={busy} onClick={()=>begin(true)}>账号</GameButton>}
    <Dialog.Portal container={portal}>
      <Dialog.Overlay className="game-dialog-overlay" />
      <Dialog.Content className="game-dialog wardrobe" aria-describedby={undefined}>
        <header className="game-dialog-header">
          <Dialog.Title><PixelText>{onboarding ? register ? "完成统一认证注册" : "绑定已有账号" : token && !accountMode ? "创建角色" : "账号"}</PixelText></Dialog.Title>
          <GameDialogClose />
        </header>
        <div className="wardrobe-content" aria-busy={busy}>
          {!token ? (
            <AccountForm email={email} password={password} passwordConfirm={passwordConfirm} code={code} cooldown={cooldown} register={register} disabled={busy || !ready}
              onEmail={value=>{setEmail(value);setCode("");setCooldown(0);}} onPassword={setPassword} onPasswordConfirm={setPasswordConfirm} onCode={setCode} onSendCode={sendCode} onToggle={()=>setRegister(!register)} onSubmit={()=>void login()}
              onOIDC={oidcEnabled && !onboarding ? ()=>loginOIDC() : undefined} onboarding={onboarding} />
          ) : accountMode ? (<>
            <div className="account-details">
              <PixelText wrap>{`邮箱：${account!.email}`}</PixelText>
              <PixelText wrap>{`大工统一认证：${account!.oidcBound ? account!.oidcSubject ? `已绑定(${account!.oidcSubject})` : "已绑定" : "未绑定"}`}</PixelText>
              {!account!.oidcBound && oidcEnabled && <GameButton disabled={busy} onClick={()=>loginOIDC(true)}>绑定统一认证</GameButton>}
            </div>
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
