import * as THREE from "three";

interface Lamp {
  id: string;
  kind: "street" | "ring";
  position: [number, number];
  direction: [number, number];
  height: number;
}

interface Noticeboard {
  id: string;
  position: [number, number];
  direction: [number, number];
  width: number;
  height: number;
  topBarWidth: number;
  panelBottom: number;
  panelHeight: number;
}

export interface SiteFixtureData { lamps: Lamp[]; noticeboards: Noticeboard[] }

export class SiteFixtures {
  readonly root = new THREE.Group();
  private readonly geometries: THREE.BufferGeometry[] = [];
  private readonly materials: THREE.Material[] = [];
  private readonly lamps: { position: THREE.Vector3; target: THREE.Vector3; intensity: number }[] = [];
  private readonly poles: THREE.Vector2[] = [];
  private readonly boards: { center: THREE.Vector2; axis: THREE.Vector2; halfWidth: number }[] = [];
  private readonly lights: THREE.SpotLight[] = [];
  private readonly metal = this.surface(0xa7b6b2, 0.25);
  private readonly rim = this.surface(0x536860, 0.15);
  private readonly lens = this.surface(0xeee5ca);
  private readonly wood = this.surface(0x665047);
  private readonly trim = this.surface(0xb4b7ab);
  private readonly panel = this.surface(0xb8bcb3);
  private readonly glowTexture = this.makeGlow();
  private readonly glow = new THREE.SpriteMaterial({ map: this.glowTexture, color: 0xffd197, opacity: 0, blending: THREE.AdditiveBlending, transparent: true, depthWrite: false, toneMapped: false });
  private lightingTick = -1;

  constructor(data: SiteFixtureData, offset: [number, number]) {
    this.root.name = "EDA outdoor fixtures";
    this.lens.emissive.set(0xffc786);
    this.materials.push(this.glow);
    for (const lamp of data.lamps) {
      const group = new THREE.Group();
      group.name = lamp.id;
      group.position.set(lamp.position[0] - offset[0], 0, lamp.position[1] - offset[1]);
      group.rotation.y = Math.atan2(-lamp.direction[1], lamp.direction[0]);
      this.root.add(group);
      const head = lamp.kind === "street" ? this.streetLamp(group, lamp.height) : this.ringLamp(group);
      const glow = new THREE.Sprite(this.glow);
      glow.position.copy(head);
      glow.scale.setScalar(lamp.kind === "street" ? 1.8 : 1.4);
      group.add(glow);
      const position = head.clone().applyAxisAngle(new THREE.Vector3(0, 1, 0), group.rotation.y).add(group.position);
      this.lamps.push({ position, target: new THREE.Vector3(position.x + lamp.direction[0] * 1.2, 0.02, position.z + lamp.direction[1] * 1.2), intensity: lamp.kind === "street" ? 140 : 55 });
      this.poles.push(new THREE.Vector2(group.position.x, group.position.z));
    }
    for (const board of data.noticeboards) {
      const group = new THREE.Group();
      group.name = board.id;
      group.position.set(board.position[0] - offset[0], 0, board.position[1] - offset[1]);
      group.rotation.y = Math.atan2(-board.direction[1], board.direction[0]);
      this.root.add(group);
      this.noticeboard(group, board);
      this.boards.push({ center: new THREE.Vector2(group.position.x, group.position.z), axis: new THREE.Vector2(...board.direction), halfWidth: board.width / 2 });
    }
    // A fixed pool keeps shader light counts stable and limits per-pixel cost.
    for (let i = 0; i < Math.min(4, this.lamps.length); i++) {
      const light = new THREE.SpotLight(0xffd3a1, 0, 16, Math.PI / 3, 0.75, 2);
      light.castShadow = false;
      this.lights.push(light);
      this.root.add(light, light.target);
    }
  }

  private surface(color: number, metalness = 0) {
    const material = new THREE.MeshStandardMaterial({ color, roughness: 0.8, metalness });
    this.materials.push(material);
    return material;
  }

  private mesh(parent: THREE.Group, geometry: THREE.BufferGeometry, material: THREE.Material, x: number, y: number, z: number) {
    this.geometries.push(geometry);
    const mesh = new THREE.Mesh(geometry, material);
    mesh.position.set(x, y, z);
    mesh.castShadow = mesh.receiveShadow = true;
    parent.add(mesh);
    return mesh;
  }

  private box(parent: THREE.Group, material: THREE.Material, x: number, y: number, z: number, width: number, height: number, depth: number) {
    return this.mesh(parent, new THREE.BoxGeometry(width, height, depth), material, x, y, z);
  }

  private cylinder(parent: THREE.Group, bottom: number, top: number, height: number, x: number, y: number, z: number) {
    return this.mesh(parent, new THREE.CylinderGeometry(top, bottom, height, 8), this.metal, x, y, z);
  }

  private strut(parent: THREE.Group, a: THREE.Vector3, b: THREE.Vector3, radius: number) {
    const center = a.clone().add(b).multiplyScalar(0.5);
    const pole = this.cylinder(parent, radius, radius, a.distanceTo(b), center.x, center.y, center.z);
    pole.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), b.clone().sub(a).normalize());
  }

  private streetLamp(group: THREE.Group, height: number) {
    this.cylinder(group, 0.16, 0.16, 0.12, 0, 0.06, 0);
    this.cylinder(group, 0.065, 0.036, height - 0.57, 0, (height - 0.33) / 2, 0);
    let previous = new THREE.Vector3(0, height - 0.45, 0);
    for (let i = 1; i <= 6; i++) {
      const angle = Math.PI / 2 * i / 6;
      const next = new THREE.Vector3((1 - Math.cos(angle)) * 0.45, height - 0.45 + Math.sin(angle) * 0.45, 0);
      this.strut(group, previous, next, 0.035);
      previous = next;
    }
    this.strut(group, previous, previous.clone().add(new THREE.Vector3(0.4, 0, 0)), 0.032);
    const head = previous.clone().add(new THREE.Vector3(0.55, -0.04, 0));
    this.box(group, this.rim, head.x, head.y, 0, 0.65, 0.12, 0.25);
    this.box(group, this.lens, head.x, head.y - 0.063, 0, 0.48, 0.012, 0.18);
    return head;
  }

  private ringLamp(group: THREE.Group) {
    this.cylinder(group, 0.14, 0.14, 0.025, 0, 0.0125, 0);
    this.cylinder(group, 0.087, 0.08, 0.5, 0, 0.275, 0);
    this.cylinder(group, 0.062, 0.044, 2.9, 0, 1.83, 0);
    const shape = new THREE.Shape();
    shape.absarc(0, 0, 0.46, 0, Math.PI * 2, false);
    const hole = new THREE.Path();
    hole.absarc(0, 0, 0.34, 0, Math.PI * 2, true);
    shape.holes.push(hole);
    const ring = new THREE.ExtrudeGeometry(shape, { depth: 0.06, bevelEnabled: false, curveSegments: 8 });
    ring.rotateX(-Math.PI / 2);
    this.mesh(group, ring, this.rim, 0, 3.54, 0);
    const lens = new THREE.RingGeometry(0.355, 0.447, 16);
    lens.rotateX(Math.PI / 2);
    this.mesh(group, lens, this.lens, 0, 3.535, 0);
    for (let i = 0; i < 3; i++) {
      const angle = i * Math.PI * 2 / 3;
      this.strut(group, new THREE.Vector3(Math.cos(angle) * 0.045, 3.14, Math.sin(angle) * 0.045), new THREE.Vector3(Math.cos(angle) * 0.403, 3.55, Math.sin(angle) * 0.403), 0.018);
    }
    return new THREE.Vector3(0, 3.56, 0);
  }

  private noticeboard(group: THREE.Group, board: Noticeboard) {
    for (const x of [-board.width / 2, 0, board.width / 2]) this.box(group, this.wood, x, board.height / 2, 0, 0.13, board.height, 0.14);
    this.box(group, this.wood, 0, 0.43, 0, board.width, 0.1, 0.12);
    this.box(group, this.wood, 0, board.height - 0.2, 0, board.width, 0.09, 0.12);
    this.box(group, this.trim, 0, board.height, 0, board.topBarWidth, 0.055, 0.2);
    const width = board.width / 2 - 0.2, y = board.panelBottom + board.panelHeight / 2;
    for (const side of [-1, 1]) {
      const x = side * board.width / 4;
      this.box(group, this.panel, x, y, 0, width, board.panelHeight, 0.08);
      for (const edge of [-1, 1]) {
        this.box(group, this.trim, x + edge * width / 2, y, 0, 0.055, board.panelHeight + 0.055, 0.11);
        this.box(group, this.trim, x, y + edge * board.panelHeight / 2, 0, width, 0.055, 0.11);
      }
    }
  }

  private makeGlow() {
    const canvas = document.createElement("canvas");
    canvas.width = canvas.height = 32;
    const context = canvas.getContext("2d")!;
    for (let y = 0; y < 32; y++) {
      for (let x = 0; x < 32; x++) {
        const radius = Math.hypot((x - 15.5) / 16, (y - 15.5) / 16);
        const alpha = radius >= 1 ? 0 : Math.round(Math.exp(-radius * radius * 5) * 12) / 16;
        context.fillStyle = `rgba(255,224,175,${alpha})`;
        context.fillRect(x, y, 1, 1);
      }
    }
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.magFilter = texture.minFilter = THREE.NearestFilter;
    texture.generateMipmaps = false;
    return texture;
  }

  update(time: number, center: THREE.Vector3, solarAltitude: number) {
    const tick = Math.floor(time / 200);
    if (tick === this.lightingTick) return;
    this.lightingTick = tick;
    const night = 1 - THREE.MathUtils.smoothstep(solarAltitude, -0.08, 0.12);
    this.lens.emissiveIntensity = night * 4;
    this.glow.opacity = night * 0.55;
    const nearest = this.lamps.map(lamp => ({ ...lamp, distance: Math.hypot(lamp.position.x - center.x, lamp.position.z - center.z) })).sort((a, b) => a.distance - b.distance);
    this.lights.forEach((light, index) => {
      const lamp = nearest[index];
      light.position.copy(lamp.position);
      light.target.position.copy(lamp.target);
      light.intensity = night * lamp.intensity * THREE.MathUtils.clamp((50 - lamp.distance) / 15, 0, 1);
    });
  }

  blocks(x: number, z: number, radius: number) {
    if (this.poles.some(pole => Math.hypot(pole.x - x, pole.y - z) < radius + 0.14)) return true;
    return this.boards.some(board => {
      const dx = x - board.center.x, dz = z - board.center.y;
      return Math.abs(dx * board.axis.x + dz * board.axis.y) < board.halfWidth + radius && Math.abs(-dx * board.axis.y + dz * board.axis.x) < 0.1 + radius;
    });
  }

  destroy() {
    this.geometries.forEach(geometry => geometry.dispose());
    this.materials.forEach(material => material.dispose());
    this.glowTexture.dispose();
    this.root.clear();
  }
}
