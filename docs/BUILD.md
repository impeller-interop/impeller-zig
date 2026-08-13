# Build

A quick reference for build integration.

## Contents

- [Runtime steps](#runtime-steps)
- [Default layout](#default-layout)
- [Custom layouts](#custom-layouts)
  - [Install to lib](#install-to-lib)
  - [Install to a custom directory](#install-to-a-custom-directory)
- [Platform notes](#platform-notes)

## Runtime steps

Add the Zig module import to the executable root module:

```zig
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
```

`linkRuntime()` and `installRuntime()` do different work:

| API | Purpose |
| --- | --- |
| `linkRuntime()` | Links the final executable or test artifact against the Impeller runtime. |
| `installRuntime()` | Copies the Impeller runtime library into the install prefix. |

Most applications need both:

```zig
const exe = b.addExecutable(.{
    .name = "app",
    .root_module = exe_mod,
});

impeller_pkg.linkRuntime(exe, impeller_dep);
b.getInstallStep().dependOn(impeller_pkg.installRuntime(.{
    .compile_step = exe,
    .dependency = impeller_dep,
}));
```

## Default layout

`installRuntime()` defaults to `.install_dir = .bin`.

| Platform | Installed runtime |
| --- | --- |
| Linux | `zig-out/bin/libimpeller.so` |
| macOS | `zig-out/bin/libimpeller.dylib` |
| Windows | `zig-out/bin/impeller.dll` |

If the runtime is installed beside the executable, use the matching runtime search path:

```zig
exe.root_module.addRPathSpecial("$ORIGIN");
```

On macOS:

```zig
exe.root_module.addRPathSpecial("@executable_path");
```

## Custom layouts

`install_dir` uses `std.Build.InstallDir`:

| Value | Install location |
| --- | --- |
| `.bin` | `zig-out/bin` |
| `.lib` | `zig-out/lib` |
| `.{ .custom = "runtime" }` | `zig-out/runtime` |

The install directory and runtime search path must match.

### Install to lib

Linux:

```zig
impeller_pkg.linkRuntime(exe, impeller_dep);
exe.root_module.addRPathSpecial("$ORIGIN/../lib");

b.getInstallStep().dependOn(impeller_pkg.installRuntime(.{
    .compile_step = exe,
    .dependency = impeller_dep,
    .install_dir = .lib,
}));
```

macOS:

```zig
impeller_pkg.linkRuntime(exe, impeller_dep);
exe.root_module.addRPathSpecial("@executable_path/../lib");

b.getInstallStep().dependOn(impeller_pkg.installRuntime(.{
    .compile_step = exe,
    .dependency = impeller_dep,
    .install_dir = .lib,
}));
```

### Install to a custom directory

Linux:

```zig
impeller_pkg.linkRuntime(exe, impeller_dep);
exe.root_module.addRPathSpecial("$ORIGIN/../runtime");

b.getInstallStep().dependOn(impeller_pkg.installRuntime(.{
    .compile_step = exe,
    .dependency = impeller_dep,
    .install_dir = .{ .custom = "runtime" },
}));
```

macOS:

```zig
impeller_pkg.linkRuntime(exe, impeller_dep);
exe.root_module.addRPathSpecial("@executable_path/../runtime");

b.getInstallStep().dependOn(impeller_pkg.installRuntime(.{
    .compile_step = exe,
    .dependency = impeller_dep,
    .install_dir = .{ .custom = "runtime" },
}));
```

## Platform notes

| Platform | Link input | Runtime file |
| --- | --- | --- |
| Linux | `libimpeller.so` | `libimpeller.so` |
| macOS | `libimpeller.dylib` | `libimpeller.dylib` |
| Windows | `impeller.dll.lib` | `impeller.dll` |

Windows uses the import library for linking and the DLL at runtime.

On Windows, prefer `.install_dir = .bin`. Custom DLL directories require a launcher that updates `PATH`, or application code that configures DLL search paths.

For macOS app bundles, let the application packaging layer decide the bundle layout.

On Linux, prefer the X11 windowing backend; Impeller's Vulkan surface integration currently has poor Wayland support.
