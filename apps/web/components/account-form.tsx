"use client";

import { GameButton } from "./game-button";
import PixelText from "./pixel-text";

export default function AccountForm({email,password,passwordConfirm,code,cooldown,register,disabled,onEmail,onPassword,onPasswordConfirm,onCode,onSendCode,onToggle,onSubmit,onOIDC,onGuest,onboarding=false}:{
  email:string; password:string; passwordConfirm:string; code:string; cooldown:number; register:boolean; disabled:boolean;
  onEmail:(value:string)=>void; onPassword:(value:string)=>void;
  onPasswordConfirm:(value:string)=>void; onCode:(value:string)=>void; onSendCode:()=>void;
  onToggle:()=>void; onSubmit:()=>void; onOIDC?:()=>void; onGuest?:()=>void; onboarding?:boolean;
}) {
  return <form onSubmit={event=>{event.preventDefault();onSubmit();}}>
    {onGuest && !register && <GameButton className="sso-login" disabled={disabled} onClick={onGuest}>游客登录</GameButton>}
    {onOIDC && <GameButton className="sso-login" appearance="primary" disabled={disabled} onClick={onOIDC}>大工统一认证</GameButton>}
    <label>
      <PixelText>邮箱</PixelText>
      <input aria-label="邮箱" type="email" autoComplete="email" required value={email} onChange={event=>onEmail(event.target.value)} />
    </label>
    {register && <label>
      <PixelText>邮箱验证码</PixelText>
      <div className="verification-code-row">
        <input aria-label="邮箱验证码" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" maxLength={6} required value={code} onChange={event=>onCode(event.target.value)} />
        <GameButton disabled={disabled || cooldown>0} onClick={onSendCode}>{cooldown>0 ? `${cooldown}秒后重发` : "发送验证码"}</GameButton>
      </div>
    </label>}
    <label>
      <PixelText>密码</PixelText>
      <input aria-label="密码" type="password" autoComplete={register ? "new-password" : "current-password"} minLength={8} required value={password} onChange={event=>onPassword(event.target.value)} />
    </label>
    {register && <label>
      <PixelText>确认密码</PixelText>
      <input aria-label="确认密码" type="password" autoComplete="new-password" minLength={8} required value={passwordConfirm} onChange={event=>onPasswordConfirm(event.target.value)} />
    </label>}
    <GameButton type="submit" disabled={disabled}>{onboarding ? register ? "注册并绑定" : "登录并绑定" : register ? "注册并登录" : "登录"}</GameButton>
    <GameButton disabled={disabled} onClick={onToggle}>{register ? "已有账号" : "注册账号"}</GameButton>
  </form>;
}
