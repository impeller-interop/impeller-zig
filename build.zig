const std = @import("std");
const Translator = @import("translate_c").Translator;

const BuildOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

const SdkPaths = struct {
    header: std.Build.LazyPath,
    include_path: std.Build.LazyPath,
    lib_path: std.Build.LazyPath,
    runtime_library: std.Build.LazyPath,
    windows_import_library: ?std.Build.LazyPath,

    fn fromDependency(dep: *std.Build.Dependency, target: std.Target) SdkPaths {
        return .{
            .header = dep.namedLazyPath("impeller_header"),
            .include_path = dep.namedLazyPath("impeller_include"),
            .lib_path = dep.namedLazyPath("impeller_lib_dir"),
            .runtime_library = dep.namedLazyPath("impeller_library"),
            .windows_import_library = if (target.os.tag == .windows)
                dep.namedLazyPath("impeller_import_library")
            else
                null,
        };
    }
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const options: BuildOptions = .{
        .target = target,
        .optimize = optimize,
    };

    const sdk = getSdk(b, options);
    exposeSdk(b, sdk);

    const mod = addModule(b, options, sdk);
    addTests(b, options, sdk, mod);
}

/// Link the Impeller runtime to a final compile step.
pub fn linkRuntime(compile_step: *std.Build.Step.Compile, dep: *std.Build.Dependency) void {
    const target = compile_step.rootModuleTarget();
    const sdk = SdkPaths.fromDependency(dep, target);
    linkSdk(compile_step.root_module, sdk, target);
}

/// Install the Impeller runtime to a selected install directory.
pub fn installRuntime(options: struct {
    compile_step: *std.Build.Step.Compile,
    dependency: *std.Build.Dependency,
    install_dir: std.Build.InstallDir = .bin,
}) *std.Build.Step {
    const compile_step = options.compile_step;
    const b = compile_step.step.owner;
    const target = compile_step.rootModuleTarget();
    const sdk = SdkPaths.fromDependency(options.dependency, target);

    const runtime_file_name = switch (target.os.tag) {
        .windows => "impeller.dll",
        .macos => "libimpeller.dylib",
        .linux => "libimpeller.so",
        else => @panic("unsupported Impeller SDK target"),
    };

    return &b.addInstallFileWithDir(
        sdk.runtime_library,
        options.install_dir,
        runtime_file_name,
    ).step;
}

fn getSdk(b: *std.Build, options: BuildOptions) SdkPaths {
    const dep = b.dependency("impeller_sdk", .{
        .target = options.target,
    });

    return .fromDependency(dep, options.target.result);
}

fn exposeSdk(b: *std.Build, sdk: SdkPaths) void {
    b.addNamedLazyPath("impeller_header", sdk.header);
    b.addNamedLazyPath("impeller_include", sdk.include_path);
    b.addNamedLazyPath("impeller_lib_dir", sdk.lib_path);
    b.addNamedLazyPath("impeller_library", sdk.runtime_library);
    if (sdk.windows_import_library) |import_library| {
        b.addNamedLazyPath("impeller_import_library", import_library);
    }
}

fn addModule(b: *std.Build, options: BuildOptions, sdk: SdkPaths) *std.Build.Module {
    const impeller_c = addRawModule(b, options, sdk);
    return b.addModule("impeller", .{
        .root_source_file = b.path("src/impeller.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "impeller_c", .module = impeller_c },
        },
    });
}

fn addRawModule(b: *std.Build, options: BuildOptions, sdk: SdkPaths) *std.Build.Module {
    const translate_c = b.dependency("translate_c", .{});

    const t: Translator = .init(translate_c, .{
        .name = "impeller_c",
        .c_source_file = sdk.header,
        .target = options.target,
        .optimize = options.optimize,
        .warnings = .show,
    });
    t.addIncludePath(sdk.include_path);

    return t.mod;
}

fn addTests(b: *std.Build, options: BuildOptions, sdk: SdkPaths, mod: *std.Build.Module) void {
    const test_mod = b.createModule(.{
        .root_source_file = b.path("tests/impeller_test.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "impeller", .module = mod },
        },
    });

    const tests = b.addTest(.{
        .root_module = test_mod,
    });
    linkSdk(tests.root_module, sdk, options.target.result);

    const run_tests = b.addRunArtifact(tests);
    addRuntimePath(run_tests, sdk, options.target.result);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}

fn linkSdk(mod: *std.Build.Module, sdk: SdkPaths, target: std.Target) void {
    mod.addIncludePath(sdk.include_path);
    if (target.os.tag == .windows) {
        mod.addObjectFile(sdk.windows_import_library.?);
    } else {
        mod.addObjectFile(sdk.runtime_library);
    }
}

fn addRuntimePath(run: *std.Build.Step.Run, sdk: SdkPaths, target: std.Target) void {
    const b = run.step.owner;
    const lib_path = lazyPathString(sdk.lib_path);

    switch (target.os.tag) {
        .macos => run.setEnvironmentVariable("DYLD_LIBRARY_PATH", lib_path),
        .windows => {
            const old_path = run.getEnvMap().get("PATH");
            if (old_path) |prev_path| {
                run.setEnvironmentVariable("PATH", b.fmt("{s}{c}{s}", .{ prev_path, std.fs.path.delimiter, lib_path }));
            } else {
                run.setEnvironmentVariable("PATH", lib_path);
            }
        },
        .linux => run.setEnvironmentVariable("LD_LIBRARY_PATH", lib_path),
        else => @panic("unsupported Impeller SDK target"),
    }
}

fn lazyPathString(lazy_path: std.Build.LazyPath) []const u8 {
    return switch (lazy_path) {
        .cwd_relative => |path| path,
        .src_path => |src_path| src_path.owner.root.joinString(
            src_path.owner.allocator,
            src_path.sub_path,
        ) catch @panic("OOM"),
        .dependency => |dep| dep.dependency.builder.root.joinString(
            dep.dependency.builder.allocator,
            dep.sub_path,
        ) catch @panic("OOM"),
        .generated, .relative => @panic("expected a file system path"),
    };
}
