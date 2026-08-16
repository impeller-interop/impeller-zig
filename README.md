# impeller-zig

Zig wrapper for Impeller's standalone `impeller.h` API.

Standalone SDK artifacts are packaged in [`impeller-sdk`](https://github.com/impeller-interop/impeller-sdk).

<p align="center">
  <img src="https://github.com/user-attachments/assets/f143b456-1d55-4309-9817-6b53f7ab2ccb" height="300"/>
  <img src="https://github.com/user-attachments/assets/71ce96fe-fbe4-4195-aa36-aeee224b3830" height="300"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/883936cf-6c3b-40b6-a34a-0d6c7388b7cc" width="700"/>
</p>

<p align="center">
  <strong><a href="https://github.com/impeller-interop/impeller-zig-examples">Explore runnable examples →</a></strong>
</p>

## Features

- Linux + Vulkan
- macOS + Metal
- Windows + Vulkan
- Zig wrappers for contexts, surfaces, paints, paths, textures, display lists, typography, and basic geometry
- Flat domain modules such as `impeller.geometry`, `impeller.paint`, `impeller.path`, and `impeller.text`

## Zig support

[![Zig version support](https://zig-support.dkx215417.workers.dev/0.16.0/0.15.2/0.15.1/badge.svg)](https://ziglang.org/download/)

## Install

Install the latest release:

```bash
zig fetch --save git+https://github.com/impeller-interop/impeller-zig#v0.1.0
```

To follow the development branch instead:

```bash
zig fetch --save git+https://github.com/impeller-interop/impeller-zig#main
```

Add the dependency in `build.zig`:

```zig
// ...
const impeller_pkg = @import("impeller_zig");

const impeller_dep = b.dependency("impeller_zig", .{
    .target = target,
    .optimize = optimize,
});

const exe_mod = b.createModule(.{
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
    .imports = &.{
        .{ .name = "impeller", .module = impeller_dep.module("impeller") },
    },
});
const exe = b.addExecutable(.{
    .name = "app",
    .root_module = exe_mod,
});

// Link libimpeller and copy it beside the executable.
impeller_pkg.linkRuntime(exe, impeller_dep);
b.getInstallStep().dependOn(impeller_pkg.installRuntime(.{
    .compile_step = exe,
    .dependency = impeller_dep,
}));
// ...
```

Then import it:

```zig
const impeller = @import("impeller");
```

The main API is Zig-first:

```zig
var paint = try impeller.Paint.init();
defer paint.deinit();

paint.setColor(impeller.srgb(1.0, 0.2, 0.1, 1.0));
```

Common types are re-exported at the root for concise call sites. The same API is also split into flat domain modules:

```zig
const geometry = impeller.geometry;
const paint = impeller.paint;

const bounds = geometry.rect(0.0, 0.0, 640.0, 480.0);
var fill = try paint.Paint.init();
defer fill.deinit();
```

Use the `impeller.c` namespace only when you need raw C functions that are not wrapped yet.

The runtime link step is explicit so projects that only import the package without using Impeller do not load `libimpeller`.

For custom runtime install layouts and rpath setup, see [BUILD.md](docs/BUILD.md).

## Minimal drawing

Core drawing code:

```zig
var builder = try impeller.DisplayListBuilder.init(null);
defer builder.deinit();

var paint = try impeller.Paint.init();
defer paint.deinit();

paint.setColor(impeller.srgb(1.0, 1.0, 1.0, 1.0));
builder.drawPaint(paint);

paint.setColor(impeller.srgb(0.2, 0.4, 1.0, 1.0));
builder.drawRect(impeller.rect(120.0, 100.0, 240.0, 160.0), paint);

var list = try builder.build();
defer list.deinit();

try surface.draw(list);
try surface.present();
```

## Examples

Runnable examples live in [`impeller-zig-examples`](https://github.com/impeller-interop/impeller-zig-examples), keeping this package a pure library dependency with no windowing requirement.

## API notes

See [API.md](docs/API.md) for the API guide.

## Developer Tools

Fetch the current pinned header:

```bash
python3 tools/fetch_h.py --current
```

This updates `tools/impeller.h`, which is committed alongside `build.zig.zon`.

Fetch the latest stable header for comparison:

```bash
python3 tools/fetch_h.py
```

Use `--sha <engine-sha>` to fetch a specific Flutter engine header into `tools/impeller_<sha8>.h`.

Export the current SDK header surface:

```bash
python3 tools/export_h.py
```

Compare the current SDK header with another SDK:

```bash
python3 tools/diff_h.py --new tools/impeller_<sha8>.h
```

By default `diff_h.py` compares against `tools/impeller.h`. Use `--old /path/to/old/impeller.h` to compare against a specific header.

## LICENSE

[MIT](LICENSE)
