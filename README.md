# impeller-zig

Zig bindings for Impeller's standalone `impeller.h` API.

Standalone SDK artifacts are packaged in [`impeller-sdk`](https://github.com/impeller-interop/impeller-sdk).

<p align="left">
  <img src="https://github.com/user-attachments/assets/938615ee-55aa-4a76-a106-c778151ede53" height="300">
  <img src="https://github.com/user-attachments/assets/07dd8543-4f0a-4dc1-ab9f-76c4e3a9a3ad" height="300"/>
</p>

> Examples [here](https://github.com/impeller-interop/impeller-zig-examples).

## Features

- Linux + Vulkan
- macOS + Metal
- Windows + Vulkan
- Zig wrappers for contexts, surfaces, paints, paths, textures, display lists, typography, and basic geometry

## Install

```bash
zig fetch --save git+https://github.com/impeller-interop/impeller-zig#main
```

Add the dependency in `build.zig`:

```zig
// ...
const impeller_dep = b.dependency("zig_impeller", .{
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
exe.root_module.linkLibrary(impeller_dep.artifact("impeller"));
// ...
```

Then import it:

```zig
const impeller = @import("impeller");
```

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

Runnable examples now live in the separate `impeller-zig-examples` repository so this package stays a pure library dependency with no windowing requirement.

## Status

- All of `impeller.h` is wrapped
- `zig build test` runs unit tests
- `FragmentProgram` is wrapped, but shader packaging is not documented here yet

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
