"use client";

import * as Dialog from "@radix-ui/react-dialog";
import PixelText from "./pixel-text";

export default function GameDialogClose() {
  return <Dialog.Close className="game-dialog-close" aria-label="关闭"><PixelText>X</PixelText></Dialog.Close>;
}
