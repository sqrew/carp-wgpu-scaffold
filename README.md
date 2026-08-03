# Carp WebGPU Voxel Game Scaffold

An advanced, high-performance, real-time voxel game engine written in the **Carp** programming language (a statically typed Lisp with borrow checking) compiling to C and integrating with **WebGPU (wgpu-native)** and **GLFW**.

This project implements a hybrid Entity Component System (ECS) & Structure-of-Arrays (SOA) architecture, dynamic GPU JIT shader assembly and hot-reloading, trilinear voxel sampling, ambient occlusion, fluid/heat field cellular diffusion simulators, custom GUI rendering, and full rigid body physics.

---

## 🚀 Key Features

*   **GPU Voxel Raymarching Renderer**: Pure-GPU raymarching implementing shadow mapping, ambient occlusion, and trilinear interpolation on voxel grids.
*   **Voxel Simulator Fields (`FieldDatabase`)**: Real-time cellular simulation of 8 fields (`temperature`, `light`, `humidity`, `pressure`, `stress`, `gravity`, `density`, and `lifetime`) communicating via customizable diffusion kernels.
*   **Live Coding / JIT Hot Reloading**: Dynamic compilation of WGSL compute and render shaders. If a `.wgsl` shader or interaction rule is updated on disk, the WGPU pipelines are automatically rebuilt and swapped in real-time.
*   **Custom Immediate-Mode GUI**: Rendered directly in WebGPU, parsing Outfit fonts, panels, sliders, and buttons, generating custom draw commands.
*   **ECS & Spatial Partitioning**: Carp ECS mapping for lightweight game states, backed by an optimized Structure-of-Arrays database (`EntityDatabase`) and a 3D `SpatialGrid` for fast broad-phase collision queries.
*   **Rigid Body & SDF Physics Solver**: Interactive physical interactions, box/voxel collisions, contact normal estimation, and CSG tree solver logic.

---

## 📂 Project Directory Structure

```text
carp-wgpu-scaffold/
├── src/
│   ├── main.carp             # Entry point, GLFW window loop, GUI layouts
│   ├── engine.carp           # Game loop orchestrator, systems tick coordinator
│   ├── engine_type.carp      # Engine and Sun structural schemas
│   ├── init.carp             # WGPU Context/Surface and GLFW initialization
│   ├── components.carp       # ECS GameWorld definition and component tags
│   ├── entity_database.carp  # Structure-of-Arrays (SOA) entity records
│   ├── field_database.carp   # Environmental fields simulator kernels
│   ├── world.carp            # World and Chunk management, voxel caching
│   ├── render.carp           # WGPU renderer pipelines and inline C templates
│   ├── render_database.carp  # Render commands queue database
│   ├── physics_system.carp   # Collisions, trilinear SDF sampling, contact solver
│   ├── player_system.carp    # Movement, flying, crater-carving, and block placements
│   ├── coordinator.carp      # Event dispatcher and Priority Queue scheduler
│   ├── settings.carp         # Runtime configuration loader
│   ├── prefab.carp           # Bullet, rubble, and entity spawn templates
│   ├── debug_draw.carp       # Debug line visualizers
│   ├── shaders.carp          # In-app shader declarations
│   ├── shaders/              # WGSL compute, composite, and raymarching shaders
│   └── jit_rules/            # Water, gas, light, and interaction shader templates
├── assets/                   # Textures, font data, and graphical assets
├── settings.cfg              # Engine settings (voxel resolution, steps, gravity)
├── diagnostics.log           # Output performance diagnostic profiles
└── run.sh                    # Build and execute helper script
```

---

## 🛠️ Requirements & Setup

### Prerequisites
1. **Carp Compiler Fork**: A customized Carp compiler build is required. By default, the run script looks for it at `/home/sqrew/Desktop/Carp-fork`.
2. **WebGPU (wgpu-native)**: The WGPU C-bindings library must be installed/compiled and accessible by the dynamic linker.
3. **GLFW**: Window and input handling library.
4. **Development tools**: `clang` or `gcc`, standard library headers, and `X11` libraries (on Linux).

---

## 🏃 Running the Scaffold

To compile and launch the application under optimization flags:

```bash
chmod +x run.sh
./run.sh
```

The script navigates to the custom Carp fork directory and runs:
```bash
./scripts/carp.sh --optimize -x /path/to/project/src/main.carp
```

---

## ⚙️ Settings Configuration (`settings.cfg`)

You can modify basic rendering, simulation, and physics rules without recompiling by changing `settings.cfg`:

```ini
width=1280
height=720
shadow_quality=2          # Shadow map resolution multiplier
volumetric_sdf=false      # Toggle volume rendering shadows
fixed_dt=0.00833          # Target physics time-step delta
physics_iterations=8      # Solver loops per frame
gravity_y=-9.81           # Ambient gravity
voxel_resolution=32       # Voxel density per chunk dimension
```

---

## ⌨️ Default Controls

*   **`TAB`**: Toggle **Editor Mode**.
    *   *Disabled*: Controls player camera rotation (Mouse) and movement (Walk/Fly).
    *   *Enabled*: Re-enables the cursor, unlocks camera lock, and displays the **Voxel Engine Editor** panel.
*   **`W`, `A`, `S`, `D`**: Movement.
*   **`SPACE` / `LEFT SHIFT`**: Move up / down (when flying).
*   **`K`**: Cycle building material type.
*   **`Left Mouse Click`**: Carve craters / fire inputs.
