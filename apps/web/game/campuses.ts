export const campuses = [
  { id: "lingshui", name: "凌水主校区" },
  { id: "eda", name: "开发区校区" },
  { id: "panjin", name: "盘锦校区" },
] as const;

export type Campus = (typeof campuses)[number];
