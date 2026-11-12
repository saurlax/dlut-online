export interface NearbyAction {
  label: string;
  x: number;
  z: number;
  available: boolean;
  run: () => void;
}
