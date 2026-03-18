import {
  Vector3, Cube, Sphere, Plane, Cylinder, Cone, Torus,
  Scene, Camera, Input, GUI, PointLight, Particles, Debug, Configuration
} from "tachyon";

// Scene objects
var orb, orbRing, orbInner;
var floatingRocks = [];
var crystalPillars = [];
var waterPlane;

// Particle emitters
var orbEmitter, portalEmitter, rainEmitter, burstEmitter;

// Camera
var cameraPos = new Vector3(18, 8, 0);
var cameraTarget = new Vector3(0, 2, 0);
var cameraOrbitSpeed = 0.12;
var cameraManual = false;

// State
var time = 0;
var fogEnabled = true;
var fogDense = false;
var particlesEnabled = true;
var shadowsEnabled = true;
var wireframeMode = false;
var orbColor = 0;

// Color palettes for the orb cycling (r, g, b, emR, emG, emB)
var orbPalettes = [
  { r: 0.1, g: 0.2, b: 0.8, er: 0.1, eg: 0.3, eb: 1.0, name: "Arcane Blue" },
  { r: 0.8, g: 0.1, b: 0.1, er: 1.0, eg: 0.15, eb: 0.05, name: "Infernal Red" },
  { r: 0.1, g: 0.8, b: 0.3, er: 0.05, eg: 1.0, eb: 0.3, name: "Nature Green" },
  { r: 0.7, g: 0.4, b: 0.9, er: 0.6, eg: 0.2, eb: 1.0, name: "Void Purple" },
  { r: 0.9, g: 0.8, b: 0.2, er: 1.0, eg: 0.9, eb: 0.1, name: "Solar Gold" },
];

// Scene construction

// Ground: dark stone expanse
try {
  var ground = new Plane({ width: 80, height: 80 });
  ground.setMaterialColor(0.06, 0.06, 0.07);
  ground.setMaterialRoughness(0.9);
  ground.loadTexture("./example/assets/stone.jpg", 0);
  ground.setTextureScale(32, 32);
  Scene.add(ground);
} catch (e) { Debug.error("ground: " + e.message); }

// Raised circular platform
try {
  var platform = new Cylinder({ radius: 12, height: 0.5, segments: 64 });
  platform.position = new Vector3(0, 0.25, 0);
  platform.setMaterialColor(0.12, 0.11, 0.1);
  platform.setMaterialRoughness(0.7);
  platform.loadTexture("./example/assets/stone.jpg", 0);
  platform.setTextureScale(16, 16);
  Scene.add(platform);
} catch (e) { Debug.error("platform: " + e.message); }

// Inner ritual circle
try {
  var innerRing = new Torus({ majorRadius: 5.0, minorRadius: 0.15, majorSegments: 64 });
  innerRing.position = new Vector3(0, 0.55, 0);
  innerRing.setMaterialColor(0.3, 0.25, 0.2);
  innerRing.setMaterialMetallic(0.8);
  innerRing.setMaterialRoughness(0.2);
  innerRing.setMaterialEmissive(0.15, 0.1, 0.05);
  innerRing.setMaterialEmissiveStrength(0.5);
  innerRing.loadTexture("./example/assets/metal.jpg", 0);
  Scene.add(innerRing);
} catch (e) { Debug.error("innerRing: " + e.message); }

// Central altar
try {
  var altar = new Cylinder({ radius: 1.2, height: 1.8, segments: 8 });
  altar.position = new Vector3(0, 0.9, 0);
  altar.setMaterialColor(0.1, 0.1, 0.12);
  altar.setMaterialMetallic(0.4);
  altar.setMaterialRoughness(0.3);
  altar.loadTexture("./example/assets/metal.jpg", 0);
  altar.setTextureScale(3, 3);
  Scene.add(altar);
} catch (e) { Debug.error("altar: " + e.message); }

// Floating orb (centerpiece)
try {
  orb = new Sphere({ radius: 0.55, segments: 48, rings: 24 });
  orb.position = new Vector3(0, 3.0, 0);
  orb.setMaterialColor(0.95, 0.95, 1.0);
  orb.setMaterialMetallic(0.95);
  orb.setMaterialRoughness(0.02);
  orb.setMaterialEmissive(0.1, 0.3, 1.0);
  orb.setMaterialEmissiveStrength(1.0);
  orb.loadTexture("./example/assets/marble.jpg", 0);
  Scene.add(orb);
} catch (e) { Debug.error("orb: " + e.message); }

// Inner glow sphere
try {
  orbInner = new Sphere({ radius: 0.35, segments: 24, rings: 12 });
  orbInner.position = new Vector3(0, 3.0, 0);
  orbInner.setMaterialColor(1.0, 1.0, 1.0);
  orbInner.setMaterialEmissive(0.2, 0.5, 1.0);
  orbInner.setMaterialEmissiveStrength(3.0);
  Scene.add(orbInner);
} catch (e) { Debug.error("orbInner: " + e.message); }

// Orbiting ring
try {
  orbRing = new Torus({ majorRadius: 0.85, minorRadius: 0.025, majorSegments: 64 });
  orbRing.position = new Vector3(0, 3.0, 0);
  orbRing.setMaterialColor(0.5, 0.7, 1.0);
  orbRing.setMaterialMetallic(1.0);
  orbRing.setMaterialRoughness(0.05);
  orbRing.setMaterialEmissive(0.3, 0.5, 1.0);
  orbRing.setMaterialEmissiveStrength(2.5);
  Scene.add(orbRing);
} catch (e) { Debug.error("orbRing: " + e.message); }

// Monolith pillars with crystal caps
try {
  var pillarCount = 10;
  var pillarRadius = 10;
  for (var i = 0; i < pillarCount; i++) {
    var angle = (i / pillarCount) * Math.PI * 2;
    var px = Math.cos(angle) * pillarRadius;
    var pz = Math.sin(angle) * pillarRadius;
    var pillarH = 5.0 + Math.sin(i * 1.7) * 2.0;

    var pillar = new Cylinder({ radius: 0.4, height: pillarH, segments: 6 });
    pillar.position = new Vector3(px, pillarH * 0.5, pz);
    pillar.setMaterialColor(0.18, 0.16, 0.15);
    pillar.setMaterialRoughness(0.85);
    pillar.loadTexture("./example/assets/stone.jpg", 0);
    pillar.setTextureScale(2, 4);
    Scene.add(pillar);

    var crystal = new Cone({ radius: 0.18, height: 0.8, segments: 5 });
    crystal.position = new Vector3(px, pillarH + 0.4, pz);
    var ci = i % 3;
    var cr = ci === 0 ? 0.2 : ci === 1 ? 0.8 : 0.1;
    var cg = ci === 0 ? 0.5 : ci === 1 ? 0.2 : 0.9;
    var cb = ci === 0 ? 1.0 : ci === 1 ? 0.3 : 0.4;
    crystal.setMaterialColor(cr, cg, cb);
    crystal.setMaterialMetallic(0.6);
    crystal.setMaterialRoughness(0.1);
    crystal.setMaterialEmissive(cr, cg, cb);
    crystal.setMaterialEmissiveStrength(1.8);
    Scene.add(crystal);
    crystalPillars.push({ pillar: pillar, crystal: crystal, angle: angle, baseH: pillarH });
  }
} catch (e) { Debug.error("pillars: " + e.message); }

// Floating rocks around the scene
try {
  for (var i = 0; i < 20; i++) {
    var dist = 6 + Math.random() * 18;
    var angle = Math.random() * Math.PI * 2;
    var rx = Math.cos(angle) * dist;
    var rz = Math.sin(angle) * dist;
    var ry = 1.5 + Math.random() * 5.0;
    var size = 0.15 + Math.random() * 0.6;

    var rock = new Cube({ width: size, height: size * 0.7, depth: size * 0.9 });
    rock.position = new Vector3(rx, ry, rz);
    rock.rotate(Math.random() * 360, Math.random() * 360, Math.random() * 360);
    rock.setMaterialColor(0.12 + Math.random() * 0.08, 0.1 + Math.random() * 0.06, 0.1 + Math.random() * 0.05);
    rock.setMaterialRoughness(0.8 + Math.random() * 0.2);
    rock.loadTexture("./example/assets/stone.jpg", 0);
    Scene.add(rock);
    floatingRocks.push({ node: rock, baseY: ry, speed: 0.3 + Math.random() * 0.8, phase: Math.random() * Math.PI * 2 });
  }
} catch (e) { Debug.error("rocks: " + e.message); }

// Scattered ground debris
try {
  for (var i = 0; i < 15; i++) {
    var rx = (Math.random() - 0.5) * 30;
    var rz = (Math.random() - 0.5) * 30;
    var size = 0.15 + Math.random() * 0.4;
    var debris = new Cube({ width: size, height: size * 0.5, depth: size });
    debris.position = new Vector3(rx, size * 0.25, rz);
    debris.rotate(0, Math.random() * 360, 0);
    debris.setMaterialColor(0.13, 0.12, 0.11);
    debris.loadTexture("./example/assets/stone.jpg", 0);
    Scene.add(debris);
  }
} catch (e) { Debug.error("debris: " + e.message); }

// Lights
try {
  // Central orb light
  new PointLight({ x: 0, y: 3.5, z: 0, r: 0.2, g: 0.5, b: 1.0, intensity: 5.0, range: 25.0 });

  // Crystal pillar lights
  for (var i = 0; i < 10; i += 2) {
    var angle = (i / 10) * Math.PI * 2;
    var ci = i % 3;
    var lr = ci === 0 ? 0.2 : ci === 1 ? 0.8 : 0.1;
    var lg = ci === 0 ? 0.5 : ci === 1 ? 0.2 : 0.9;
    var lb = ci === 0 ? 1.0 : ci === 1 ? 0.3 : 0.4;
    new PointLight({
      x: Math.cos(angle) * 10, y: 7, z: Math.sin(angle) * 10,
      r: lr, g: lg, b: lb, intensity: 2.0, range: 8.0
    });
  }

  // Rim lights
  new PointLight({ x: 20, y: 4, z: 0, r: 0.05, g: 0.05, b: 0.15, intensity: 1.5, range: 30.0 });
  new PointLight({ x: -20, y: 4, z: 0, r: 0.15, g: 0.05, b: 0.05, intensity: 1.5, range: 30.0 });
} catch (e) { Debug.error("lights: " + e.message); }

// Orb particle fountain
try {
  orbEmitter = Particles.createEmitter({ maxParticles: 512 });
  Particles.setPosition(orbEmitter, new Vector3(0, 3.0, 0));
  Particles.setDirection(orbEmitter, new Vector3(0, 1, 0));
  Particles.setSizes(orbEmitter, 0.05, 0.005);
  Particles.setSpeed(orbEmitter, 0.5, 1.5);
  Particles.setLifetime(orbEmitter, 1.0, 3.5);
  Particles.setGravity(orbEmitter, new Vector3(0, 0.3, 0));
  Particles.setRate(orbEmitter, 40);
  Particles.setSpread(orbEmitter, 0.8);
} catch (e) { Debug.error("orbEmitter: " + e.message); }

// Portal swirl at ground level
try {
  portalEmitter = Particles.createEmitter({ maxParticles: 512 });
  Particles.loadTexture(portalEmitter, "./example/assets/smoke.png");
  Particles.setPosition(portalEmitter, new Vector3(0, 0.8, 0));
  Particles.setDirection(portalEmitter, new Vector3(0, 1.0, 0));
  Particles.setSizes(portalEmitter, 0.6, 0.08);
  Particles.setSpeed(portalEmitter, 0.3, 1.2);
  Particles.setLifetime(portalEmitter, 2.0, 5.0);
  Particles.setGravity(portalEmitter, new Vector3(0, 0.15, 0));
  Particles.setRate(portalEmitter, 18);
  Particles.setSpread(portalEmitter, 1.2);
  Particles.setColors(portalEmitter,
    new Vector3(0.3, 0.5, 1.0),
    new Vector3(0.5, 0.1, 0.8)
  );
} catch (e) { Debug.error("portalEmitter: " + e.message); }


// Ambient dust/rain
try {
  rainEmitter = Particles.createEmitter({ maxParticles: 512 });

  Particles.setPosition(rainEmitter, new Vector3(0, 15, 0));
  Particles.setDirection(rainEmitter, new Vector3(0, -1, 0));
  Particles.setSizes(rainEmitter, 0.03, 0.01);
  Particles.setSpeed(rainEmitter, 2.0, 5.0);
  Particles.setLifetime(rainEmitter, 2.0, 4.0);
  Particles.setGravity(rainEmitter, new Vector3(0, -2, 0));
  Particles.setRate(rainEmitter, 25);
  Particles.setSpread(rainEmitter, 1.2);
} catch (e) { Debug.error("rainEmitter: " + e.message); }

// Burst emitter for spacebar
try {
  burstEmitter = Particles.createEmitter({ maxParticles: 1024 });

  Particles.setPosition(burstEmitter, new Vector3(0, 3.0, 0));
  Particles.setDirection(burstEmitter, new Vector3(0, 1, 0));
  Particles.setSizes(burstEmitter, 0.06, 0.01);
  Particles.setSpeed(burstEmitter, 4, 12);
  Particles.setLifetime(burstEmitter, 0.5, 2.0);
  Particles.setGravity(burstEmitter, new Vector3(0, -5, 0));
  Particles.setRate(burstEmitter, 0);
  Particles.setSpread(burstEmitter, 3.14159);
} catch (e) { Debug.error("burstEmitter: " + e.message); }

// Lifecycle

export function onStart() {
  Camera.setPosition(cameraPos);
  Camera.setTarget(cameraTarget);
  Camera.setFOV(65);

  Configuration.setShadowResolution(4096);

  fogEnabled = true;
  Scene.setFog({ color: [0.02, 0.015, 0.04], near: 5, far: 20, mode: "exponential", density: 0.04 });
}

export function onUpdate(dt) {
  time += dt;
  GUI.clear();

  handleInput(dt);
  updateCamera(dt);
  updateOrb(dt);
  updateFloatingRocks(dt);
  updatePortalEmitter(dt);
  drawHUD(dt);
}

function handleInput(dt) {
  // Space: particle burst
  if (Input.keyPressed("Space") && burstEmitter) {
    Particles.emitBurst(burstEmitter, 300);
  }

  // F: cycle fog modes (off / light / dense)
  if (Input.keyPressed("F")) {
    if (!fogEnabled) {
      fogEnabled = true;
      Scene.setFog({ color: [0.02, 0.015, 0.04], near: 5, far: 20, mode: "exponential", density: 0.04 });
    } else {
      fogEnabled = false;
      Scene.clearFog();
    }
  }

  if (Input.keyPressed("T")) {
    shadowsEnabled = Configuration.toggleShadow();
  }

  // C: cycle orb color palette
  if (Input.keyPressed("C")) {
    orbColor = (orbColor + 1) % orbPalettes.length;
    var pal = orbPalettes[orbColor];
    if (orb) {
      orb.setMaterialEmissive(pal.er, pal.eg, pal.eb);
    }
    if (orbInner) {
      orbInner.setMaterialEmissive(pal.er * 2, pal.eg * 2, pal.eb * 2);
    }
    if (orbRing) {
      orbRing.setMaterialColor(pal.r, pal.g, pal.b);
      orbRing.setMaterialEmissive(pal.er, pal.eg, pal.eb);
    }
  }

  // P: toggle particles on/off
  if (Input.keyPressed("P")) {
    particlesEnabled = !particlesEnabled;
    var rate = particlesEnabled ? 1 : 0;
    if (orbEmitter) Particles.setRate(orbEmitter, particlesEnabled ? 40 : 0);
    if (portalEmitter) Particles.setRate(portalEmitter, particlesEnabled ? 12 : 0);
    if (rainEmitter) Particles.setRate(rainEmitter, particlesEnabled ? 25 : 0);
  }

  // W: toggle wireframe on all crystal pillars
  if (Input.keyPressed("W")) {
    wireframeMode = !wireframeMode;
    for (var i = 0; i < crystalPillars.length; i++) {
      crystalPillars[i].pillar.wireframe = wireframeMode;
      crystalPillars[i].crystal.wireframe = wireframeMode;
    }
    if (orb) orb.wireframe = wireframeMode;
    if (orbRing) orbRing.wireframe = wireframeMode;
  }

  // M: toggle manual camera (WASD to move)
  if (Input.keyPressed("M")) {
    cameraManual = !cameraManual;
  }

  // R: reset everything
  if (Input.keyPressed("R")) {
    orbColor = 0;
    fogEnabled = true;
    fogDense = false;
    particlesEnabled = true;
    wireframeMode = false;
    cameraManual = false;
    Scene.setFog({ color: [0.01, 0.01, 0.025], near: 15, far: 40, mode: "linear" });
    if (orbEmitter) Particles.setRate(orbEmitter, 40);
    if (portalEmitter) Particles.setRate(portalEmitter, 12);
    if (rainEmitter) Particles.setRate(rainEmitter, 25);
    if (orb) {
      orb.wireframe = false;
      orb.setMaterialEmissive(0.1, 0.3, 1.0);
    }
    if (orbInner) orbInner.setMaterialEmissive(0.2, 0.5, 1.0);
    if (orbRing) {
      orbRing.wireframe = false;
      orbRing.setMaterialColor(0.5, 0.7, 1.0);
      orbRing.setMaterialEmissive(0.3, 0.5, 1.0);
    }
    for (var i = 0; i < crystalPillars.length; i++) {
      crystalPillars[i].pillar.wireframe = false;
      crystalPillars[i].crystal.wireframe = false;
    }
  }
}

function updateCamera(dt) {
  if (cameraManual) {
    var moveSpeed = 12.0 * dt;
    // Forward/back relative to look direction
    if (Input.keyDown("W")) { cameraPos.y += moveSpeed * 0.5; }
    if (Input.keyDown("S")) { cameraPos.y -= moveSpeed * 0.5; }
    if (Input.keyDown("A")) { cameraOrbitSpeed += dt * 0.3; }
    if (Input.keyDown("D")) { cameraOrbitSpeed -= dt * 0.3; }
    // Still orbit but at manual speed
    var angle = time * cameraOrbitSpeed;
    var dist = 18;
    cameraPos.x = Math.cos(angle) * dist;
    cameraPos.z = Math.sin(angle) * dist;
  } else {
    // Auto orbit with gentle vertical sway
    var angle = time * 0.12;
    var lift = 7 + Math.sin(time * 0.25) * 2.0;
    var dist = 18 + Math.sin(time * 0.18) * 3;
    cameraPos.x = Math.cos(angle) * dist;
    cameraPos.y = lift;
    cameraPos.z = Math.sin(angle) * dist;
  }
  Camera.setPosition(cameraPos);
  Camera.setTarget(cameraTarget);
}

function updateOrb(dt) {
  var pulse = 0.5 + Math.sin(time * 1.5) * 0.5;
  var bob = Math.sin(time * 0.8) * 0.3;

  if (orb) {
    orb.position = new Vector3(0, 3.0 + bob, 0);
    orb.setMaterialEmissiveStrength(0.5 + pulse * 1.5);
    orb.rotate(0, dt * 15, dt * 8);
  }
  if (orbInner) {
    orbInner.position = new Vector3(0, 3.0 + bob, 0);
    orbInner.setMaterialEmissiveStrength(2.0 + pulse * 3.0);
  }
  if (orbRing) {
    orbRing.position = new Vector3(0, 3.0 + bob, 0);
    orbRing.rotate(dt * 8, dt * 45, dt * 3);
  }

  // Update orb emitter position
  if (orbEmitter) {
    Particles.setPosition(orbEmitter, new Vector3(0, 3.0 + bob, 0));
  }
  if (burstEmitter) {
    Particles.setPosition(burstEmitter, new Vector3(0, 3.0 + bob, 0));
  }
}

function updateFloatingRocks(dt) {
  for (var i = 0; i < floatingRocks.length; i++) {
    var r = floatingRocks[i];
    var newY = r.baseY + Math.sin(time * r.speed + r.phase) * 0.5;
    var pos = r.node.position;
    r.node.position = new Vector3(pos.x, newY, pos.z);
    r.node.rotate(0, dt * (r.speed * 10), 0);
  }
}

function updatePortalEmitter(dt) {
  if (!portalEmitter) return;
  // Slowly move portal emitter in a circle
  var angle = time * 0.5;
  var px = Math.cos(angle) * 4.5;
  var pz = Math.sin(angle) * 4.5;
  Particles.setPosition(portalEmitter, new Vector3(px, 0.6, pz));
}

function drawHUD(dt) {
  var fps = dt > 0 ? Math.floor(1.0 / dt) : 0;
  var pal = orbPalettes[orbColor];

  // Title bar
  GUI.rect(8, 8, 350, 250, 0, 0, 0, 0.6);
  GUI.text("TACHYON ENGINE", 18, 14, 2.4, 0.0, 0.0, 0.0, 0.9);
  GUI.text("FPS: " + fps, 18, 38, 1.6, 0.0, 0.0, 0.0, 0.8);

  var cy = 70;
  var lh = 18;

  GUI.text("SPACE  Particle burst", 18, cy + 6, 1.5, 0.0, 0.0, 0.0, 0.8);
  GUI.text("F      Fog: " + (fogEnabled ? "On" : "Off"), 18, cy + 6 + lh, 1.5, 0.0, 0.0, 0.0, 0.8);
  GUI.text("C      Orb: " + pal.name, 18, cy + 6 + lh * 2, 1.5, 0.0, 0.0, 0.0, 0.9);
  GUI.text("P      Particles: " + (particlesEnabled ? "On" : "Off"), 18, cy + 6 + lh * 3, 1.5, 0.0, 0.0, 0.0, 0.8);
  GUI.text("W      Wireframe: " + (wireframeMode ? "On" : "Off"), 18, cy + 6 + lh * 4, 1.5, 0.0, 0.0, 0.0, 0.8);
  GUI.text("M      Camera: " + (cameraManual ? "Manual" : "Auto"), 18, cy + 6 + lh * 5, 1.5, 0.0, 0.0, 0.0, 0.8);
  GUI.text("T      Shadows: " + (shadowsEnabled ? "On" : "Off"), 18, cy + 6 + lh * 6, 1.5, 0.0, 0.0, 0.0, 0.8);
  GUI.text("R      Reset all", 18, cy + 6 + lh * 7, 1.5, 0.0, 0.0, 0.0, 0.6);

  if (cameraManual) {
    GUI.text("WASD   Adjust orbit", 18, cy + 6 + lh * 8, 1.5, 0.0, 0.0, 0.0, 0.7);
  }
}