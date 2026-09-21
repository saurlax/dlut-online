export type DownloadPlatform = "windows" | "macos" | "android";

// Replace each platform URL with its OSS artifact URL when releases move there.
export const downloads = {
  windows: {
    label: "Windows", architecture: "x86_64", button: "下载 Windows 版",
    url: "https://github.com/saurlax/dlut-online/releases/latest/download/DLUT-Online-Windows.exe",
  },
  macos: {
    label: "macOS", architecture: "Apple 芯片（arm64）", button: "下载 macOS 版",
    url: "https://github.com/saurlax/dlut-online/releases/latest/download/DLUT-Online-macOS.dmg",
  },
  android: {
    label: "Android 测试版", architecture: "arm64 APK", button: "下载 Android 测试版",
    url: "https://github.com/saurlax/dlut-online/releases/latest/download/DLUT-Online-Android.apk",
  },
} satisfies Record<DownloadPlatform, { label: string; architecture: string; button: string; url: string }>;

export function detectDownloadPlatform(userAgent: string, platform: string, maxTouchPoints = 0): DownloadPlatform | null {
  if (/Android/i.test(userAgent)) return "android";
  // iPad desktop mode can identify as a Mac. Mobile devices must not get a desktop recommendation.
  if (/iPhone|iPad|iPod/i.test(userAgent) || (/Mac/i.test(platform) && maxTouchPoints > 1)) return null;
  if (/Windows/i.test(userAgent) || /^Win/i.test(platform)) return "windows";
  if (/Macintosh|Mac OS X/i.test(userAgent) || /^Mac/i.test(platform)) return "macos";
  return null;
}
