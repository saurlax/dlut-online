export const interfaceSizes = [
  { scale: 1, label: "小" },
  { scale: 1.5, label: "标准" },
  { scale: 2, label: "大" },
] as const;

const storageKey = "do-interface-scale";
const changeEvent = "do:interface-scale";

export function interfaceGrid() {
  const saved = Number(localStorage.getItem(storageKey));
  const scale = interfaceSizes.find(size => size.scale === saved)?.scale ?? 1.5;
  const width = Math.floor(window.innerWidth / scale);
  const height = Math.floor(window.innerHeight / scale);
  return { scale, width, height, compact: height < 160 };
}

export function setInterfaceScale(scale: number) {
  localStorage.setItem(storageKey, String(scale));
  window.dispatchEvent(new Event(changeEvent));
}

export function watchInterfaceGrid(update: (grid: ReturnType<typeof interfaceGrid>) => void) {
  const refresh = () => update(interfaceGrid());
  function storage(event: StorageEvent) {
    if (event.key === storageKey || event.key === null) refresh();
  }
  refresh();
  window.addEventListener("resize", refresh);
  window.addEventListener(changeEvent, refresh);
  window.addEventListener("storage", storage);
  return () => {
    window.removeEventListener("resize", refresh);
    window.removeEventListener(changeEvent, refresh);
    window.removeEventListener("storage", storage);
  };
}
