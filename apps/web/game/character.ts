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
const skins = ["#e9b58c", "#c78b61", "#a06547", "#754732"];
const hairColors = ["#352c31", "#835234", "#d9a957", "#243f66"];
const clothes = ["#2877b4", "#ac5a65", "#53976d", "#d2a255"];
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
  const c = canvas.getContext("2d")!;
  c.imageSmoothingEnabled = false;
  const rect = (x: number, y: number, w: number, h: number, color: string) => {
    c.fillStyle = color;
    c.fillRect(x, y, w, h);
  };
  const skin = skins[a.skin],
    hair = hairColors[a.hairColor];
  const outfit = (slot: string) => wear.find((v) => v.key === slot);
  const top = outfit("shirt"),
    bottom = outfit("trousers") || outfit("skirt"),
    shoes = outfit("sneakers"),
    hat = outfit("cap");
  const sway = step === 1 ? 1 : step === 2 ? -1 : 0,
    side = direction === 1 || direction === 3,
    back = direction === 2;
  if (a.hair === 2 || a.hair === 3) rect(3, 5, 10, 17, hair);
  rect(5, 18, 6, 8, skin);
  rect(4, 25, 3, 5 + sway, skin);
  rect(9, 25, 3, 5 - sway, skin);
  rect(4, 19, 8, 6, "#f4e3cc");
  if (bottom) {
    const color = clothes[bottom.color];
    rect(4, 22, 8, bottom.key === "skirt" ? 6 : 3, color);
    if (bottom.key === "trousers") {
      rect(4, 25, 3, 4 + sway, color);
      rect(9, 25, 3, 4 - sway, color);
    }
  }
  if (shoes) {
    rect(3, 29 + sway, 4, 2, "#29384c");
    rect(9, 29 - sway, 4, 2, "#29384c");
    rect(3, 31 + sway, 4, 1, "#dce5dd");
    rect(9, 31 - sway, 4, 1, "#dce5dd");
  }
  const female = gender === "female";
  rect(female ? 5 : 4, 15, female ? 6 : 8, 8, top ? clothes[top.color] : "#f4e3cc");
  if (top) {
    rect(7, 16, 2, 5, "#a4ced8");
    rect(7, 21, 1, 1, "#163c66");
  }
  const leftArm = side ? 5 : female ? 3 : 2, rightArm = female ? 11 : 12;
  rect(leftArm, 17, 2, 6 + sway, skin);
  rect(rightArm, 17, 2, 6 - sway, skin);
  if (top) {
    rect(leftArm, 16, 2, 3, clothes[top.color]);
    rect(rightArm, 16, 2, 3, clothes[top.color]);
  }
  rect(a.face === 0 ? 4 : 3, 4, a.face === 0 ? 8 : 10, 9, skin);
  rect(5, 12, 6, 3, skin);
  rect(3, 7, 1, 3, skin);
  rect(12, 7, 1, 3, skin);
  rect(4, 2, 8, 3, hair);
  rect(3, 4, 10, 3, hair);
  if (back) {
    rect(3, 6, 10, 7, hair);
    if (a.hair === 1) rect(10, 9, 4, 6, hair);
  } else {
    rect(3, 6, 2, a.hair === 0 ? 3 : 7, hair);
    if (!side) rect(11, 6, 2, a.hair === 0 ? 3 : 7, hair);
    if (a.hair === 3) rect(5, 6, 5, 2, hair);
    if (a.hair === 1) rect(5, 5, 6, 2, "#af7747");
    const eye = ["#24384c", "#49724b", "#72543d"][a.eyes];
    rect(side ? 10 : 5, 9, 1, 2, eye);
    if (!side) rect(10, 9, 1, 2, eye);
    if (a.brows) {
      rect(side ? 10 : 5, 8, 2, 1, hair);
      if (!side) rect(9, 8, 2, 1, hair);
    }
    if (a.freckles) {
      rect(4, 11, 2, 1, "#b57b59");
      if (!side) rect(10, 11, 2, 1, "#b57b59");
    }
    if (a.beard) rect(5, 12, 6, 3, hair);
    rect(side ? 12 : 8, 11, 1, a.nose ? 2 : 1, "#b57b59");
    rect(side ? 10 : 7, 13, a.mouth ? 3 : 2, 1, "#8d5050");
  }
  if (hat) {
    rect(3, 2, 10, 4, clothes[hat.color]);
    rect(4, 1, 8, 1, clothes[hat.color]);
    rect(side ? 8 : 2, 6, side ? 7 : 12, 1, "#194975");
    if (!back) rect(7, 3, 2, 2, "#e8dfae");
  }
  const pack = wear.find(v => v.key.startsWith("backpack_"));
  if (pack) {
    if (back) {
      rect(4, 16, 8, 10, "#183c59");
      rect(5, 17, 6, 8, clothes[pack.color]);
      rect(5, 21, 6, 1, "#183c59");
      rect(7, 18, 2, 2, "#e8dfae");
    } else if (side) {
      rect(2, 17, 3, 8, "#183c59");
      rect(2, 18, 2, 6, clothes[pack.color]);
    } else {
      rect(4, 16, 1, 7, "#183c59");
      rect(11, 16, 1, 7, "#183c59");
    }
  }
  if (direction === 3) {
    const copy = document.createElement("canvas");
    copy.width = 16;
    copy.height = 32;
    copy.getContext("2d")!.drawImage(canvas, 0, 0);
    c.clearRect(0, 0, 16, 32);
    c.save();
    c.translate(16, 0);
    c.scale(-1, 1);
    c.drawImage(copy, 0, 0);
    c.restore();
  }
}
