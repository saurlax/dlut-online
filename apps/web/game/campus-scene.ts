import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { ShaderPass } from "three/addons/postprocessing/ShaderPass.js";
import { UnrealBloomPass } from "three/addons/postprocessing/UnrealBloomPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";
import { drawCharacter, type CharacterState, type Item } from "./character";
import { watchPixelGrid } from "./pixel-grid";
import { SiteFixtures, type SiteFixtureData } from "./site-fixtures";

const WORLD_PIXELS_PER_METER = 12;

interface ModelManifest {
  buildings: { id: string; file: string; origin: [number, number, number] }[];
}

interface PlantInstance { x: number; z: number; phase: number; opacity: number; hidden: boolean }

export interface EnvironmentAnimations {
  water: {
    image: string;
    frameWidth: number;
    frameHeight: number;
    frameDurationMs: number;
    framesByTile: Record<string, number[]>;
  };
  trees: { frameDurationMs: number; offsets: number[]; fixedRootPixels: number };
}

export interface CampusMap {
  tileSize: number;
  offset: [number, number];
  chunkSize: number;
  width: number;
  height: number;
  textures: string[];
  focus: [number, number];
  materials: string[];
  materialRuns: number[];
  chunks: { x: number; y: number; layers: number[][]; overview: number[] }[];
  buildings: {
    id: string;
    name: string;
    image: string;
    x: number;
    y: number;
    width: number;
    height: number;
    footprint: [number, number][];
    depth: number;
    heightMeters: number;
    style: string;
  }[];
  plantPrototypes: Record<
    string,
    { width: number; height: number; runs: number[] }
  >;
  plants: {
    id: number;
    prototype: string;
    x: number;
    y: number;
    depth: number;
  }[];
}

export class CampusScene {
  private readonly world = new THREE.Scene();
  private readonly labels = new THREE.Scene();
  private readonly renderer = new THREE.WebGLRenderer({ antialias: false, powerPreference: "high-performance" });
  private readonly camera = new THREE.OrthographicCamera(-20, 20, 15, -15, 0.1, 400);
  private readonly sun = new THREE.DirectionalLight(0xffd6a0, 2.4);
  private readonly sky = new THREE.HemisphereLight(0xc2d7ee, 0x5e6b38, 1.6);
  private readonly composer: EffectComposer;
  private readonly bloom: UnrealBloomPass;
  private readonly focusPass: ShaderPass;
  private readonly textures = new Set<THREE.Texture>();
  private readonly geometries = new Set<THREE.BufferGeometry>();
  private readonly materials = new Set<THREE.Material>();
  private readonly terrain = new Map<string, THREE.Mesh<THREE.PlaneGeometry, THREE.MeshStandardMaterial>>();
  private readonly plantGroups: { mesh: THREE.InstancedMesh; instances: PlantInstance[]; visible: PlantInstance[]; pixels: Uint8ClampedArray; width: number; height: number }[] = [];
  private readonly buildings: THREE.Group[] = [];
  private readonly fixtures: SiteFixtures;
  private readonly characterCanvas = document.createElement("canvas");
  private characterPixels: THREE.Vector3[] = [];
  private readonly characterTexture = this.texture(this.characterCanvas);
  private readonly character = new THREE.Mesh(
    this.geometry(new THREE.PlaneGeometry(1, 2)),
    this.material(new THREE.MeshStandardMaterial({ map: this.characterTexture, alphaTest: 0.5, side: THREE.DoubleSide, roughness: 1 })),
  );
  private readonly name = new THREE.Sprite(this.material(new THREE.SpriteMaterial({ depthTest: false, toneMapped: false })));
  private readonly cameraTarget = new THREE.Vector3();
  private readonly raycaster = new THREE.Raycaster();
  private readonly screenPoint = new THREE.Vector3();
  private readonly keys = new Set<string>();
  private touchMovement = { x: 0, y: 0 };
  private actor?: { x: number; y: number };
  private characterState?: CharacterState;
  private itemCatalog: Item[] = [];
  private direction = 0;
  private pose = "";
  private atlas!: ImageBitmap;
  private waterTexture!: THREE.CanvasTexture;
  private readonly waterPhase = { value: 0 };
  private frame = 0;
  private lastTime = 0;
  private sampleStart = 0;
  private sampleFrames = 0;
  private sampleMaxMs = 0;
  private frameSample = { fps: 0, frameMs: 0, maxFrameMs: 0 };
  private serverOffset = 0;
  private weatherCode: number | null = null;
  private lightingTick = -1;
  private solarAngle = 0;
  private viewKey = "";
  private shadowTick = -1;
  private occlusionTick = -1;
  private stopResize?: () => void;
  private disposed = false;

  constructor(private readonly campus: CampusMap, private readonly environment: EnvironmentAnimations, fixtureData: SiteFixtureData) {
    this.renderer.setPixelRatio(1);
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.autoUpdate = false;
    this.renderer.shadowMap.type = THREE.PCFShadowMap;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.1;
    this.world.background = new THREE.Color(0x9eaf99);
    this.world.fog = new THREE.Fog(0xc2bcab, 110, 260);
    this.world.add(this.sky, this.sun, this.sun.target);
    this.fixtures = new SiteFixtures(fixtureData, campus.offset);
    this.world.add(this.fixtures.root);
    this.sun.castShadow = true;
    this.sun.shadow.mapSize.set(2048, 2048);
    Object.assign(this.sun.shadow.camera, { left: -85, right: 85, top: 85, bottom: -85, near: 1, far: 300 });
    this.sun.shadow.normalBias = 0.035;
    this.sun.shadow.bias = -0.00015;
    this.sun.shadow.radius = 4;
    this.sun.shadow.intensity = 0.72;
    this.sky.groundColor.set(0x9d8864);
    this.character.castShadow = true;
    this.character.receiveShadow = true;
    this.character.visible = false;
    this.name.visible = false;
    this.name.renderOrder = 100;
    this.world.add(this.character);
    this.labels.add(this.name);
    const target = new THREE.WebGLRenderTarget(1, 1, { type: THREE.HalfFloatType, depthTexture: new THREE.DepthTexture(1, 1) });
    this.composer = new EffectComposer(this.renderer, target);
    this.composer.addPass(new RenderPass(this.world, this.camera));
    // Reuse the main render's depth buffer; a second scene render is unnecessary.
    this.focusPass = new ShaderPass({
      uniforms: { tDiffuse: { value: null }, tDepth: { value: null }, texel: { value: new THREE.Vector2(1, 1) }, focus: { value: Math.hypot(90, 75) }, daylight: { value: 1 }, warmth: { value: 0.5 } },
      vertexShader: `varying vec2 vUv;
        void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
      fragmentShader: `uniform sampler2D tDiffuse, tDepth;
        uniform vec2 texel;
        uniform float focus, daylight, warmth;
        varying vec2 vUv;
        void main() {
          float distance = mix(0.1, 400.0, texture2D(tDepth, vUv).x);
          float blur = clamp((abs(distance - focus) - 6.0) / 18.0, 0.0, 1.0) * 3.5;
          vec2 d = texel * blur;
          vec3 color = texture2D(tDiffuse, vUv).rgb * 0.28;
          color += texture2D(tDiffuse, vUv + vec2(d.x, 0.0)).rgb * 0.12;
          color += texture2D(tDiffuse, vUv - vec2(d.x, 0.0)).rgb * 0.12;
          color += texture2D(tDiffuse, vUv + vec2(0.0, d.y)).rgb * 0.12;
          color += texture2D(tDiffuse, vUv - vec2(0.0, d.y)).rgb * 0.12;
          color += texture2D(tDiffuse, vUv + d).rgb * 0.06;
          color += texture2D(tDiffuse, vUv - d).rgb * 0.06;
          color += texture2D(tDiffuse, vUv + vec2(d.x, -d.y)).rgb * 0.06;
          color += texture2D(tDiffuse, vUv + vec2(-d.x, d.y)).rgb * 0.06;
          float luminance = dot(color, vec3(0.2126, 0.7152, 0.0722));
          float highlight = smoothstep(0.25, 1.15, luminance);
          vec3 shadeTint = vec3(0.91, 0.96, 1.07);
          vec3 sunTint = mix(vec3(1.04, 1.01, 0.96), vec3(1.15, 1.03, 0.89), warmth);
          color *= mix(vec3(1.0), mix(shadeTint, sunTint, highlight), daylight * 0.75);
          color = mix(vec3(luminance), color, 1.07);
          float vignette = smoothstep(0.22, 0.78, length((vUv - 0.5) * vec2(1.0, 0.85)));
          gl_FragColor = vec4(color * (1.0 - vignette * 0.22), 1.0);
        }`,
    });
    this.composer.addPass(this.focusPass);
    this.bloom = new UnrealBloomPass(new THREE.Vector2(1, 1), 0.38, 0.65, 0.55);
    this.composer.addPass(this.bloom);
    this.composer.addPass(new OutputPass());
  }

  private texture(canvas: HTMLCanvasElement) {
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.magFilter = texture.minFilter = THREE.NearestFilter;
    texture.generateMipmaps = false;
    this.textures.add(texture);
    return texture;
  }

  private geometry<T extends THREE.BufferGeometry>(geometry: T): T { this.geometries.add(geometry); return geometry; }
  private material<T extends THREE.Material>(material: T): T { this.materials.add(material); return material; }

  async start(host: HTMLElement, signal: AbortSignal, progress: (value: number) => void) {
    host.append(this.renderer.domElement);
    const image = async (path: string) => {
      const response = await fetch(`/campuses/eda/${path}`, { signal });
      if (!response.ok) throw new Error(`Image request failed: ${path}`);
      return createImageBitmap(await response.blob());
    };
    const response = await fetch("/campuses/eda/models/manifest.json", { signal });
    if (!response.ok) throw new Error("Model manifest request failed");
    const manifest: ModelManifest = await response.json();
    const images = await Promise.all([image("tile-atlas.png"), image(this.environment.water.image)]);
    if (signal.aborted) { images.forEach(image => image.close()); return; }
    [this.atlas] = images;
    const waterCanvas = document.createElement("canvas");
    waterCanvas.width = images[1].width;
    waterCanvas.height = images[1].height;
    waterCanvas.getContext("2d")!.drawImage(images[1], 0, 0);
    images[1].close();
    this.waterTexture = this.texture(waterCanvas);
    progress(0.15);
    const loader = new GLTFLoader();
    let completed = 0;
    // Process two models at a time so decoding does not retain the whole archive.
    const pending = [...manifest.buildings];
    const worker = async () => {
      while (pending.length) {
        const asset = pending.shift()!;
        const response = await fetch(`/campuses/eda/${asset.file}`, { signal });
        if (!response.ok) throw new Error(`Model request failed: ${asset.id}`);
        const gltf = await loader.parseAsync(await response.arrayBuffer(), "/campuses/eda/models/");
        const group = gltf.scene;
        group.traverse(object => {
          if (!(object instanceof THREE.Mesh)) return;
          this.geometry(object.geometry);
          object.castShadow = object.receiveShadow = true;
          for (const material of Array.isArray(object.material) ? object.material : [object.material]) {
            const surface = material as THREE.MeshStandardMaterial;
            surface.map!.magFilter = surface.map!.minFilter = THREE.NearestFilter;
            surface.map!.generateMipmaps = false;
            this.textures.add(surface.map!);
            surface.roughness = 0.9;
            surface.metalness = 0;
            surface.transparent = false;
            surface.opacity = 1;
            surface.side = THREE.DoubleSide;
            this.material(surface);
          }
        });
        if (signal.aborted) { this.disposeResources(); return; }
        // The archived models use building-local origins in the same WGS84 frame.
        // Ground remains the current flat map; do not apply archived terrain Y.
        group.position.set(asset.origin[0] - this.campus.offset[0], 0, asset.origin[2] - this.campus.offset[1]);
        group.userData.id = asset.id;
        this.buildings.push(group);
        this.world.add(group);
        progress(0.15 + ++completed / manifest.buildings.length * 0.75);
      }
    };
    await Promise.all([worker(), worker()]);
    if (signal.aborted) return;
    for (const building of this.campus.buildings.filter(building => building.style === "unverified")) {
      const shape = new THREE.Shape(building.footprint.map(([x, z]) => new THREE.Vector2(x, -z)));
      const mesh = new THREE.Mesh(this.geometry(new THREE.ShapeGeometry(shape)), this.material(new THREE.MeshStandardMaterial({ color: 0xb1b39d, roughness: 1 })));
      mesh.rotation.x = -Math.PI / 2;
      mesh.position.y = 0.015;
      mesh.receiveShadow = true;
      this.world.add(mesh);
    }
    this.createPlants();
    this.stopResize = watchPixelGrid(grid => {
      this.renderer.setSize(grid.width + 1, grid.height + 1, false);
      this.renderer.domElement.style.width = `${grid.width + 1}px`;
      this.renderer.domElement.style.height = `${grid.height + 1}px`;
      this.renderer.domElement.style.transform = `scale(${grid.pixel})`;
      this.composer.setSize(grid.width + 1, grid.height + 1);
      this.focusPass.uniforms.texel.value.set(1 / (grid.width + 1), 1 / (grid.height + 1));
      this.camera.left = -grid.width / (2 * WORLD_PIXELS_PER_METER);
      this.camera.right = grid.width / (2 * WORLD_PIXELS_PER_METER);
      this.camera.top = grid.height / (2 * WORLD_PIXELS_PER_METER);
      this.camera.bottom = -grid.height / (2 * WORLD_PIXELS_PER_METER);
      this.camera.updateProjectionMatrix();
      this.viewKey = "";
      this.updateCamera(true);
    });
    window.addEventListener("keydown", this.keydown);
    window.addEventListener("keyup", this.keyup);
    window.addEventListener("blur", this.clearInput);
    window.addEventListener("focusin", this.focusInput);
    this.updateCamera(true);
    progress(1);
    this.frame = requestAnimationFrame(this.update);
  }

  setTouchMovement(x: number, y: number) { this.touchMovement = { x, y }; }

  performanceSnapshot() { return this.frameSample; }

  setEnvironment(serverTime: number, code: number | null) {
    this.serverOffset = serverTime - Date.now();
    this.weatherCode = code;
    this.lightingTick = -1;
  }

  private readonly keydown = (event: KeyboardEvent) => {
    if ((event.target as HTMLElement).closest('input,textarea,select,[contenteditable="true"]') || event.ctrlKey || event.metaKey || event.altKey) return;
    if (event.key.startsWith("Arrow")) event.preventDefault();
    this.keys.add(event.key.toLowerCase());
  };
  private readonly keyup = (event: KeyboardEvent) => { this.keys.delete(event.key.toLowerCase()); };
  private readonly clearInput = () => { this.keys.clear(); this.setTouchMovement(0, 0); };
  private readonly focusInput = (event: FocusEvent) => {
    if ((event.target as HTMLElement).closest('input,textarea,select,[contenteditable="true"]')) this.clearInput();
  };

  setCharacter(state: CharacterState, items: Item[]) {
    this.characterState = state;
    this.itemCatalog = items;
    this.pose = "";
    this.character.visible = this.name.visible = Boolean(state.profile);
    if (!state.profile) { this.actor = undefined; return; }
    if (!this.actor) {
      let x = this.campus.focus[0] * 16, y = this.campus.focus[1] * 16;
      if (!this.canStand(x, y)) {
        find: for (let r = 0; r < 20; r++) {
          for (let dy = -r; dy <= r; dy++) {
            for (let dx = -r; dx <= r; dx++) {
              const px = (this.campus.focus[0] + dx) * 16 + 8, py = (this.campus.focus[1] + dy) * 16 + 8;
              if (this.canStand(px, py)) { x = px; y = py; break find; }
            }
          }
        }
      }
      this.actor = { x, y };
      this.updateCamera(true);
    }
    this.animateCharacter(0);
    const canvas = document.createElement("canvas"), context = canvas.getContext("2d")!;
    context.font = '12px "Fusion Pixel"';
    canvas.width = 2 * Math.ceil((context.measureText(state.profile.name).width + 2) / 2);
    canvas.height = 14;
    context.font = '12px "Fusion Pixel"';
    context.fillStyle = "#fff3d0";
    context.fillText(state.profile.name, 0, 10);
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height);
    for (let i = 3; i < pixels.data.length; i += 4) pixels.data[i] = pixels.data[i] >= 128 ? 255 : 0;
    context.putImageData(pixels, 0, 0);
    const previous = this.name.material.map;
    if (previous) { previous.dispose(); this.textures.delete(previous); }
    this.name.material.map = this.texture(canvas);
    this.name.material.needsUpdate = true;
    this.name.scale.set(canvas.width / WORLD_PIXELS_PER_METER, canvas.height / WORLD_PIXELS_PER_METER, 1);
  }

  private animateCharacter(step: number) {
    const state = this.characterState!;
    drawCharacter(this.characterCanvas, state.profile!.appearance,
      state.inventory.filter(item => !item.slotId.startsWith("hotbar:") && !item.slotId.startsWith("bag:"))
        .map(item => ({ key: this.itemCatalog.find(entry => entry.id === item.itemId)!.key, color: item.color })),
      this.direction, step, state.profile!.gender);
    this.characterTexture.needsUpdate = true;
    const pixels = this.characterCanvas.getContext("2d")!.getImageData(0, 0, 16, 32).data;
    this.characterPixels = [];
    for (let y = 0; y < 32; y++) {
      for (let x = 0; x < 16; x++) {
        if (pixels[(y * 16 + x) * 4 + 3] >= 128) this.characterPixels.push(new THREE.Vector3((x + 0.5) / 16 - 0.5, 1 - (y + 0.5) / 16, 0));
      }
    }
  }

  private drawTile(context: CanvasRenderingContext2D, index: number, x: number, y: number) {
    const columns = this.atlas.width / 16;
    context.drawImage(this.atlas, index % columns * 16, Math.floor(index / columns) * 16, 16, 16, x * 16, y * 16, 16, 16);
  }

  private createPlants() {
    for (const [key, prototype] of Object.entries(this.campus.plantPrototypes)) {
      const canvas = document.createElement("canvas");
      canvas.width = prototype.width * 16;
      canvas.height = prototype.height * 16;
      const context = canvas.getContext("2d")!;
      let offset = 0;
      for (let i = 0; i < prototype.runs.length; i += 2) {
        for (let j = 0; j < prototype.runs[i]; j++, offset++) {
          if (prototype.runs[i + 1] >= 0) this.drawTile(context, prototype.runs[i + 1], offset % prototype.width, Math.floor(offset / prototype.width));
        }
      }
      const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
      const material = this.material(new THREE.MeshStandardMaterial({ map: this.texture(canvas), alphaTest: 0.5, side: THREE.DoubleSide, roughness: 1, transparent: true, forceSinglePass: true }));
      material.onBeforeCompile = shader => {
        shader.vertexShader = "attribute float plantOpacity; varying float vPlantOpacity;\n" + shader.vertexShader;
        shader.vertexShader = shader.vertexShader.replace("#include <begin_vertex>", "#include <begin_vertex>\nvPlantOpacity = plantOpacity;");
        shader.fragmentShader = "varying float vPlantOpacity;\n" + shader.fragmentShader;
        // Apply instance fading after the original cutout alpha test.
        shader.fragmentShader = shader.fragmentShader.replace("#include <opaque_fragment>", "diffuseColor.a *= vPlantOpacity;\n#include <opaque_fragment>");
      };
      const geometry = this.geometry(new THREE.PlaneGeometry(prototype.width, prototype.height));
      geometry.translate(0, prototype.height / 2, 0);
      // Rounded foliage lighting on the cutout, with brighter upper leaves.
      const normals = geometry.getAttribute("normal");
      [[-0.4, 0.85, 0.5], [0.4, 0.85, 0.5], [-0.3, 0.35, 0.85], [0.3, 0.35, 0.85]]
        .forEach(([x, y, z], index) => normals.setXYZ(index, x, y, z));
      geometry.normalizeNormals();
      const instances = this.campus.plants.filter(plant => plant.prototype === key)
        .map(plant => ({ x: plant.x + prototype.width / 2, z: plant.depth, phase: plant.id, opacity: 1, hidden: false }));
      geometry.setAttribute("plantOpacity", new THREE.InstancedBufferAttribute(new Float32Array(instances.length).fill(1), 1).setUsage(THREE.DynamicDrawUsage));
      const mesh = new THREE.InstancedMesh(geometry, material, instances.length);
      mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
      mesh.count = 0;
      mesh.castShadow = mesh.receiveShadow = true;
      this.plantGroups.push({ mesh, instances, visible: [], pixels, width: canvas.width, height: canvas.height });
      this.world.add(mesh);
    }
  }

  private updatePlantOcclusion() {
    this.character.updateWorldMatrix(true, false);
    const points = this.characterPixels.map(point => point.clone().applyMatrix4(this.character.matrixWorld));
    const towardCamera = this.camera.getWorldDirection(new THREE.Vector3()).negate();
    const matrix = new THREE.Matrix4(), inverse = new THREE.Matrix4(), point = new THREE.Vector3();
    const x = this.actor!.x / 16, z = this.actor!.y / 16;
    for (const group of this.plantGroups) {
      group.visible.forEach((plant, index) => {
        plant.hidden = false;
        const width = group.width / 16, height = group.height / 16;
        if (Math.abs(plant.x - x) > width / 2 + 0.7 || plant.z < z - 1 || plant.z > z + height * 75 / 90 + 2) return;
        group.mesh.getMatrixAt(index, matrix);
        inverse.copy(matrix).invert();
        plant.hidden = points.some(source => {
          const distance = (plant.z - source.z) / towardCamera.z;
          if (distance <= 0) return false;
          point.copy(source).addScaledVector(towardCamera, distance).applyMatrix4(inverse);
          const u = point.x / width + 0.5, v = 1 - point.y / height;
          if (u < 0 || u >= 1 || v < 0 || v >= 1) return false;
          return group.pixels[(Math.floor(v * group.height) * group.width + Math.floor(u * group.width)) * 4 + 3] >= 128;
        });
      });
    }
  }

  private createTerrain(chunk: CampusMap["chunks"][number]) {
    const size = this.campus.chunkSize;
    const canvas = document.createElement("canvas");
    canvas.width = canvas.height = size * 16;
    const context = canvas.getContext("2d")!;
    const waterCells: { x: number; y: number; row: number }[] = [];
    for (const runs of chunk.layers) {
      let offset = 0;
      for (let i = 0; i < runs.length; i += 2) {
        const tile = runs[i + 1];
        for (let j = 0; j < runs[i]; j++, offset++) {
          if (tile >= 0) {
            const x = offset % size, y = Math.floor(offset / size);
            this.drawTile(context, tile, x, y);
            const frames = this.environment.water.framesByTile[this.campus.textures[tile]];
            if (frames) waterCells.push({ x, y, row: frames[0] / 16 });
          }
        }
      }
    }
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
    // The atlas has one 16-frame row per water tile. Store that row in the
    // opaque ground texture's unused alpha channel, only on water-colored pixels.
    // Shore and path overlays keep alpha 255 and remain completely static.
    for (const cell of waterCells) {
      for (let y = 0; y < 16; y++) {
        for (let x = 0; x < 16; x++) {
          const i = ((cell.y * 16 + y) * canvas.width + cell.x * 16 + x) * 4;
          const r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
          if ((r === 68 && g === 143 && b === 153) || (r === 102 && g === 173 && b === 176) || (r === 60 && g === 130 && b === 142)) pixels[i + 3] = cell.row;
        }
      }
    }
    const data = new Uint8Array(pixels.length), stride = canvas.width * 4;
    for (let y = 0; y < canvas.height; y++) data.set(pixels.subarray(y * stride, (y + 1) * stride), (canvas.height - y - 1) * stride);
    const texture = new THREE.DataTexture(data, canvas.width, canvas.height);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.needsUpdate = true;
    this.textures.add(texture);
    const material = this.material(new THREE.MeshStandardMaterial({ map: texture, roughness: 1 }));
    if (waterCells.length) {
      material.onBeforeCompile = shader => {
        shader.uniforms.waterAtlas = { value: this.waterTexture };
        shader.uniforms.waterPhase = this.waterPhase;
        shader.uniforms.waterGrid = { value: new THREE.Vector2(this.waterTexture.image.width / 16, this.waterTexture.image.height / 16) };
        shader.uniforms.chunkSize = { value: size };
        shader.fragmentShader = `uniform sampler2D waterAtlas;
          uniform float waterPhase, chunkSize;
          uniform vec2 waterGrid;\n` + shader.fragmentShader;
        shader.fragmentShader = shader.fragmentShader.replace("#include <map_fragment>", `
          vec4 sampledDiffuseColor = texture2D(map, vMapUv);
          if (sampledDiffuseColor.a < 0.999) {
            float row = floor(sampledDiffuseColor.a * 255.0 + 0.5);
            vec2 tileUv = fract(vec2(vMapUv.x, 1.0 - vMapUv.y) * chunkSize);
            vec2 waterUv = vec2((mod(waterPhase, waterGrid.x) + tileUv.x) / waterGrid.x, 1.0 - (row + tileUv.y) / waterGrid.y);
            sampledDiffuseColor = texture2D(waterAtlas, waterUv);
          }
          diffuseColor *= sampledDiffuseColor;
        `);
      };
    }
    const mesh = new THREE.Mesh(this.geometry(new THREE.PlaneGeometry(size, size)), material);
    mesh.rotation.x = -Math.PI / 2;
    mesh.position.set(chunk.x + size / 2, 0, chunk.y + size / 2);
    mesh.receiveShadow = true;
    this.terrain.set(`${chunk.x}:${chunk.y}`, mesh);
    this.world.add(mesh);
  }

  private updateCamera(center: boolean) {
    const x = this.actor ? this.actor.x / 16 : this.campus.focus[0];
    const z = this.actor ? this.actor.y / 16 : this.campus.focus[1];
    const halfX = this.camera.right / 2;
    const halfZ = this.camera.top / 2 / Math.sin(Math.atan2(90, 75));
    if (center) this.cameraTarget.set(x, 0, z);
    else {
      this.cameraTarget.x = THREE.MathUtils.clamp(this.cameraTarget.x, x - halfX, x + halfX);
      this.cameraTarget.z = THREE.MathUtils.clamp(this.cameraTarget.z, z - halfZ, z + halfZ);
    }
    this.cameraTarget.x = THREE.MathUtils.clamp(this.cameraTarget.x, 0, this.campus.width);
    this.cameraTarget.z = THREE.MathUtils.clamp(this.cameraTarget.z, 0, this.campus.height);
    this.camera.position.copy(this.cameraTarget).add(new THREE.Vector3(0, 90, 75));
    this.camera.lookAt(this.cameraTarget);
    this.camera.updateMatrixWorld();
    this.character.quaternion.copy(this.camera.quaternion);
    const radiusX = this.camera.right + 40, radiusZ = this.camera.top * 1.4 + 70;
    const minX = Math.max(0, Math.floor((this.cameraTarget.x - radiusX) / this.campus.chunkSize) * this.campus.chunkSize);
    const maxX = Math.min(this.campus.width, Math.ceil((this.cameraTarget.x + radiusX) / this.campus.chunkSize) * this.campus.chunkSize);
    const minZ = Math.max(0, Math.floor((this.cameraTarget.z - radiusZ) / this.campus.chunkSize) * this.campus.chunkSize);
    const maxZ = Math.min(this.campus.height, Math.ceil((this.cameraTarget.z + radiusZ) / this.campus.chunkSize) * this.campus.chunkSize);
    const key = `${minX}:${maxX}:${minZ}:${maxZ}`;
    if (key === this.viewKey) return;
    this.viewKey = key;
    for (const [key, mesh] of this.terrain) {
      const [x, z] = key.split(":").map(Number);
      if (x >= minX && x < maxX && z >= minZ && z < maxZ) continue;
      const texture = mesh.material.map!;
      texture.dispose(); this.textures.delete(texture);
      mesh.geometry.dispose(); this.geometries.delete(mesh.geometry);
      mesh.material.dispose(); this.materials.delete(mesh.material);
      this.world.remove(mesh); this.terrain.delete(key);
    }
    for (const chunk of this.campus.chunks) {
      if (chunk.x >= minX && chunk.x < maxX && chunk.y >= minZ && chunk.y < maxZ && !this.terrain.has(`${chunk.x}:${chunk.y}`)) this.createTerrain(chunk);
    }
    for (const group of this.plantGroups) {
      group.visible = group.instances.filter(plant => plant.x >= minX && plant.x < maxX && plant.z >= minZ && plant.z < maxZ);
    }
    this.shadowTick = -1;
  }

  private updateLighting() {
    const tick = Math.floor((Date.now() + this.serverOffset) / 10000);
    if (tick === this.lightingTick) return;
    this.lightingTick = tick;
    const date = new Date(Date.now() + this.serverOffset + 8 * 3600000);
    const hour = date.getUTCHours() + date.getUTCMinutes() / 60;
    this.solarAngle = (hour - 6) * Math.PI / 12;
    const altitude = Math.sin(this.solarAngle);
    const daylight = THREE.MathUtils.smoothstep(altitude, -0.12, 0.42);
    const sunlight = THREE.MathUtils.smoothstep(altitude, -0.04, 0.2);
    const warmth = 1 - THREE.MathUtils.clamp(altitude, 0, 1);
    const cloudy = this.weatherCode !== null && this.weatherCode >= 3;
    this.sun.intensity = (0.12 + sunlight * 3.2) * (cloudy ? 0.65 : 1);
    this.sun.color.set(0xffe3ba).lerp(new THREE.Color(0xffb16d), warmth);
    this.sky.intensity = 0.8 + daylight * 1.05;
    this.sky.color.set(daylight > 0 ? 0xb4c9eb : 0x7287c4);
    (this.world.fog as THREE.Fog).color.set(daylight > 0 ? 0xc2bcab : 0x555f89);
    this.renderer.toneMappingExposure = 0.85 + daylight * 0.3;
    this.focusPass.uniforms.daylight.value = daylight;
    this.focusPass.uniforms.warmth.value = warmth;
    this.bloom.strength = 0.22 + daylight * 0.16;
  }

  private readonly update = (time: number) => {
    if (this.disposed) return;
    const frameMs = time - (this.lastTime || time);
    if (!this.sampleStart) this.sampleStart = time;
    else {
      this.sampleFrames++;
      this.sampleMaxMs = Math.max(this.sampleMaxMs, frameMs);
      const elapsed = time - this.sampleStart;
      if (elapsed >= 500) {
        this.frameSample = { fps: Math.round(this.sampleFrames * 1000 / elapsed), frameMs: Math.round(elapsed / this.sampleFrames * 10) / 10, maxFrameMs: Math.round(this.sampleMaxMs * 10) / 10 };
        this.sampleStart = time;
        this.sampleFrames = 0;
        this.sampleMaxMs = 0;
      }
    }
    const delta = Math.min(frameMs, 50);
    this.lastTime = time;
    if (document.querySelector('[role="dialog"]') || document.activeElement?.closest('input,textarea,select,[contenteditable="true"]') || !document.hasFocus()) this.clearInput();
    const dx = this.touchMovement.x || Number(this.keys.has("d") || this.keys.has("arrowright")) - Number(this.keys.has("a") || this.keys.has("arrowleft"));
    const dy = this.touchMovement.y || Number(this.keys.has("s") || this.keys.has("arrowdown")) - Number(this.keys.has("w") || this.keys.has("arrowup"));
    const sprinting = this.keys.has("shift");
    if (this.actor) {
      if (dx || dy) {
        this.direction = Math.abs(dx) > Math.abs(dy) ? dx > 0 ? 1 : 3 : dy > 0 ? 0 : 2;
        const distance = (sprinting ? 64 : 32) * delta / 1000 / Math.max(1, Math.hypot(dx, dy));
        const x = this.actor.x + dx * distance, y = this.actor.y + dy * distance;
        if (this.canStand(x, y)) { this.actor.x = x; this.actor.y = y; }
      }
      const step = dx || dy ? Math.floor(time / (sprinting ? 80 : 160)) % 3 : 0;
      const pose = `${this.direction}:${step}`;
      if (pose !== this.pose) { this.animateCharacter(step); this.pose = pose; }
      this.character.position.set(this.actor.x / 16, 0, this.actor.y / 16);
      // Put the bottom of the billboard at the geographic foot point.
      this.character.position.add(new THREE.Vector3(0, 1, 0).applyQuaternion(this.camera.quaternion));
      this.name.position.copy(this.character.position).add(new THREE.Vector3(0, 1.7, 0).applyQuaternion(this.camera.quaternion));
    }
    this.updateCamera(false);
    if (this.actor) this.focusPass.uniforms.focus.value = -this.screenPoint.copy(this.character.position).applyMatrix4(this.camera.matrixWorldInverse).z;
    this.updateLighting();
    this.fixtures.update(time, this.cameraTarget, Math.sin(this.solarAngle));
    const angle = this.solarAngle;
    const target = this.cameraTarget;
    this.sun.target.position.copy(target);
    this.sun.position.set(target.x - Math.cos(angle) * 90, Math.max(25, Math.sin(angle) * 100), target.z - 50);
    this.waterPhase.value = Math.floor(time / this.environment.water.frameDurationMs);
    if (this.actor && Math.floor(time / 150) !== this.occlusionTick) {
      this.occlusionTick = Math.floor(time / 150);
      this.updatePlantOcclusion();
      this.screenPoint.copy(this.character.position).project(this.camera);
      this.raycaster.setFromCamera(new THREE.Vector2(this.screenPoint.x, this.screenPoint.y), this.camera);
      const distance = this.camera.position.distanceTo(this.character.position);
      for (const building of this.buildings) {
        const hidden = this.raycaster.intersectObject(building, true).some(hit => hit.distance < distance - 0.5);
        building.traverse(object => {
          if (!(object instanceof THREE.Mesh)) return;
          for (const material of Array.isArray(object.material) ? object.material : [object.material]) {
            material.transparent = hidden;
            material.opacity = hidden ? 0.4 : 1;
            material.depthWrite = !hidden;
          }
        });
      }
    }
    for (const group of this.plantGroups) {
      const opacity = group.mesh.geometry.getAttribute("plantOpacity") as THREE.InstancedBufferAttribute;
      let changed = false;
      group.visible.forEach((plant, index) => {
        const target = plant.hidden ? 0.45 : 1;
        const step = 0.55 * delta / 180;
        plant.opacity += THREE.MathUtils.clamp(target - plant.opacity, -step, step);
        if (Math.abs(opacity.getX(index) - plant.opacity) > 0.00001) { opacity.setX(index, plant.opacity); changed = true; }
      });
      if (changed) opacity.needsUpdate = true;
    }
    const shadowTick = Math.floor(time / 150);
    if (shadowTick !== this.shadowTick) {
      this.shadowTick = shadowTick;
      const matrix = new THREE.Matrix4(), rotation = new THREE.Quaternion();
      const position = new THREE.Vector3(), scale = new THREE.Vector3(1, 1, 1), axis = new THREE.Vector3(0, 0, 1);
      for (const group of this.plantGroups) {
        group.mesh.count = group.visible.length;
        group.visible.forEach((plant, index) => {
          position.set(plant.x, 0, plant.z);
          rotation.setFromAxisAngle(axis, Math.sin(time / 1600 + plant.phase) * 0.008);
          group.mesh.setMatrixAt(index, matrix.compose(position, rotation, scale));
        });
        group.mesh.instanceMatrix.needsUpdate = true;
        group.mesh.computeBoundingSphere();
      }
      this.renderer.shadowMap.needsUpdate = true;
    }
    this.focusPass.uniforms.tDepth.value = this.composer.readBuffer.depthTexture;
    this.composer.render();
    this.renderer.autoClear = false;
    this.renderer.clearDepth();
    this.renderer.render(this.labels, this.camera);
    this.renderer.autoClear = true;
    this.frame = requestAnimationFrame(this.update);
  };

  private disposeResources() {
    this.textures.forEach(texture => {
      texture.dispose();
      if (texture.image instanceof ImageBitmap) texture.image.close();
    });
    this.geometries.forEach(geometry => geometry.dispose());
    this.materials.forEach(material => material.dispose());
  }

  destroy() {
    this.disposed = true;
    cancelAnimationFrame(this.frame);
    this.stopResize?.();
    window.removeEventListener("keydown", this.keydown);
    window.removeEventListener("keyup", this.keyup);
    window.removeEventListener("blur", this.clearInput);
    window.removeEventListener("focusin", this.focusInput);
    this.atlas?.close();
    this.disposeResources();
    this.fixtures.destroy();
    this.plantGroups.forEach(group => group.mesh.dispose());
    this.composer.passes.forEach(pass => pass.dispose());
    this.composer.dispose();
    this.sun.shadow.dispose();
    this.renderer.dispose();
    this.renderer.domElement.remove();
  }

  minimapTerrain() {
    const palette: Record<string, string> = {
      outside: '#778e5a', grass: '#93bb60', woodland: '#608044', water: '#448f99',
      asphalt: '#777b72', path: '#c4b48b', 'red-walk': '#c7785e', paving: '#b8b59b',
      bridge: '#b9bea8', track: '#b46c55', court: '#719c8f', field: '#8aaa5a',
    };
    const canvas = document.createElement('canvas');
    canvas.width = Math.ceil(this.campus.width / 2);
    canvas.height = Math.ceil(this.campus.height / 2);
    const context = canvas.getContext('2d')!;
    let offset = 0;
    for (let i = 0; i < this.campus.materialRuns.length; i += 2) {
      const count = this.campus.materialRuns[i];
      context.fillStyle = palette[this.campus.materials[this.campus.materialRuns[i + 1]]];
      for (let j = offset; j < offset + count; j++) {
        const x = j % this.campus.width, y = Math.floor(j / this.campus.width);
        if (x % 2 === 1 && y % 2 === 1) context.fillRect(Math.floor(x / 2), Math.floor(y / 2), 1, 1);
      }
      offset += count;
    }
    context.fillStyle = '#e2d5b4';
    for (const building of this.campus.buildings) {
      context.beginPath();
      building.footprint.forEach(([x,y], i) => i === 0 ? context.moveTo(x/2,y/2) : context.lineTo(x/2,y/2));
      context.closePath(); context.fill();
    }
    return canvas;
  }

  minimapPosition() {
    return this.actor
      ? { x: this.actor.x / 32, y: this.actor.y / 32, direction: this.direction, active: true }
      : { x: this.campus.focus[0] / 2, y: this.campus.focus[1] / 2, direction: 0, active: false };
  }

  mapSnapshot() {
    return {
      width: Math.ceil(this.campus.width / 10),
      height: Math.ceil(this.campus.height / 10),
      player: this.actor ? { x: Math.round(this.actor.x / 160), y: Math.round(this.actor.y / 160) } : null,
      landmarks: this.campus.buildings.filter(b=>!b.id.endsWith('-podium')).map(b=>{
        const xs=b.footprint.map(p=>p[0]),ys=b.footprint.map(p=>p[1]);
        const x=Math.floor(Math.min(...xs)/10),y=Math.floor(Math.min(...ys)/10);
        return {id:b.id,name:b.name,x,y,width:Math.max(1,Math.ceil(Math.max(...xs)/10)-x),height:Math.max(1,Math.ceil(Math.max(...ys)/10)-y)};
      }),
    };
  }

  travelToLandmark(id: string) {
    const building = this.campus.buildings.find(b => b.id === id)!;
    const xs = building.footprint.map(p => p[0]);
    const ys = building.footprint.map(p => p[1]);
    // Prefer open ground just south of the footprint; this is not an inferred entrance.
    const targetX = Math.floor((Math.min(...xs) + Math.max(...xs)) / 2);
    const targetY = Math.ceil(Math.max(...ys)) + 2;
    for (let radius = 0; radius <= 32; radius++) {
      for (let dy = -radius; dy <= radius; dy++) {
        for (let dx = -radius; dx <= radius; dx++) {
          if (Math.max(Math.abs(dx), Math.abs(dy)) !== radius) continue;
          const x = (targetX + dx) * 16 + 8;
          const y = (targetY + dy) * 16 + 8;
          if (!this.canStand(x, y)) continue;
          this.keys.clear();
          this.actor!.x = x;
          this.actor!.y = y;
          this.touchMovement = { x: 0, y: 0 };
          this.updateCamera(true);
          return true;
        }
      }
    }
    return false;
  }

  private canStand(x: number, y: number) {
    return this.walkable(x - 3, y) && this.walkable(x + 3, y) && !this.fixtures.blocks(x / 16, y / 16, 3 / 16);
  }

  private walkable(x: number, y: number) {
    const tx = Math.floor(x / 16),
      ty = Math.floor(y / 16),
      size = this.campus.chunkSize;
    const chunk = this.campus.chunks.find(
      (c) => tx >= c.x && ty >= c.y && tx < c.x + size && ty < c.y + size,
    );
    if (!chunk) return false;
    const target = (ty - chunk.y) * size + tx - chunk.x;
    let material = "outside";
    for (const runs of chunk.layers) {
      let count = 0;
      for (let i = 0; i < runs.length; i += 2) {
        count += runs[i];
        if (count > target) {
          if (runs[i + 1] >= 0) material = this.campus.textures[runs[i + 1]];
          break;
        }
      }
    }
    if (!/^(grass|woodland|field|path|asphalt|red-walk|track|court|paving|bridge)-/.test(material))
      return false;
    for (const b of this.campus.buildings) {
      let inside = false;
      const p = b.footprint;
      for (let i = 0, j = p.length - 1; i < p.length; j = i++) {
        if (
          p[i][1] > y / 16 !== p[j][1] > y / 16 &&
          x / 16 <
            ((p[j][0] - p[i][0]) * (y / 16 - p[i][1])) / (p[j][1] - p[i][1]) +
              p[i][0]
        )
          inside = !inside;
      }
      if (inside) return false;
    }
    return true;
  }

}
