const std = @import("std");
const impeller_pkg = @import("impeller_zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep = b.dependency("impeller_zig", .{
        .target = target,
        .optimize = optimize,
    });

    // dyld does not expand the ELF `$ORIGIN` token.
    const runtime_search_path = switch (target.result.os.tag) {
        .macos => "@executable_path",
        else => "$ORIGIN",
    };

    const app = b.addExecutable(.{
        .name = "app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "impeller", .module = dep.module("impeller") },
            },
        }),
    });
    app.root_module.addRPathSpecial(runtime_search_path);
    const install_step = b.getInstallStep();

    const install_runtime = impeller_pkg.installRuntime(.{
        .compile_step = app,
        .dependency = dep,
    });

    install_step.dependOn(install_runtime);

    install_step.dependOn(impeller_pkg.installRuntime(.{
        .compile_step = app,
        .dependency = dep,
        .install_dir = .lib,
    }));

    install_step.dependOn(impeller_pkg.installRuntime(.{
        .compile_step = app,
        .dependency = dep,
        .install_dir = .{ .custom = "runtime" },
    }));

    const install_app = b.addInstallArtifact(app, .{});
    install_step.dependOn(&install_app.step);

    const installed_app_path = switch (target.result.os.tag) {
        .windows => "zig-out/bin/app.exe",
        else => "zig-out/bin/app",
    };
    const run_app = b.addRunFile(b.path(installed_app_path));
    run_app.step.dependOn(&install_app.step);
    run_app.step.dependOn(install_runtime);

    const run_step = b.step("run", "Run consumer");
    run_step.dependOn(&run_app.step);
}
