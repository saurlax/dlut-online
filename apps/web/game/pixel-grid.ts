export function pixelGrid() {
  const physicalPixel = Math.max(1, Math.round(2 * window.devicePixelRatio));
  const pixel = physicalPixel / window.devicePixelRatio;
  const width = Math.floor(window.innerWidth / pixel);
  const height = Math.floor(window.innerHeight / pixel);
  return { pixel, physicalPixel, width, height, compact: height < 160 };
}

export type PixelGrid = ReturnType<typeof pixelGrid>;

// Re-arm the query after each change, including moving between displays.
export function watchPixelGrid(update: (grid: PixelGrid) => void) {
  let resolution: MediaQueryList;
  function refresh() {
    resolution?.removeEventListener('change', refresh);
    resolution = window.matchMedia(`(resolution: ${window.devicePixelRatio}dppx)`);
    resolution.addEventListener('change', refresh);
    update(pixelGrid());
  }
  refresh();
  window.addEventListener('resize', refresh);
  return () => {
    window.removeEventListener('resize', refresh);
    resolution.removeEventListener('change', refresh);
  };
}
