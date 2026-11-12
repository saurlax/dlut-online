import * as THREE from "three";
import { nameCanvas, type AnimalState } from "./players";
import type { NearbyAction } from "./nearby-action";
import { loadSprite } from "./sprite-image";

export interface AnimalArt {
  id: string;
  name: string;
  kind: "cat" | "swan" | "duck" | "dog" | "boar";
  sprite?: string;
  temperament?: "friendly" | "wary" | "shy";
}

type Pose = "idle" | "walk1" | "walk2" | "blink" | "sleep" | "breathe" | "groom" | "lick" | "happy";
const catPoses: Pose[] = ["idle", "walk1", "walk2", "blink", "sleep", "breathe", "groom", "lick", "happy"];

function spritePose(pose: AnimalState["pose"], time: number): Pose {
  switch (pose) {
    case "walk":
    case "flee":
    case "chase":
      return Math.floor(time / (pose === "walk" ? 180 : 95)) % 2 ? "walk1" : "walk2";
    case "sleep": return Math.floor(time / 600) % 2 ? "sleep" : "breathe";
    case "groom": return Math.floor(time / 250) % 2 ? "groom" : "lick";
    case "happy": return "happy";
    case "idle": return time % 2600 < 160 ? "blink" : "idle";
  }
}

export async function loadAnimalSprites(art: AnimalArt[]) {
  const images = new Map<string, Promise<HTMLImageElement>>();
  const [heart, anger, animals] = await Promise.all([
    loadSprite("/sprites/animals/heart.png"),
    loadSprite("/sprites/animals/anger.png"),
    Promise.all(art.map(async animal => {
      const key = animal.sprite ?? animal.id;
      if (!images.has(key)) images.set(key, loadSprite(`/sprites/animals/${key}.png`));
      return { ...animal, image: await images.get(key)! };
    })),
  ]);
  return { heart, anger, animals };
}

export type AnimalSprites = Awaited<ReturnType<typeof loadAnimalSprites>>;

function pixelTexture(map: THREE.Texture) {
  map.colorSpace = THREE.SRGBColorSpace;
  map.minFilter = map.magFilter = THREE.NearestFilter;
  map.generateMipmaps = false;
  return map;
}

export class CampusAnimals {
  private readonly geometry = new THREE.PlaneGeometry(20 / 16, 1);
  private readonly lift = new THREE.Vector3();
  private readonly right = new THREE.Vector3();
  private readonly hearts: THREE.Texture;
  private readonly anger: THREE.Texture;
  private readonly residents;
  readonly actions: NearbyAction[] = [];

  constructor(sprites: AnimalSprites, world: THREE.Scene, labels: THREE.Scene, interact: (id: string) => void) {
    this.hearts = pixelTexture(new THREE.Texture(sprites.heart));
    this.hearts.needsUpdate = true;
    this.anger = pixelTexture(new THREE.Texture(sprites.anger));
    this.anger.needsUpdate = true;
    this.residents = new Map(sprites.animals.map((animal, index) => {
      const frameCount = animal.kind === "cat" ? catPoses.length : 3;
      const map = pixelTexture(new THREE.Texture(animal.image));
      map.repeat.x = 1 / frameCount;
      map.needsUpdate = true;
      const material = new THREE.MeshStandardMaterial({ map, alphaTest: 0.5, roughness: 1 });
      const mesh = new THREE.Mesh(this.geometry, material);
      const size = animal.kind === "dog" || animal.kind === "boar" ? 1.8 : animal.kind === "swan" ? 1.4 : 1;
      mesh.scale.setScalar(size);
      world.add(mesh);
      let label: THREE.Sprite | undefined;
      if (animal.name) {
        const canvas = nameCanvas(animal.name);
        label = new THREE.Sprite(new THREE.SpriteMaterial({
          map: pixelTexture(new THREE.CanvasTexture(canvas)), depthTest: false, toneMapped: false,
        }));
        label.scale.set(canvas.width / 12, canvas.height / 12, 1);
        labels.add(label);
      }
      let anger: THREE.Sprite | undefined;
      if (animal.kind === "dog" || animal.kind === "boar") {
        anger = new THREE.Sprite(new THREE.SpriteMaterial({
          map: this.anger, alphaTest: 0.5, depthTest: false, depthWrite: false, toneMapped: false,
        }));
        anger.visible = false;
        anger.renderOrder = 110;
        labels.add(anger);
      }
      const action: NearbyAction | undefined = animal.temperament === "friendly"
        ? { label: "抚摸", x: 0, z: 0, available: false, run: () => interact(animal.id) }
        : undefined;
      const particles: THREE.Sprite[] = [];
      if (action) {
        this.actions.push(action);
        for (let i = 0; i < 3; i++) {
          const heart = new THREE.Sprite(new THREE.SpriteMaterial({
            map: this.hearts, transparent: true, depthTest: false, depthWrite: false, toneMapped: false,
          }));
          heart.visible = false;
          heart.renderOrder = 110;
          heart.scale.set(0.51, 0.44, 1);
          labels.add(heart);
          particles.push(heart);
        }
      }
      mesh.visible = false;
      if (label) label.visible = false;
      const resident = {
        map, frameCount, mesh, label, anger, size, action, particles, phase: index * 73,
        state: undefined as AnimalState | undefined,
        from: new THREE.Vector2(), to: new THREE.Vector2(), position: new THREE.Vector2(),
        received: 0, petStart: -Infinity, chaseStart: -Infinity, attackStart: -Infinity,
      };
      return [animal.id, resident] as const;
    }));
  }

  receive(states: AnimalState[], serverTime: number) {
    const now = performance.now();
    for (const state of states) {
      const resident = this.residents.get(state.id)!;
      resident.to.set(state.x / 16, state.y / 16);
      if (!resident.state) resident.position.copy(resident.to);
      resident.from.copy(resident.position);
      if (state.petAt && state.petAt !== resident.state?.petAt) {
        resident.petStart = now - (serverTime - state.petAt);
      }
      if (state.pose === "chase" && resident.state?.pose !== "chase") resident.chaseStart = now;
      if (state.attackAt && state.attackAt !== resident.state?.attackAt) {
        resident.attackStart = now - (serverTime - state.attackAt);
      }
      resident.state = state;
      resident.received = now;
    }
  }

  clear() {
    for (const resident of this.residents.values()) {
      resident.state = undefined;
      resident.petStart = -Infinity;
      resident.mesh.visible = false;
      if (resident.label) resident.label.visible = false;
      if (resident.anger) resident.anger.visible = false;
      if (resident.action) resident.action.available = false;
      for (const heart of resident.particles) heart.visible = false;
    }
  }

  update(time: number, camera: THREE.Camera, target: THREE.Vector3) {
    this.lift.set(0, 1, 0).applyQuaternion(camera.quaternion);
    this.right.set(1, 0, 0).applyQuaternion(camera.quaternion);
    for (const { mesh, label, anger, size, map, frameCount, state, action, particles, phase, position, from, to, received, petStart, chaseStart, attackStart } of this.residents.values()) {
      if (!state) continue;
      position.lerpVectors(from, to, THREE.MathUtils.clamp((time - received) / 100, 0, 1));
      const { x, y: z } = position;
      const attackAge = time - attackStart;
      const windingUp = attackAge >= 0 && attackAge < 240;
      const striking = attackAge >= 240 && attackAge < 470;
      const strike = striking ? 1 - (attackAge - 240) / 230 : 0;
      const windup = windingUp ? attackAge / 240 : 0;
      const pose = striking ? "walk2" : windingUp ? "idle" : spritePose(state.pose, time + phase);
      if (action) {
        action.x = x;
        action.z = z;
        action.available = state.pose !== "happy";
      }
      mesh.visible = Math.hypot(x - target.x, z - target.z) < 95;
      if (label) label.visible = mesh.visible;
      if (anger) anger.visible = mesh.visible && state.pose === "chase";
      if (mesh.visible) {
        mesh.quaternion.copy(camera.quaternion);
        mesh.rotateZ(state.facing * (0.1 * windup - 0.13 * strike));
        mesh.scale.set(state.facing * size * (1 + strike * 0.13), size * (1 - windup * 0.13), size);
        mesh.position.set(x, 0.025, z).addScaledVector(this.lift, size / 2 - windup * 0.1)
          .addScaledVector(this.right, state.facing * (0.42 * strike - 0.13 * windup));
        const frame = catPoses.indexOf(pose);
        map.offset.x = frame < frameCount ? frame / frameCount : 0;
        if (label) label.position.copy(mesh.position).addScaledVector(this.lift, size / 2 + 0.35);
        if (anger?.visible) {
          const pop = 1 - Math.min(1, (time - chaseStart) / 220);
          anger.position.copy(mesh.position).addScaledVector(this.lift, size / 2 + 0.37 + 0.2 * pop);
          anger.scale.set(0.72 + 0.24 * pop, 0.72 + 0.24 * pop, 1);
        }
      }
      for (const [i, heart] of particles.entries()) {
        const age = (time - petStart - i * 140) / 1000;
        heart.visible = mesh.visible && age >= 0 && age < 1.1;
        if (!heart.visible) continue;
        const side = i - 1;
        heart.position.copy(mesh.position).addScaledVector(this.lift, 0.48 + age * 1.65);
        heart.position.x += side * (0.52 + age * 0.65);
        heart.material.opacity = Math.min(1, (1.1 - age) * 4);
      }
    }
  }

  destroy() {
    this.geometry.dispose();
    this.hearts.dispose();
    this.anger.dispose();
    for (const { map, mesh, label, anger, particles } of this.residents.values()) {
      map.dispose();
      mesh.material.dispose();
      label?.material.map?.dispose();
      label?.material.dispose();
      anger?.material.dispose();
      for (const heart of particles) heart.material.dispose();
    }
  }
}
