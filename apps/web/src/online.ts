export const campuses = [
  { id: "lingshui", name: "凌水主校区", number: "01" },
  { id: "eda", name: "开发区校区", number: "02" },
  { id: "panjin", name: "盘锦校区", number: "03" },
] as const;
export type CampusID = (typeof campuses)[number]["id"];
export interface Online {
  status: "live" | "stale" | "unavailable";
  total: number | null;
  campuses: Record<CampusID, number> | null;
  received_at: string | null;
}

export function parseOnline(value: unknown): Online {
  if (!value || typeof value !== "object")
    throw new Error("Invalid online response");
  const v = value as Online;
  if (
    !["live", "stale", "unavailable"].includes(v.status) ||
    (v.received_at !== null &&
      (typeof v.received_at !== "string" ||
        !Number.isFinite(Date.parse(v.received_at))))
  ) {
    throw new Error("Invalid online response");
  }
  if (v.status === "live") {
    if (
      !v.received_at ||
      !Number.isInteger(v.total) ||
      v.total! < 0 ||
      !v.campuses ||
      campuses.some(
        (c) => !Number.isInteger(v.campuses![c.id]) || v.campuses![c.id] < 0,
      ) ||
      campuses.reduce((sum, c) => sum + v.campuses![c.id], 0) !== v.total
    ) {
      throw new Error("Invalid online counts");
    }
  }
  return v;
}

export function isLive(
  data: Online | null,
  failed: boolean,
  now: number,
): boolean {
  if (failed || data?.status !== "live" || !data.received_at) return false;
  const age = now - Date.parse(data.received_at);
  return age >= -5000 && age <= 15000;
}
