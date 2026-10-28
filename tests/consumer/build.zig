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

    b.getInstallStep().dependOn(impeller_pkg.installRuntime(.{
        .compile_step = app,
        .dependency = dep,
    }));
    b.getInstallStep().dependOn(impeller_pkg.installRuntime(.{
        .compile_step = app,
        .dependency = dep,
        .install_dir = .lib,
    }));
    b.getInstallStep().dependOn(impeller_pkg.installRuntime(.{
        .compile_step = app,
        .dependency = dep,
        .install_dir = .{ .custom = "runtime" },
    }));

    b.installArtifact(app);
}
