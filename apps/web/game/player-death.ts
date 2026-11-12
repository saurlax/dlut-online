import * as THREE from "three";
import type { WorldSnapshot } from "./players";

export function posePlayer(mesh: THREE.Mesh<THREE.BufferGeometry, THREE.MeshStandardMaterial>, camera: THREE.Quaternion, up: THREE.Vector3, deathStart: number | null, protectionEnd: number, time: number) {
  mesh.quaternion.copy(camera);
  const progress = deathStart === null ? 0 : THREE.MathUtils.clamp((time - deathStart) / 360, 0, 1);
  const fall = progress * progress;
  mesh.rotateZ(-Math.PI / 2 * fall);
  mesh.position.addScaledVector(up, 1 - 0.5 * fall);
  const protectedNow = deathStart === null && time < protectionEnd;
  const material = mesh.material;
  if (material.transparent !== protectedNow) {
    material.transparent = protectedNow;
    material.alphaTest = protectedNow ? 0.3 : 0.5;
  }
  material.opacity = protectedNow ? (Math.floor((protectionEnd - time) / 145) % 2 ? 0.4 : 0.75) : 1;
}

const smokeLife = 1700;
const puffs = [
  { x: -0.32, rise: 1.5, delay: 100, size: 0.65 },
  { x: 0.17, rise: 2.3, delay: 180, size: 0.85 },
  { x: 0.39, rise: 1.7, delay: 270, size: 0.68 },
  { x: -0.15, rise: 2.1, delay: 320, size: 0.8 },
  { x: 0.02, rise: 1.8, delay: 440, size: 0.73 },
];

export class DeathSmoke {
  private readonly map: THREE.Texture;
  private readonly bursts = new Map<string, { x: number; z: number; start: number; sprites: THREE.Sprite[] }>();
  private readonly seen = new Map<string, number>();
  private readonly up = new THREE.Vector3();
  private readonly right = new THREE.Vector3();

  constructor(private readonly scene: THREE.Scene, image: HTMLImageElement) {
    this.map = new THREE.Texture(image);
    this.map.colorSpace = THREE.SRGBColorSpace;
    this.map.magFilter = this.map.minFilter = THREE.NearestFilter;
    this.map.generateMipmaps = false;
    this.map.needsUpdate = true;
  }

  receive(snapshot: WorldSnapshot) {
    const dead = new Set<string>();
    for (const player of snapshot.players) {
      if (!player.deathAt) continue;
      dead.add(player.id);
      if (this.seen.get(player.id) === player.deathAt) continue;
      this.seen.set(player.id, player.deathAt);
      const age = snapshot.time - player.deathAt;
      if (age >= smokeLife) continue;
      const sprites = puffs.map(() => {
        const sprite = new THREE.Sprite(new THREE.SpriteMaterial({
          map: this.map, transparent: true, depthWrite: false, depthTest: false, toneMapped: false,
        }));
        sprite.renderOrder = 105;
        sprite.visible = false;
        this.scene.add(sprite);
        return sprite;
      });
      this.bursts.set(player.id, { x: player.x / 16, z: player.y / 16, start: performance.now() - age, sprites });
    }
    for (const id of this.seen.keys()) if (!dead.has(id)) this.seen.delete(id);
  }

  update(time: number, camera: THREE.Quaternion) {
    this.up.set(0, 1, 0).applyQuaternion(camera);
    this.right.set(1, 0, 0).applyQuaternion(camera);
    for (const [id, burst] of this.bursts) {
      const elapsed = time - burst.start;
      if (elapsed >= smokeLife) {
        this.remove(burst.sprites);
        this.bursts.delete(id);
        continue;
      }
      burst.sprites.forEach((sprite, index) => {
        const puff = puffs[index];
        const age = (elapsed - puff.delay) / 1150;
        sprite.visible = age >= 0 && age < 1;
        if (!sprite.visible) return;
        sprite.position.set(burst.x, 0, burst.z).addScaledVector(this.up, 0.4 + age * puff.rise)
          .addScaledVector(this.right, puff.x * (1 + age));
        sprite.scale.setScalar(puff.size * (0.5 + age));
        sprite.material.opacity = 0.92 * (1 - age);
      });
    }
  }

  private remove(sprites: THREE.Sprite[]) {
    for (const sprite of sprites) {
      this.scene.remove(sprite);
      sprite.material.dispose();
    }
  }

  clear() {
    this.bursts.forEach(burst => this.remove(burst.sprites));
    this.bursts.clear();
    this.seen.clear();
  }

  destroy() {
    this.clear();
    this.map.dispose();
  }
}
