import assert from "node:assert/strict";
import test from "node:test";
import { detectDesktopPlatform } from "./downloads.ts";

test("desktop downloads distinguish supported systems from mobile and unknown clients", () => {
  assert.equal(detectDesktopPlatform("Mozilla/5.0 (Windows NT 10.0; Win64; x64)", "Win32"), "windows");
  assert.equal(detectDesktopPlatform("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", "MacIntel"), "macos");
  assert.equal(detectDesktopPlatform("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", "MacIntel", 5), null);
  assert.equal(detectDesktopPlatform("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", "iPhone", 5), null);
  assert.equal(detectDesktopPlatform("Mozilla/5.0 (Linux; Android 15)", "Linux armv8l", 5), null);
  assert.equal(detectDesktopPlatform("Mozilla/5.0 (X11; Linux x86_64)", "Linux x86_64"), null);
  assert.equal(detectDesktopPlatform("", ""), null);
});
