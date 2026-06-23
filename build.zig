const std = @import("std");

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

fn getSdk(b: *std.Build, options: BuildOptions) SdkPaths {
    const dep = b.dependency("impeller_sdk", .{
        .target = options.target,
    });

    return .{
        .header = dep.namedLazyPath("impeller_header"),
        .include_path = dep.namedLazyPath("impeller_include"),
        .lib_path = dep.namedLazyPath("impeller_lib_dir"),
        .runtime_library = dep.namedLazyPath("impeller_library"),
        .windows_import_library = if (options.target.result.os.tag == .windows)
            dep.namedLazyPath("impeller_import_library")
        else
            null,
    };
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
    const mod = b.addModule("impeller", .{
        .root_source_file = b.path("src/impeller.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "impeller_c", .module = impeller_c },
        },
    });
    return mod;
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
    addRuntimePath(run_tests, sdk);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}

fn addRawModule(b: *std.Build, options: BuildOptions, sdk: SdkPaths) *std.Build.Module {
    const translate = b.addTranslateC(.{
        .root_source_file = sdk.header,
        .target = options.target,
        .optimize = options.optimize,
    });
    translate.addIncludePath(sdk.include_path);
    return translate.createModule();
}

fn linkSdk(mod: *std.Build.Module, sdk: SdkPaths, target: std.Target) void {
    mod.addIncludePath(sdk.include_path);
    if (target.os.tag == .windows) {
        mod.addObjectFile(sdk.windows_import_library.?);
    } else {
        mod.addObjectFile(sdk.runtime_library);
    }
}

/// Link the Impeller runtime to a final compile step.
pub fn linkRuntime(compile_step: *std.Build.Step.Compile, dep: *std.Build.Dependency) void {
    const sdk = sdkFromDependency(dep, compile_step.rootModuleTarget());
    linkSdk(compile_step.root_module, sdk, compile_step.rootModuleTarget());
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
    const sdk = sdkFromDependency(options.dependency, target);
    const install_step = b.step("install-impeller-runtime", "Install Impeller runtime library");

    switch (target.os.tag) {
        .windows => install_step.dependOn(&b.addInstallFileWithDir(
            sdk.runtime_library,
            options.install_dir,
            "impeller.dll",
        ).step),
        .macos => install_step.dependOn(&b.addInstallFileWithDir(
            sdk.runtime_library,
            options.install_dir,
            "libimpeller.dylib",
        ).step),
        .linux => {
            install_step.dependOn(&b.addInstallFileWithDir(
                sdk.runtime_library,
                options.install_dir,
                "libimpeller.so",
            ).step);
        },
        else => @panic("unsupported Impeller SDK target"),
    }

    return install_step;
}

fn sdkFromDependency(dep: *std.Build.Dependency, target: std.Target) SdkPaths {
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

fn addRuntimePath(run: *std.Build.Step.Run, sdk: SdkPaths) void {
    const lib_path = sdk.lib_path.getPath2(run.step.owner, &run.step);
    run.setEnvironmentVariable("DYLD_LIBRARY_PATH", lib_path);
    run.setEnvironmentVariable("LD_LIBRARY_PATH", lib_path);
    run.addPathDir(lib_path);
}
