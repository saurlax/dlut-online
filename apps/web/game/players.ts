import * as THREE from "three";
import { drawCharacter, type Appearance, type Gender } from "./character";

export interface MovementInput { seq: number; x: number; y: number; ms: number; sprint: boolean }
export interface PlayerState {
  id: string; x: number; y: number; direction: number; moving: boolean; sprint: boolean; ack: number; revision: number;
  look: { name: string; gender: Gender; appearance: Appearance; wear: { key: string; color: number }[] };
}
export interface WorldSnapshot { selfId: string; players: PlayerState[] }

export function nameCanvas(name: string) {
  const canvas = document.createElement("canvas"), context = canvas.getContext("2d")!;
  context.font = '12px "Fusion Pixel"';
  canvas.width = 2 * Math.ceil((context.measureText(name).width + 2) / 2);
  canvas.height = 14;
  context.font = '12px "Fusion Pixel"';
  context.fillStyle = "#fff3d0";
  context.fillText(name, 0, 10);
  const pixels = context.getImageData(0, 0, canvas.width, canvas.height);
  for (let i = 3; i < pixels.data.length; i += 4) pixels.data[i] = pixels.data[i] >= 128 ? 255 : 0;
  context.putImageData(pixels, 0, 0);
  return canvas;
}

function texture(canvas: HTMLCanvasElement) {
  const map = new THREE.CanvasTexture(canvas);
  map.colorSpace = THREE.SRGBColorSpace;
  map.magFilter = map.minFilter = THREE.NearestFilter;
  map.generateMipmaps = false;
  return map;
}

interface RemotePlayer {
  state: PlayerState;
  mesh: THREE.Mesh<THREE.PlaneGeometry, THREE.MeshStandardMaterial>;
  label: THREE.Sprite;
  canvas: HTMLCanvasElement;
  from: THREE.Vector2; to: THREE.Vector2; position: THREE.Vector2;
  received: number; pose: string; look: string;
}

export class RemotePlayers {
  private readonly geometry = new THREE.PlaneGeometry(1, 2);
  private readonly players = new Map<string, RemotePlayer>();
  private readonly up = new THREE.Vector3();

  constructor(private readonly world: THREE.Scene, private readonly labels: THREE.Scene, private readonly camera: THREE.Camera) {}

  receive(snapshot: WorldSnapshot) {
    const ids = new Set(snapshot.players.filter(p => p.id !== snapshot.selfId).map(p => p.id));
    for (const [id, remote] of this.players) if (!ids.has(id)) { this.remove(remote); this.players.delete(id); }
    for (const state of snapshot.players) {
      if (state.id === snapshot.selfId) continue;
      let remote = this.players.get(state.id);
      if (!remote) {
        const canvas = document.createElement("canvas");
        const mesh = new THREE.Mesh(this.geometry, new THREE.MeshStandardMaterial({ map: texture(canvas), alphaTest: 0.5, side: THREE.DoubleSide, roughness: 1 }));
        mesh.castShadow = mesh.receiveShadow = true;
        const label = new THREE.Sprite(new THREE.SpriteMaterial({ depthTest: false, toneMapped: false }));
        remote = { state, mesh, label, canvas, from: new THREE.Vector2(state.x, state.y), to: new THREE.Vector2(state.x, state.y), position: new THREE.Vector2(state.x, state.y), received: performance.now(), pose: "", look: "" };
        this.players.set(state.id, remote);
        this.world.add(mesh); this.labels.add(label);
      }
      remote.from.copy(remote.position);
      remote.to.set(state.x, state.y);
      if (state.revision !== remote.state.revision) { remote.position.copy(remote.to); remote.from.copy(remote.to); }
      remote.received = performance.now();
      remote.state = state;
      const look = JSON.stringify(state.look);
      if (look !== remote.look) {
        remote.look = look; remote.pose = "";
        const canvas = nameCanvas(state.look.name);
        remote.label.material.map?.dispose();
        remote.label.material.map = texture(canvas);
        remote.label.material.needsUpdate = true;
        remote.label.scale.set(canvas.width / 12, canvas.height / 12, 1);
      }
    }
  }

  update(time: number) {
    this.up.set(0, 1, 0).applyQuaternion(this.camera.quaternion);
    for (const remote of this.players.values()) {
      const state = remote.state;
      remote.position.lerpVectors(remote.from, remote.to, Math.min(1, (time - remote.received) / 100));
      remote.mesh.position.set(remote.position.x / 16, 0, remote.position.y / 16).add(this.up);
      remote.mesh.quaternion.copy(this.camera.quaternion);
      remote.label.position.copy(remote.mesh.position).addScaledVector(this.up, 1.7);
      const step = state.moving ? Math.floor(time / (state.sprint ? 80 : 120)) % 3 : 0;
      const pose = `${state.direction}:${step}`;
      if (pose !== remote.pose) {
        drawCharacter(remote.canvas, state.look.appearance, state.look.wear, state.direction, step, state.look.gender);
        remote.mesh.material.map!.needsUpdate = true;
        remote.pose = pose;
      }
    }
  }

  private remove(remote: RemotePlayer) {
    this.world.remove(remote.mesh); this.labels.remove(remote.label);
    remote.mesh.material.map!.dispose(); remote.mesh.material.dispose();
    remote.label.material.map!.dispose(); remote.label.material.dispose();
  }

  clear() { this.players.forEach(p => this.remove(p)); this.players.clear(); }
  destroy() { this.clear(); this.geometry.dispose(); }
}
