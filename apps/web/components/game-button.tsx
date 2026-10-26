import type { ComponentPropsWithRef, ReactNode } from 'react';
import './game-button.css';

type IconName = 'sprout' | 'settings' | 'fullscreen' | 'window' | 'home';
type Appearance = 'primary' | 'secondary' | 'icon';

export function GameIcon({ name }: { name: IconName }) {
  return (
    <svg className="game-icon" viewBox="0 0 16 16" aria-hidden="true" shapeRendering="crispEdges">
      {name === 'sprout' && <>
        <path fill="currentColor" d="M1 9h4l3 2 3-2h4v5h-4l-3 2-3-2H1z" />
        <path fill="#fff3d0" d="M2 10h3l3 2v2l-3-2H2zm12 0h-3l-3 2v2l3-2h3z" />
        <path fill="#3c764a" d="M7 4h2v7H7zM2 1h3l3 3v2H5L2 3zm7 3 3-3h3v3l-3 3H9z" />
        <path fill="#9bc85b" d="M3 2h2l2 2H5zm7 3 2-2h2v1l-2 2h-2z" />
      </>}
      {name === 'settings' && <path fill="currentColor" fillRule="evenodd" d="M6 1h4v2h2V2h2v2h-1v2h2v4h-2v2h1v2h-2v-1h-2v2H6v-2H4v1H2v-2h1v-2H1V6h2V4H2V2h2v1h2V1ZM6 6v4h4V6H6Z" />}
      {name === 'fullscreen' && <path fill="currentColor" d="M1 1h5v2H3v3H1zm9 0h5v5h-2V3h-3zM1 10h2v3h3v2H1zm12 0h2v5h-5v-2h3z" />}
      {name === 'window' && <path fill="currentColor" fillRule="evenodd" d="M1 2h14v12H1zm2 4v6h10V6z" />}
      {name === 'home' && <path fill="currentColor" d="M7 1h2v2h2v2h2v2h2v2h-2v6H9v-4H7v4H3V9H1V7h2V5h2V3h2z" />}
    </svg>
  );
}

function ButtonContents({ icon, children }: { icon: IconName; children?: ReactNode }) {
  return <><span className="game-button-icon"><GameIcon name={icon} /></span>{children && <span className="game-button-label">{children}</span>}</>;
}

type ButtonStyle = { icon: IconName; appearance?: Appearance };

export function GameButton({ icon, appearance = 'secondary', children, className = '', ...props }: ButtonStyle & ComponentPropsWithRef<'button'>) {
  return <button type="button" {...props} className={`game-button game-button--${appearance} ${className}`}><ButtonContents icon={icon}>{children}</ButtonContents></button>;
}

export function GameLink({ icon, appearance = 'primary', children, className = '', ...props }: ButtonStyle & ComponentPropsWithRef<'a'>) {
  return <a {...props} className={`game-button game-button--${appearance} ${className}`}><ButtonContents icon={icon}>{children}</ButtonContents></a>;
}
