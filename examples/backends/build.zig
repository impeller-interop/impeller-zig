const std = @import("std");
const impeller_pkg = @import("impeller_zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const strip = b.option(bool, "strip", "Strip debug symbols") orelse false;

    const os_tag = target.result.os.tag;
    const exe_suffix = if (os_tag == .windows) ".exe" else "";

    const impeller_dep = b.dependency("impeller_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const impeller_mod = impeller_dep.module("impeller");

    const sdl3_mod = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
    }).module("sdl3");

    const draw_mod = b.createModule(.{
        .root_source_file = b.path("src/draw.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "impeller", .module = impeller_mod },
        },
    });

    const sdl3_exe = addBackend(
        b,
        target,
        optimize,
        strip,
        os_tag,
        "impeller-sdl3",
        "src/backends/sdl3.zig",
        "sdl3",
        sdl3_mod,
        null,
        draw_mod,
        impeller_mod,
    );

    const runtime_install = impeller_pkg.installRuntime(.{
        .compile_step = sdl3_exe,
        .dependency = impeller_dep,
    });
    b.getInstallStep().dependOn(runtime_install);

    addSteps(b, sdl3_exe, "sdl3", "impeller-sdl3", exe_suffix, runtime_install, true);

    const glfw_dep = try b.dependencyLazy("glfw", .{
        .target = target,
        .optimize = optimize,
    });
    const glfw_lib = glfw_dep.artifact("glfw");
    const glfw_translate = b.addTranslateC(.{
        .root_source_file = glfw_dep.path("glfw/include/GLFW/glfw3.h"),
        .target = target,
        .optimize = optimize,
    });
    if (os_tag == .linux or os_tag == .windows) {
        glfw_translate.defineCMacro("GLFW_INCLUDE_VULKAN", null);
        glfw_translate.defineCMacro("GLFW_INCLUDE_NONE", null);
        glfw_translate.addIncludePath(glfw_lib.getEmittedIncludeTree());
    }

    const glfw_exe = addBackend(
        b,
        target,
        optimize,
        strip,
        os_tag,
        "impeller-glfw",
        "src/backends/glfw.zig",
        "glfw_c",
        glfw_translate.createModule(),
        glfw_lib,
        draw_mod,
        impeller_mod,
    );
    addSteps(b, glfw_exe, "glfw", "impeller-glfw", exe_suffix, runtime_install, false);

    const wio_dep = try b.dependencyLazy("wio", .{
        .target = target,
        .optimize = optimize,
        .enable_vulkan = os_tag != .macos,
        .enable_opengl = false,
        .unix_backends = "x11",
    });
    const wio_exe = addBackend(
        b,
        target,
        optimize,
        strip,
        os_tag,
        "impeller-wio",
        "src/backends/wio.zig",
        "wio",
        wio_dep.module("wio"),
        null,
        draw_mod,
        impeller_mod,
    );
    addSteps(b, wio_exe, "wio", "impeller-wio", exe_suffix, runtime_install, false);
}

fn addSteps(
    b: *std.Build,
    exe: *std.Build.Step.Compile,
    step_name: []const u8,
    exe_name: []const u8,
    exe_suffix: []const u8,
    runtime_install: *std.Build.Step,
    is_default: bool,
) void {
    const install = b.addInstallArtifact(exe, .{});
    if (is_default) b.getInstallStep().dependOn(&install.step);

    const build_step = b.step(step_name, b.fmt("Build the {s} example", .{step_name}));
    build_step.dependOn(&install.step);
    build_step.dependOn(runtime_install);

    const run_cmd = b.addRunFile(b.path(b.fmt("zig-out/bin/{s}{s}", .{ exe_name, exe_suffix })));
    run_cmd.step.dependOn(&install.step);
    run_cmd.step.dependOn(runtime_install);

    const run_step = b.step(b.fmt("run-{s}", .{step_name}), b.fmt("Run the {s} example", .{step_name}));
    run_step.dependOn(&run_cmd.step);
}

fn addBackend(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    strip: bool,
    os_tag: std.Target.Os.Tag,
    exe_name: []const u8,
    source: []const u8,
    window_import: []const u8,
    window_mod: *std.Build.Module,
    glfw_lib: ?*std.Build.Step.Compile,
    draw_mod: *std.Build.Module,
    impeller_mod: *std.Build.Module,
) *std.Build.Step.Compile {
    const backend_mod = b.createModule(.{
        .root_source_file = b.path(source),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "impeller", .module = impeller_mod },
            .{ .name = "draw", .module = draw_mod },
            .{ .name = window_import, .module = window_mod },
        },
    });

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .imports = &.{
            .{ .name = "backend", .module = backend_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_module = root_mod,
        .use_llvm = if (os_tag == .macos) null else true,
        .use_lld = if (os_tag == .macos) null else true,
    });
    exe.each_lib_rpath = false;

    if (glfw_lib) |lib| exe.root_module.linkLibrary(lib);

    switch (os_tag) {
        .windows => {},
        .linux => {
            exe.root_module.linkSystemLibrary("dl", .{});
            exe.root_module.linkSystemLibrary("pthread", .{});
            exe.root_module.linkSystemLibrary("m", .{});
            exe.root_module.addRPathSpecial("$ORIGIN");
        },
        .macos => {
            exe.root_module.addCSourceFile(.{
                .file = b.path("src/metal.m"),
                .flags = &.{ "-fobjc-arc", "-Wno-deprecated-declarations", "-Wno-unguarded-availability-new" },
                .language = .objective_c,
            });
            exe.root_module.linkFramework("AppKit", .{});
            exe.root_module.linkFramework("Metal", .{});
            exe.root_module.linkFramework("QuartzCore", .{});
            exe.root_module.addRPathSpecial("@executable_path");
        },
        else => @panic("unsupported target"),
    }

    return exe;
}
