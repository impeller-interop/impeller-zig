const std = @import("std");
const impeller_pkg = @import("impeller_zig");

const Example = struct {
    step: []const u8,
    exe_name: []const u8,
    exe: *std.Build.Step.Compile,
};

pub fn build(b: *std.Build) void {
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

    const planet_exe = addShader(
        b,
        target,
        optimize,
        strip,
        os_tag,
        "impeller-planet",
        "planet",
        sdl3_mod,
        impeller_mod,
    );

    const liquid_glass_exe = addShader(
        b,
        target,
        optimize,
        strip,
        os_tag,
        "impeller-liquid-glass",
        "liquid_glass",
        sdl3_mod,
        impeller_mod,
    );

    const examples = [_]Example{
        .{ .step = "planet", .exe_name = "impeller-planet", .exe = planet_exe },
        .{ .step = "liquid-glass", .exe_name = "impeller-liquid-glass", .exe = liquid_glass_exe },
    };

    const runtime_install = impeller_pkg.installRuntime(.{
        .compile_step = examples[0].exe,
        .dependency = impeller_dep,
    });
    b.getInstallStep().dependOn(runtime_install);

    for (examples) |example| {
        const install = b.addInstallArtifact(example.exe, .{});
        if (std.mem.eql(u8, example.step, "planet")) {
            b.getInstallStep().dependOn(&install.step);
        }

        const build_step = b.step(example.step, b.fmt("Build the {s} example", .{example.step}));
        build_step.dependOn(&install.step);
        build_step.dependOn(runtime_install);

        const run_cmd = b.addRunFile(b.path(b.fmt("zig-out/bin/{s}{s}", .{
            example.exe_name,
            exe_suffix,
        })));
        run_cmd.step.dependOn(&install.step);
        run_cmd.step.dependOn(runtime_install);

        const run_step = b.step(b.fmt("run-{s}", .{example.step}), b.fmt("Run the {s} example", .{example.step}));
        run_step.dependOn(&run_cmd.step);
    }
}

fn addShader(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    strip: bool,
    os_tag: std.Target.Os.Tag,
    exe_name: []const u8,
    shader_name: []const u8,
    sdl3_mod: *std.Build.Module,
    impeller_mod: *std.Build.Module,
) *std.Build.Step.Compile {
    const options = b.addOptions();
    options.addOption([]const u8, "shader", shader_name);

    const draw_mod = b.createModule(.{
        .root_source_file = b.path("src/draw.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "impeller", .module = impeller_mod },
            .{ .name = "sdl3", .module = sdl3_mod },
            .{ .name = "build_options", .module = options.createModule() },
        },
    });

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .imports = &.{
            .{ .name = "draw", .module = draw_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_module = root_mod,
        .use_llvm = if (os_tag == .macos) null else true,
        .use_lld = if (os_tag == .macos) null else true,
    });
    exe.each_lib_rpath = false;

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
