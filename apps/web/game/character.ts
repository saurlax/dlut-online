import { loadSprite } from "./sprite-image";

export interface Appearance {
  brows: number;
  beard: number;
  freckles: number;
  skin: number;
  hair: number;
  hairColor: number;
  eyes: number;
  face: number;
  nose: number;
  mouth: number;
}
export interface Item {
  id: string;
  key: string;
  name: string;
  slotId: string;
  capacity: number;
}
export interface Owned {
  id: string;
  itemId: string;
  slotId: string;
  color: number;
}
export type Gender = "male" | "female" | "unspecified";
export interface CharacterState {
  profile: { name: string; gender: Gender; appearance: Appearance } | null;
  defaults?: { name: string; gender: Gender };
  inventory: Owned[];
  capacity: number;
}
export const initialAppearance: Appearance = {
  brows: 0,
  beard: 0,
  freckles: 0,
  skin: 0,
  hair: 0,
  hairColor: 0,
  eyes: 0,
  face: 0,
  nose: 0,
  mouth: 0,
};

const spriteLayers = [
  "hair-back", "body", "trousers", "skirt", "sneakers", "torso", "shirt", "arms", "sleeves",
  "face", "hair", "eyes", "brows", "freckles", "beard", "nose", "mouth", "cap", "backpack",
] as const;
type SpriteLayer = typeof spriteLayers[number];

const sprites = new Map<SpriteLayer, HTMLImageElement>();
let loadingSprites: Promise<void> | undefined;

export function loadCharacterSprites() {
  return loadingSprites ??= Promise.all(spriteLayers.map(async layer => {
    sprites.set(layer, await loadSprite(`/sprites/characters/${layer}.png`));
  })).then(() => {}).catch(error => {
    loadingSprites = undefined;
    throw error;
  });
}

export function drawCharacter(
  canvas: HTMLCanvasElement,
  a: Appearance,
  wear: { key: string; color: number }[],
  direction = 0,
  step = 0,
  gender: Gender = "unspecified",
) {
  canvas.width = 16;
  canvas.height = 32;
  const context = canvas.getContext("2d")!;
  context.imageSmoothingEnabled = false;
  const frameX = (direction * 3 + step) * 16;
  const draw = (layer: SpriteLayer, row: number) => {
    context.drawImage(sprites.get(layer)!, frameX, row * 32, 16, 32, 0, 0, 16, 32);
  };

  const outfit = (key: string) => wear.find(item => item.key === key);
  const shirt = outfit("shirt");
  const trousers = outfit("trousers");
  const skirt = outfit("skirt");
  const cap = outfit("cap");
  const backpack = wear.find(item => item.key.startsWith("backpack_"));
  const body = gender === "female" ? 1 : 0;
  const hair = a.hair * 4 + a.hairColor;

  if (a.hair >= 2) draw("hair-back", hair);
  draw("body", a.skin);
  if (trousers) draw("trousers", trousers.color);
  else if (skirt) draw("skirt", skirt.color);
  if (outfit("sneakers")) draw("sneakers", 0);
  if (shirt) draw("shirt", body * 4 + shirt.color);
  else draw("torso", body);
  draw("arms", body * 4 + a.skin);
  if (shirt) draw("sleeves", body * 4 + shirt.color);
  draw("face", a.face * 4 + a.skin);
  draw("hair", hair);
  if (direction !== 2) {
    draw("eyes", a.eyes);
    if (a.brows) draw("brows", a.hairColor);
    if (a.freckles) draw("freckles", 0);
    if (a.beard) draw("beard", a.hairColor);
    draw("nose", a.nose);
    draw("mouth", a.mouth);
  }
  if (cap) draw("cap", cap.color);
  if (backpack) draw("backpack", backpack.color);
}
