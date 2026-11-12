export async function loadSprite(url: string) {
  const image = new Image();
  image.src = url;
  await image.decode();
  return image;
}
