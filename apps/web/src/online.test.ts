import { test } from "node:test";
import { strict as assert } from "node:assert";
import { isLive, parseOnline, type Online } from "./online.ts";

const now = Date.now();
const sample: Online = {
  status: "live",
  total: 3,
  campuses: { lingshui: 2, eda: 1, panjin: 0 },
  received_at: new Date(now).toISOString(),
};
test("fresh counts expire and requests failing never show historical totals as live", () => {
  assert.equal(isLive(parseOnline(sample), false, now), true);
  assert.equal(isLive(sample, false, now + 15001), false);
  assert.equal(isLive(sample, true, now), false);
  assert.equal(isLive({ ...sample, status: "stale" }, false, now), false);
  assert.equal(isLive(null, false, now), false);
  assert.equal(
    isLive(
      { ...sample, received_at: new Date(now + 6000).toISOString() },
      false,
      now,
    ),
    false,
  );
});
test("valid zero counts differ from unavailable and malformed data", () => {
  assert.equal(
    parseOnline({
      ...sample,
      total: 0,
      campuses: { lingshui: 0, eda: 0, panjin: 0 },
    }).total,
    0,
  );
  assert.equal(
    isLive(
      parseOnline({
        status: "unavailable",
        total: null,
        campuses: null,
        received_at: null,
      }),
      false,
      now,
    ),
    false,
  );
  for (const invalid of [
    {},
    { ...sample, total: 99 },
    { ...sample, campuses: {} },
    { ...sample, received_at: "bad" },
  ]) {
    assert.throws(() => parseOnline(invalid));
  }
});
