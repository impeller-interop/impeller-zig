const std = @import("std");
const impeller = @import("impeller");

test "srgb fields" {
    const color = impeller.srgb(0.1, 0.2, 0.3, 0.4);

    try std.testing.expectEqual(@as(f32, 0.1), color.red);
    try std.testing.expectEqual(@as(f32, 0.2), color.green);
    try std.testing.expectEqual(@as(f32, 0.3), color.blue);
    try std.testing.expectEqual(@as(f32, 0.4), color.alpha);
    try std.testing.expectEqual(@as(impeller.ColorSpace, impeller.color_spaces.srgb), color.color_space);
}

test "rect fields" {
    const value = impeller.rect(1.0, 2.0, 3.0, 4.0);

    try std.testing.expectEqual(@as(f32, 1.0), value.x);
    try std.testing.expectEqual(@as(f32, 2.0), value.y);
    try std.testing.expectEqual(@as(f32, 3.0), value.width);
    try std.testing.expectEqual(@as(f32, 4.0), value.height);
}

test "point fields" {
    const value = impeller.point(5.0, 6.0);

    try std.testing.expectEqual(@as(f32, 5.0), value.x);
    try std.testing.expectEqual(@as(f32, 6.0), value.y);
}

test "radii uniform" {
    const value = impeller.uniformRadii(7.0);
    const corner = impeller.point(7.0, 7.0);

    try std.testing.expectEqual(corner, value.top_left);
    try std.testing.expectEqual(corner, value.bottom_left);
    try std.testing.expectEqual(corner, value.top_right);
    try std.testing.expectEqual(corner, value.bottom_right);
}

test "color matrix" {
    const values = [_]f32{
        1.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
    };

    const value = impeller.colorMatrix(values);

    try std.testing.expectEqual(values, value.m);
}

test "pixel size" {
    const value = impeller.pixelSize(8, 9);

    try std.testing.expectEqual(@as(i32, 8), value.width);
    try std.testing.expectEqual(@as(i32, 9), value.height);
}

test "texture descriptor" {
    const size = impeller.pixelSize(10, 11);
    const value = impeller.textureDescriptor(impeller.pixel_formats.rgba8888, size, 12);

    try std.testing.expectEqual(@as(impeller.PixelFormat, impeller.pixel_formats.rgba8888), value.pixel_format);
    try std.testing.expectEqual(size, value.size);
    try std.testing.expectEqual(@as(u32, 12), value.mip_count);
}

test "version helpers" {
    const value = impeller.makeVersion(1, 2, 3, 4);

    try std.testing.expectEqual(@as(u32, 1), impeller.versionVariant(value));
    try std.testing.expectEqual(@as(u32, 2), impeller.versionMajor(value));
    try std.testing.expectEqual(@as(u32, 3), impeller.versionMinor(value));
    try std.testing.expectEqual(@as(u32, 4), impeller.versionPatch(value));
    try std.testing.expectEqual(impeller.version, impeller.makeVersion(
        impeller.version_variant,
        impeller.version_major,
        impeller.version_minor,
        impeller.version_patch,
    ));
}

test "callback aliases" {
    comptime {
        const callback: type = impeller.Callback;
        const proc_address_callback: type = impeller.ProcAddressCallback;
        const vulkan_proc_address_callback: type = impeller.VulkanProcAddressCallback;
        _ = callback;
        _ = proc_address_callback;
        _ = vulkan_proc_address_callback;
    }
}

test "mapping borrows bytes" {
    const bytes = "impeller";
    const mapping = impeller.Mapping.borrowed(bytes);

    try std.testing.expectEqual(bytes.ptr, mapping.value.data);
    try std.testing.expectEqual(@as(u64, bytes.len), mapping.value.length);
    try std.testing.expectEqual(@as(@TypeOf(mapping.value.on_release), null), mapping.value.on_release);
    try std.testing.expectEqual(@as(?*anyopaque, null), mapping.release_user_data);
}

test "mapping release state" {
    const Release = struct {
        fn callback(_: ?*anyopaque) callconv(.c) void {}
    };
    const bytes = "impeller";
    var user_data: u8 = 0;
    const mapping = impeller.Mapping.withRelease(bytes, Release.callback, &user_data);

    try std.testing.expectEqual(bytes.ptr, mapping.value.data);
    try std.testing.expectEqual(@as(impeller.Callback, Release.callback), mapping.value.on_release.?);
    try std.testing.expectEqual(@as(?*anyopaque, &user_data), mapping.release_user_data);
}

test "paint clone" {
    var paint = try impeller.Paint.init();
    defer paint.deinit();

    var cloned = paint.clone();
    defer cloned.deinit();

    try std.testing.expectEqual(paint.raw(), cloned.raw());
}
