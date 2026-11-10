# Examples

Two runnable examples.

## backends

```text
backends/
  build.zig
  build.zig.zon
  src/
    main.zig          — dispatch
    draw.zig          — shared scene
    metal.m           — shared macOS bridge
    NotoSans.ttf
    backends/
      glfw.zig
      sdl3.zig
      wio.zig
```

```bash
cd examples/backends
zig build sdl3
zig build glfw
zig build wio

zig build run-glfw
zig build run-sdl3
zig build run-wio
```

## shaders

```text
shaders/
  build.zig
  build.zig.zon
  src/
    main.zig          — dispatch
    draw.zig          — shared SDL3/Impeller runner
    metal.m
    shaders/
      planet.iplr
      liquid_glass.iplr
```

```bash
cd examples/shaders
zig build planet
zig build liquid-glass

zig build run-planet
zig build run-liquid-glass
```

Both shader examples use SDL3 and Impeller.
