const std = @import("std");

const BuildOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

const SdkPaths = struct {
    dependency: *std.Build.Dependency,
    header: std.Build.LazyPath,
    include_path: std.Build.LazyPath,
    lib_path: std.Build.LazyPath,
    runtime_library: std.Build.LazyPath,
    windows_import_library: ?std.Build.LazyPath,

    fn fromDependency(dep: *std.Build.Dependency, target: std.Target) SdkPaths {
        return .{
            .dependency = dep,
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
    b.addNamedLazyPath("impeller_library", sdk.runtime_library);

    const mod = addModule(b, options, sdk);

    addTests(b, options, sdk, mod);
    addSmoke(b, options, sdk, mod);
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
    const runtime_library = options.dependency.namedLazyPath("impeller_library");

    const runtime_file_name = switch (target.os.tag) {
        .windows => "impeller.dll",
        .macos => "libimpeller.dylib",
        .linux => "libimpeller.so",
        else => @panic("unsupported Impeller SDK target"),
    };

    return &b.addInstallFileWithDir(
        runtime_library,
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

fn addModule(b: *std.Build, options: BuildOptions, sdk: SdkPaths) *std.Build.Module {
    const impeller_c = addCModule(b, options, sdk);
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

fn addCModule(b: *std.Build, options: BuildOptions, sdk: SdkPaths) *std.Build.Module {
    const translate_c = b.addTranslateC(.{
        .root_source_file = sdk.header,
        .target = options.target,
        .optimize = options.optimize,
    });
    translate_c.addIncludePath(sdk.include_path);

    return translate_c.createModule();
}

fn addTests(b: *std.Build, options: BuildOptions, sdk: SdkPaths, mod: *std.Build.Module) void {
    const test_filter = b.option([]const u8, "test-filter", "Run only tests whose name contains one of these comma separated substrings");

    var filters: []const []const u8 = &.{};
    if (test_filter) |spec| {
        var list: std.ArrayList([]const u8) = .empty;
        var parts = std.mem.splitScalar(u8, spec, ',');
        while (parts.next()) |part| list.append(b.allocator, part) catch @panic("out of memory");
        filters = list.toOwnedSlice(b.allocator) catch @panic("out of memory");
    }

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
        .filters = filters,
    });

    const run_tests = b.addRunArtifact(tests);

    if (options.target.result.os.tag == .windows) {
        run_tests.setCwd(sdk.lib_path);
    } else {
        tests.root_module.addRPath(sdk.lib_path);
    }

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const install_tests = b.addInstallArtifact(tests, .{});
    const test_exe_step = b.step("test-exe", "Install the unit test binary");
    test_exe_step.dependOn(&install_tests.step);
}

fn addSmoke(b: *std.Build, options: BuildOptions, sdk: SdkPaths, mod: *std.Build.Module) void {
    const smoke_mod = b.createModule(.{
        .root_source_file = b.path("tests/smoke.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "impeller", .module = mod },
        },
    });

    const smoke = b.addExecutable(.{
        .name = "smoke",
        .root_module = smoke_mod,
    });
    smoke.root_module.addRPathSpecial(switch (options.target.result.os.tag) {
        .macos => "@executable_path",
        else => "$ORIGIN",
    });

    const install_runtime = installRuntime(.{
        .compile_step = smoke,
        .dependency = sdk.dependency,
    });
    const install_smoke = b.addInstallArtifact(smoke, .{});
    install_smoke.step.dependOn(install_runtime);

    const smoke_step = b.step("smoke", "Build the smoke test");
    smoke_step.dependOn(&install_smoke.step);

    const smoke_path = if (options.target.result.os.tag == .windows)
        "zig-out/bin/smoke.exe"
    else
        "zig-out/bin/smoke";
    const run_smoke = b.addRunFile(b.path(smoke_path));
    run_smoke.step.dependOn(&install_smoke.step);

    const run_smoke_step = b.step("run-smoke", "Run the smoke test");
    run_smoke_step.dependOn(&run_smoke.step);
}

fn linkSdk(mod: *std.Build.Module, sdk: SdkPaths, target: std.Target) void {
    mod.addIncludePath(sdk.include_path);
    if (target.os.tag == .windows) {
        mod.addObjectFile(sdk.windows_import_library.?);
    } else {
        mod.addObjectFile(sdk.runtime_library);
    }
}
