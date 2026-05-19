const std = @import("std");

const BuildOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

const ImpellerSdk = struct {
    header: std.Build.LazyPath,
    include_path: std.Build.LazyPath,
    lib_path: std.Build.LazyPath,
    library: std.Build.LazyPath,
    import_library: ?std.Build.LazyPath,
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
    addArtifact(b, mod);
    addTests(b, options, sdk, mod);
}

fn getSdk(b: *std.Build, options: BuildOptions) ImpellerSdk {
    const dep = b.dependency("impeller_sdk", .{
        .target = options.target,
        .optimize = options.optimize,
    });

    return .{
        .header = dep.namedLazyPath("impeller_header"),
        .include_path = dep.namedLazyPath("impeller_include"),
        .lib_path = dep.namedLazyPath("impeller_lib_dir"),
        .library = dep.namedLazyPath("impeller_library"),
        .import_library = if (options.target.result.os.tag == .windows)
            dep.namedLazyPath("impeller_import_library")
        else
            null,
    };
}

fn exposeSdk(b: *std.Build, sdk: ImpellerSdk) void {
    b.addNamedLazyPath("impeller_header", sdk.header);
    b.addNamedLazyPath("impeller_include", sdk.include_path);
    b.addNamedLazyPath("impeller_lib_dir", sdk.lib_path);
    b.addNamedLazyPath("impeller_library", sdk.library);
    if (sdk.import_library) |import_library| {
        b.addNamedLazyPath("impeller_import_library", import_library);
    }
}

fn addArtifact(b: *std.Build, mod: *std.Build.Module) void {
    const lib = b.addLibrary(.{
        .name = "impeller",
        .root_module = mod,
    });
    b.installArtifact(lib);
}

fn addModule(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk) *std.Build.Module {
    const impeller_c = addRawModule(b, options, sdk);
    const mod = b.addModule("impeller", .{
        .root_source_file = b.path("src/impeller.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "impeller_c", .module = impeller_c },
        },
    });

    linkSdk(mod, sdk, options.target.result);
    return mod;
}

fn addTests(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk, mod: *std.Build.Module) void {
    const test_mod = b.createModule(.{
        .root_source_file = b.path("tests/impeller_test.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "impeller", .module = mod },
        },
    });
    linkSdk(test_mod, sdk, options.target.result);

    const tests = b.addTest(.{
        .root_module = test_mod,
        .use_llvm = true,
        .use_lld = true,
    });

    const run_tests = b.addRunArtifact(tests);
    addRuntimePath(run_tests, sdk);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}

fn addRawModule(b: *std.Build, options: BuildOptions, sdk: ImpellerSdk) *std.Build.Module {
    const translate = b.addTranslateC(.{
        .root_source_file = sdk.header,
        .target = options.target,
        .optimize = options.optimize,
    });
    translate.addIncludePath(sdk.include_path);
    return translate.createModule();
}

fn linkSdk(mod: *std.Build.Module, sdk: ImpellerSdk, target: std.Target) void {
    mod.addIncludePath(sdk.include_path);
    mod.addRPath(sdk.lib_path);
    if (target.os.tag == .windows) {
        mod.addObjectFile(sdk.import_library.?);
    } else {
        mod.addObjectFile(sdk.library);
    }
}

fn addRuntimePath(run: *std.Build.Step.Run, sdk: ImpellerSdk) void {
    const lib_path = sdk.lib_path.getPath2(run.step.owner, &run.step);
    run.setEnvironmentVariable("DYLD_LIBRARY_PATH", lib_path);
    run.setEnvironmentVariable("LD_LIBRARY_PATH", lib_path);
    run.addPathDir(lib_path);
}
