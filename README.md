# Tachyon

A 3D/2D game engine built in Crystal, rendered via GTK4 GtkGLArea with OpenGL 4.1, and a JavaScript scripting layer powered by QuickJS through Medusa.

Tachyon is designed to be both a standalone engine and an embeddable rendering widget for Crystal GTK4 applications.

## Features

### Rendering
- **PBR Materials** — Cook-Torrance BRDF with GGX normal distribution, Smith geometry, and Schlick Fresnel
- **Shadow Mapping** — Directional light shadow maps with 5x5 PCF soft shadows (configurable up to 4096x4096)
- **Multiple Light Types** — Directional, point, and spot lights with distance attenuation (up to 8 simultaneous)
- **Skybox** — Procedural gradient skybox with cubemap support
- **Post-Processing** — Bloom via bright extraction, Gaussian blur ping-pong, and HDR compositing
- **Transparency** — Alpha blending with separate opaque and transparent render passes
- **Wireframe Mode** — Per-object wireframe rendering toggle

### Geometry
- **Built-in Primitives** — Cube, Sphere, Plane, Cylinder, Cone, Torus
- **OBJ Model Loading** — Wavefront OBJ parser with positions, normals, UVs, and fan triangulation
- **Mesh API** — `Mesh.load("model.obj")` from JavaScript
- **Vertex Layout** — 8 floats per vertex: position (3), normal (3), UV (2)

### 2D Canvas Mode
- **Sprite System** — Create, position, color, and layer sprites
- **Layer-Based Rendering** — Z-ordering by layer for proper 2D draw order
- **Canvas Background** — Configurable background color
- **Bitmap Font** — Built-in bitmap font with A-Z, a-z, 0-9, and common punctuation
- **2D/3D Switching** — Same engine runs both modes, selected by `Canvas.setup()` in JS

### GUI Overlay
- **Rect Drawing** — Colored rectangles with alpha for panels and backgrounds
- **Text Rendering** — Bitmap font text overlay on top of 3D scenes
- **HUD System** — FPS counters, health bars, score displays, crosshairs

### Audio
- **Miniaudio Backend** — Cross-platform audio via miniaudio (single header C library)
- **Fire-and-Forget** — `Audio.play("sound.wav")` for one-shot sounds
- **Controlled Playback** — Load, play, stop, and volume control for music/loops
- **Format Support** — WAV, MP3, FLAC, and other formats supported by miniaudio

### Physics & Collision
- **Fixed Timestep** — Deterministic physics via `onFixedUpdate` at 60Hz
- **AABB Collision** — Axis-aligned bounding box intersection testing
- **Ray Casting** — Full ray intersection: AABB (slab method), sphere, plane
- **Per-Triangle Raycasting** — Möller–Trumbore algorithm for precise mesh picking
- **Scene Picking** — `Scene.pick(mouseX, mouseY)` returns the clicked 3D object with two-phase broad+narrow detection

### Input
- **Keyboard** — `keyDown`, `keyPressed`, `keyReleased` with GTK key names
- **Mouse** — Position, delta, button down/pressed for left/right/middle buttons
- **Focus Management** — Click-to-focus on the GL viewport

### Scripting
- **QuickJS via Medusa** — ES module JavaScript with full `import`/`export` support
- **Lifecycle Callbacks** — `onStart`, `onUpdate(dt)`, `onFixedUpdate(dt)`
- **Clean GC Separation** — Handle registry bridges Crystal's Boehm GC and QuickJS's reference counting
- **Custom Functions** — Register Crystal functions callable from JS via `engine.register_function`

### Architecture
- **Embeddable Viewport** — `Tachyon::Viewport` is a self-contained GTK widget
- **Application Wrapper** — `Tachyon::Window::Application` provides a standalone runner
- **Callback Bridge** — C++ bridge with typed callback slots for zero-overhead Crystal↔JS communication

## Prerequisites

- **Crystal** 1.18+
- **GTK4** development libraries
- **OpenGL 4.1** capable GPU (macOS, Linux)

### macOS

```bash
brew install gtk4 crystal
```

### Linux

```bash
sudo apt install libgtk-4-dev crystal
```

## Building

```bash
# Install Crystal dependencies
shards install

# Compile the C++ libraries
make

# Run with a game script
crystal run src/window/application.cr -- examples/game.js
```

## JavaScript API

### 3D Mode

```javascript
import {
  Scene, Cube, Sphere, Plane, Cylinder, Cone, Torus, Mesh,
  Vector3, Input, Camera, PointLight, GUI, Audio
} from "tachyon";

// Create geometry
const cube = new Cube({ width: 1, height: 1, depth: 1 });

cube.position = new Vector3(0, 0.5, 0);
cube.setMaterialColor(0.9, 0.15, 0.1);

Scene.add(cube);

// Load an OBJ model
const model = Mesh.load("assets/model.obj");
model.position = new Vector3(3, 0, 0);
Scene.add(model);

// Camera
Camera.setPosition(new Vector3(0, 5, 10));
Camera.setTarget(new Vector3(0, 0, 0));
Camera.setFOV(60);

// Point light
const light = new PointLight({
  x: 2, y: 3, z: 1,
  r: 1, g: 0.8, b: 0.6,
  intensity: 3, range: 10
});

// Audio
Audio.play("assets/hit.wav");

// Lifecycle
export function onStart() {
  // Called once after script loads
}

export function onUpdate(dt) {
  cube.rotate(0, dt * 45, 0);

  // Input
  if (Input.keyDown("W")) cube.translate(0, 0, -dt * 3);
  if (Input.keyDown("S")) cube.translate(0, 0, dt * 3);

  // Raycasting
  if (Input.mouseButtonDown(0)) {
    const mouse = Input.mousePosition();
    const hit = Scene.pick(mouse.x, mouse.y);
    if (hit) hit.setMaterialColor(1, 1, 0);
  }

  // GUI overlay
  GUI.rect(10, 10, 200, 30, 0, 0, 0, 0.7);
  GUI.text("SCORE: 100", 15, 15, 1.5, 1, 1, 1, 1);
}

export function onFixedUpdate(dt) {
  // Called at fixed 60Hz for physics
}
```

### 2D Canvas Mode

```javascript
import { Canvas, Sprite, Input, Audio } from "tachyon";

Canvas.setup(1280, 720);
Canvas.background(0.05, 0.05, 0.15);

const player = Sprite.create({ width: 40, height: 40 });
player.x = 640;
player.y = 300;
player.setColor(0.2, 0.8, 1.0, 1.0);
player.layer = 1;

export function onUpdate(dt) {
  if (Input.keyDown("A")) player.x -= dt * 400;
  if (Input.keyDown("D")) player.x += dt * 400;

  Canvas.text("SCORE: 100", 10, 10, 2.0, 1.0, 1.0, 1.0, 1.0);
}
```

### API Reference

#### Geometry Constructors

| Constructor | Parameters | Description |
|---|---|---|
| `new Cube(opts)` | `width`, `height`, `depth` | Box primitive |
| `new Sphere(opts)` | `radius`, `segments`, `rings` | UV sphere |
| `new Plane(opts)` | `width`, `height` | XZ ground plane |
| `new Cylinder(opts)` | `radius`, `height`, `segments` | Capped cylinder |
| `new Cone(opts)` | `radius`, `height`, `segments` | Cone with base |
| `new Torus(opts)` | `majorRadius`, `minorRadius`, `majorSegments`, `minorSegments` | Torus |
| `Mesh.load(path)` | OBJ file path | Load external model |

#### Node Properties & Methods

| Property/Method | Description |
|---|---|
| `node.position` | Get/set Vector3 position |
| `node.scale` | Get/set Vector3 scale |
| `node.visible` | Get/set visibility |
| `node.wireframe` | Set wireframe rendering |
| `node.rotate(x, y, z)` | Rotate by degrees |
| `node.translate(x, y, z)` | Move relative |
| `node.lookAt(target)` | Face a Vector3 target |
| `node.setMaterialColor(r, g, b)` | Set albedo color (0-1) |
| `node.destroy()` | Remove and clean up |

#### Scene

| Method | Description |
|---|---|
| `Scene.add(node)` | Add node to scene |
| `Scene.remove(node)` | Remove node from scene |
| `Scene.find(name)` | Find node by name |
| `Scene.clear()` | Remove all nodes |
| `Scene.pick(x, y)` | Raycast at screen coordinates, returns hit node |

#### Camera

| Method | Description |
|---|---|
| `Camera.setPosition(vec3)` | Set camera world position |
| `Camera.getPosition()` | Get camera position |
| `Camera.setTarget(vec3)` | Set look-at target |
| `Camera.getTarget()` | Get look-at target |
| `Camera.setFOV(degrees)` | Set field of view |

#### Input

| Method | Description |
|---|---|
| `Input.keyDown(key)` | True while key is held |
| `Input.keyPressed(key)` | True on frame key was pressed |
| `Input.keyReleased(key)` | True on frame key was released |
| `Input.mouseButtonDown(btn)` | True while mouse button held |
| `Input.mousePosition()` | Returns Vector3 (x, y, 0) |
| `Input.mouseDelta()` | Returns Vector3 (dx, dy, 0) |
| `Input.lockCursor()` | Lock the mouse cursor to the center |
| `Input.unlockCursor(key)` | Unlock the mouse cursor |

#### GUI (3D Overlay)

| Method | Description |
|---|---|
| `GUI.rect(x, y, w, h, r, g, b, a)` | Draw colored rectangle |
| `GUI.text(str, x, y, scale, r, g, b, a)` | Draw text |

#### Canvas (2D Mode)

| Method | Description |
|---|---|
| `Canvas.setup(width, height)` | Enable 2D mode |
| `Canvas.background(r, g, b)` | Set background color |
| `Canvas.text(str, x, y, scale, r, g, b, a)` | Draw 2D text |

#### Sprite (2D)

| Property/Method | Description |
|---|---|
| `Sprite.create(opts)` | Create sprite with `width`, `height` |
| `Sprite.load(path)` | Load sprite from image file |
| `sprite.x`, `sprite.y` | Position |
| `sprite.visible` | Visibility toggle |
| `sprite.layer` | Z-order layer |
| `sprite.setColor(r, g, b, a)` | Set sprite color |
| `sprite.destroy()` | Remove sprite |

#### Audio

| Method | Description |
|---|---|
| `Audio.play(path)` | Play sound (fire and forget) |
| `Audio.load(path)` | Load sound, returns handle |
| `Audio.stop(handle)` | Stop a loaded sound |
| `Audio.setVolume(handle, vol)` | Set volume (0.0 - 1.0) |

#### Vector3

| Method | Description |
|---|---|
| `new Vector3(x, y, z)` | Constructor |
| `vec.x`, `vec.y`, `vec.z` | Component access |
| `vec.add(other)` | Addition |
| `vec.sub(other)` | Subtraction |
| `vec.mul(scalar)` | Scalar multiply |
| `vec.dot(other)` | Dot product |
| `vec.cross(other)` | Cross product |
| `vec.normalize()` | Unit vector |
| `vec.magnitude()` | Length |
| `vec.distance(other)` | Distance between points |
| `Vector3.zero()` | (0, 0, 0) |
| `Vector3.one()` | (1, 1, 1) |
| `Vector3.up()` | (0, 1, 0) |
| `Vector3.lerp(a, b, t)` | Linear interpolation |

## Embedding in GTK4 Applications

Tachyon can be embedded as a widget in any Crystal GTK4 application:

```crystal
require "gtk4"
require "tachyon"

app = Gtk::Application.new("com.myapp", Gio::ApplicationFlags::None)

app.activate_signal.connect do
  window = Gtk::ApplicationWindow.new(app)
  window.set_default_size(1400, 800)

  box = Gtk::Box.new(:horizontal, 0)

  # Your app UI
  sidebar = Gtk::Box.new(:vertical, 8)
  sidebar.append(Gtk::Label.new("Scene Editor"))
  sidebar.append(Gtk::Button.new(label: "Add Cube"))
  sidebar.set_size_request(200, -1)

  # Tachyon viewport
  viewport = Tachyon::Viewport.new(id: "editor")
  viewport.gl_area.hexpand = true
  viewport.gl_area.vexpand = true

  # You need to hook the input for the viewport, see src/window/application.cr,
  # if you want actual interactive renders.

  box.append(sidebar)
  box.append(viewport.gl_area)

  window.child = box
  window.present
end

app.run(ARGV)
```

## Technical Details

### Render Pipeline

Each frame executes in order:

1. **JS Update** — `onUpdate(dt)` and `onFixedUpdate(dt)` callbacks
2. **Shadow Pass** — Render scene from directional light into depth FBO
3. **Main PBR Pass** — Cook-Torrance BRDF with multi-light support
4. **Skybox Pass** — Rendered at depth 1.0 with `gl_Position = pos.xyww` trick
5. **Post-Processing** — Bloom via `glBlitFramebuffer` (GTK4 compatible)
6. **GUI Overlay** — 2D rects and bitmap font text on top

### Architecture

```
JavaScript (game.js)
    ↓ ES module import
QuickJS (via Medusa)
    ↓ C function calls
tachyon_bridge.cpp (callback dispatch)
    ↓ Crystal proc invocation
Crystal Engine (scene graph, renderer, audio)
    ↓ OpenGL calls
GTK4 GtkGLArea → GPU
```

## Contributing

1. Fork it (<https://github.com/grkek/tachyon/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Giorgi Kavrelishvili](https://github.com/grkek) - creator and maintainer

## Acknowledgements

- [Crystal](https://crystal-lang.org) — the language
- [gtk4.cr](https://github.com/hugopl/gtk4.cr) — GTK4 Crystal bindings
- [QuickJS](https://bellard.org/quickjs/) — JavaScript engine
- [stb_image](https://github.com/nothings/stb) — image loading
- [miniaudio](https://github.com/mackron/miniaudio) — audio playback