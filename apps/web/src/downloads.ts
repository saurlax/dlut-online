export type DesktopPlatform = "windows" | "macos";

// Replace each platform URL with its OSS artifact URL when releases move there.
export const downloads = {
  windows: {
    label: "Windows", architecture: "x86_64", button: "下载 Windows 版",
    url: "https://github.com/saurlax/dlut-online/releases",
  },
  macos: {
    label: "macOS", architecture: "Universal（Apple 芯片与 Intel）", button: "下载 macOS 版",
    url: "https://github.com/saurlax/dlut-online/releases",
  },
} satisfies Record<DesktopPlatform, { label: string; architecture: string; button: string; url: string }>;

export function detectDesktopPlatform(userAgent: string, platform: string, maxTouchPoints = 0): DesktopPlatform | null {
  // iPad desktop mode can identify as a Mac. Mobile devices must not get a desktop recommendation.
  if (/Android|iPhone|iPad|iPod/i.test(userAgent) || (/Mac/i.test(platform) && maxTouchPoints > 1)) return null;
  if (/Windows/i.test(userAgent) || /^Win/i.test(platform)) return "windows";
  if (/Macintosh|Mac OS X/i.test(userAgent) || /^Mac/i.test(platform)) return "macos";
  return null;
}
