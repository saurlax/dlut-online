import type { ComponentPropsWithRef } from 'react';
import PixelText from './pixel-text';
import './game-button.css';

type IconName = 'sprout' | 'settings' | 'fullscreen' | 'window' | 'home' | 'info';
type Appearance = 'primary' | 'secondary' | 'icon';

export function GameIcon({ name }: { name: IconName }) {
  return (
    <svg className="game-icon" viewBox="0 0 16 16" aria-hidden="true" shapeRendering="crispEdges">
      {name === 'sprout' && <>
        <path fill="currentColor" d="M1 9h4v1h2v1h2v-1h2V9h4v5h-4v1H9v1H7v-1H5v-1H1z" />
        <path fill="#fff3d0" d="M2 10h3v1h2v1h1v2H7v-1H5v-1H2zm12 0h-3v1H9v1H8v2h1v-1h2v-1h3z" />
        <path fill="#3c764a" d="M7 4h2v7H7zM2 1h3v1h1v1h1v1h1v2H5V5H4V4H3V3H2zm7 3h1V3h1V2h1V1h3v3h-1v1h-1v1h-1v1H9z" />
        <path fill="#9bc85b" d="M3 2h2v1h1v1H5V3H3zm7 3h1V4h1V3h2v1h-1v1h-1v1h-2z" />
      </>}
      {name === 'settings' && <path fill="currentColor" fillRule="evenodd" d="M6 1h4v2h2V2h2v2h-1v2h2v4h-2v2h1v2h-2v-1h-2v2H6v-2H4v1H2v-2h1v-2H1V6h2V4H2V2h2v1h2V1ZM6 6v4h4V6H6Z" />}
      {name === 'fullscreen' && <path fill="currentColor" d="M1 1h5v2H3v3H1zm9 0h5v5h-2V3h-3zM1 10h2v3h3v2H1zm12 0h2v5h-5v-2h3z" />}
      {name === 'window' && <path fill="currentColor" fillRule="evenodd" d="M1 2h14v12H1zm2 4v6h10V6z" />}
      {name === 'home' && <path fill="currentColor" d="M7 1h2v2h2v2h2v2h2v2h-2v6H9v-4H7v4H3V9H1V7h2V5h2V3h2z" />}
      {name === 'info' && <path fill="currentColor" fillRule="evenodd" d="M4 1h8v2h2v2h1v6h-1v2h-2v2H4v-2H2v-2H1V5h1V3h2zm1 2v2H3v6h2v2h6v-2h2V5h-2V3zM7 4h2v2H7zm0 3h2v5H7z" />}
    </svg>
  );
}

function ButtonContents({ icon, children }: { icon: IconName; children?: string }) {
  return <><span className="game-button-icon"><GameIcon name={icon} /></span>{children && <span className="game-button-label"><PixelText>{children}</PixelText></span>}</>;
}

type ButtonStyle = { icon: IconName; appearance?: Appearance; children?: string };

export function GameButton({ icon, appearance = 'secondary', children, className = '', ...props }: ButtonStyle & ComponentPropsWithRef<'button'>) {
  return <button type="button" {...props} className={`game-button game-button--${appearance} ${className}`}><ButtonContents icon={icon}>{children}</ButtonContents></button>;
}

export function GameLink({ icon, appearance = 'primary', children, className = '', ...props }: ButtonStyle & ComponentPropsWithRef<'a'>) {
  return <a {...props} className={`game-button game-button--${appearance} ${className}`}><ButtonContents icon={icon}>{children}</ButtonContents></a>;
}
