import type { Campus } from "./campuses";

export type Coordinate = [number, number];
export interface AtlasLandmark {
  key: string;
  id: string;
  campus: Campus["id"];
  name: string;
  primary: boolean;
  point: Coordinate;
  polygon: Coordinate[];
  holes: Coordinate[][];
  image?: string;
  view?: "front" | "plan";
  spritePoint?: Coordinate;
  widthMeters?: number;
}
export interface AtlasCampus {
  id: Campus["id"];
  name: string;
  bounds: [Coordinate, Coordinate];
  coordinates: [Coordinate, Coordinate, Coordinate, Coordinate];
  center: Coordinate;
  image: string;
}
export interface WorldAtlas {
  bounds: [Coordinate, Coordinate];
  image: string;
  coordinates: [Coordinate, Coordinate, Coordinate, Coordinate];
  campuses: AtlasCampus[];
  places: { point: Coordinate; name: string; population: number }[];
  landmarks: AtlasLandmark[];
  labels: {key: string; name: string; point: Coordinate; kind: "road" | "area" | "place" | "building"; minZoom: number}[];
}
