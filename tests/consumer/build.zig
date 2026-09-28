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

    const native = b.addExecutable(.{
        .name = "native",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });
    native.root_module.addCSourceFile(.{ .file = b.path("src/native.c") });
    native.root_module.link_libc = true;
    native.root_module.addRPathSpecial(runtime_search_path);

    impeller_pkg.linkRuntime(app, dep);
    impeller_pkg.linkRuntime(native, dep);

    b.getInstallStep().dependOn(impeller_pkg.installRuntime(.{
        .compile_step = app,
        .dependency = dep,
    }));
    b.getInstallStep().dependOn(impeller_pkg.installRuntime(.{
        .compile_step = native,
        .dependency = dep,
        .install_dir = .lib,
    }));
    b.getInstallStep().dependOn(impeller_pkg.installRuntime(.{
        .compile_step = app,
        .dependency = dep,
        .install_dir = .{ .custom = "runtime" },
    }));

    b.installArtifact(app);
    b.installArtifact(native);

    b.getInstallStep().dependOn(&b.addInstallDirectory(.{
        .source_dir = dep.namedLazyPath("impeller_include"),
        .install_dir = .prefix,
        .install_subdir = "include",
    }).step);
}
