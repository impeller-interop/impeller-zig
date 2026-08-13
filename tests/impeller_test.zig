const std = @import("std");
const impeller = @import("impeller");

test "public declarations compile" {
    std.testing.refAllDecls(impeller);
    std.testing.refAllDecls(impeller.geometry);
    std.testing.refAllDecls(impeller.color);
    std.testing.refAllDecls(impeller.context);
    std.testing.refAllDecls(impeller.mapping);
    std.testing.refAllDecls(impeller.texture);
    std.testing.refAllDecls(impeller.paint);
    std.testing.refAllDecls(impeller.path);
    std.testing.refAllDecls(impeller.display_list);
    std.testing.refAllDecls(impeller.surface);
    std.testing.refAllDecls(impeller.text);
}

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

test "matrix round trips" {
    const values = [_]f32{
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        2.0, 3.0, 4.0, 1.0,
    };
    const raw: impeller.c.ImpellerMatrix = .{ .m = values };

    const matrix = impeller.Matrix.fromC(raw);
    const converted = matrix.toC();

    try std.testing.expectEqual(values, matrix.m);
    try std.testing.expectEqual(values, converted.m);
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

test "enum fromC rejects unknown values" {
    const invalid: impeller.c.ImpellerColorSpace = 999;
    try std.testing.expectError(error.InvalidEnumTag, impeller.ColorSpace.fromC(invalid));
}

test "raw c namespace is available" {
    comptime {
        _ = impeller.c.ImpellerGetVersion;
        _ = impeller.c.ImpellerPaintNew;
    }
}

test "sentinel string APIs" {
    comptime {
        const set_font_family = @typeInfo(@TypeOf(impeller.ParagraphStyle.setFontFamily)).@"fn";
        const set_locale = @typeInfo(@TypeOf(impeller.ParagraphStyle.setLocale)).@"fn";
        const set_ellipsis = @typeInfo(@TypeOf(impeller.ParagraphStyle.setEllipsis)).@"fn";
        const register_font = @typeInfo(@TypeOf(impeller.TypographyContext.registerFontBorrowed)).@"fn";

        std.debug.assert(set_font_family.params[1].type.? == [:0]const u8);
        std.debug.assert(set_locale.params[1].type.? == [:0]const u8);
        std.debug.assert(set_ellipsis.params[1].type.? == ?[:0]const u8);
        std.debug.assert(register_font.params[2].type.? == ?[:0]const u8);
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

test "owned mapping copy" {
    var source = [_]u8{ 'i', 'm', 'p', 'e', 'l', 'l', 'e', 'r' };
    var owned = try impeller.OwnedMapping.copy(std.testing.allocator, source[0..]);
    defer owned.deinit();

    source[0] = 'x';

    const copied_len: usize = @intCast(owned.mapping.value.length);
    const copied_bytes = owned.mapping.value.data[0..copied_len];

    try std.testing.expectEqualStrings("impeller", copied_bytes);
    try std.testing.expect(@intFromPtr(owned.mapping.value.data) != @intFromPtr(source[0..].ptr));
    try std.testing.expect(owned.mapping.value.on_release != null);
    try std.testing.expect(owned.mapping.release_user_data != null);
}

test "owned mapping release" {
    var owned = try impeller.OwnedMapping.copy(std.testing.allocator, "impeller");
    const mapping = owned.mapping;

    owned.releaseToImpeller();
    owned.deinit();

    mapping.value.on_release.?(mapping.release_user_data);
}

test "paint clone" {
    var paint = try impeller.Paint.init();
    defer paint.deinit();

    var cloned = paint.clone();
    defer cloned.deinit();

    try std.testing.expectEqual(paint.raw(), cloned.raw());
}

test "paint child refs" {
    var paint = try impeller.Paint.init();
    defer paint.deinit();

    const colors = [_]impeller.Color{
        impeller.srgb(1.0, 0.0, 0.0, 1.0),
        impeller.srgb(0.0, 0.0, 1.0, 1.0),
    };
    const stops = [_]f32{ 0.0, 1.0 };

    var color_source = try impeller.ColorSource.initLinearGradient(
        impeller.point(0.0, 0.0),
        impeller.point(10.0, 10.0),
        colors[0..],
        stops[0..],
        impeller.tile_modes.clamp,
        null,
    );
    paint.setColorSource(color_source);
    color_source.deinit();

    var color_filter = try impeller.ColorFilter.initBlend(
        impeller.srgb(1.0, 1.0, 1.0, 1.0),
        impeller.blend_modes.source_over,
    );
    paint.setColorFilter(color_filter);
    color_filter.deinit();

    var mask_filter = try impeller.MaskFilter.initBlur(impeller.blur_styles.normal, 2.0);
    paint.setMaskFilter(mask_filter);
    mask_filter.deinit();

    var image_filter = try impeller.ImageFilter.initBlur(2.0, 2.0, impeller.tile_modes.clamp);
    paint.setImageFilter(image_filter);
    image_filter.deinit();

    var builder = try impeller.DisplayListBuilder.init(null);
    defer builder.deinit();
    builder.drawRect(impeller.rect(0.0, 0.0, 8.0, 8.0), paint);

    var display_list = try builder.build();
    defer display_list.deinit();
}

test "draw child refs" {
    var paint = try impeller.Paint.init();
    var path_builder = try impeller.PathBuilder.init();
    defer path_builder.deinit();

    path_builder.addRect(impeller.rect(0.0, 0.0, 4.0, 4.0));
    var path = try path_builder.takePath(impeller.fill_types.non_zero);

    var builder = try impeller.DisplayListBuilder.init(null);
    defer builder.deinit();
    builder.drawPath(path, paint);

    path.deinit();
    paint.deinit();

    var display_list = try builder.build();
    defer display_list.deinit();

    var parent_builder = try impeller.DisplayListBuilder.init(null);
    defer parent_builder.deinit();
    parent_builder.drawDisplayList(display_list, 1.0);

    display_list.deinit();

    var parent_list = try parent_builder.build();
    defer parent_list.deinit();
}

test "paragraph paint refs" {
    var foreground = try impeller.Paint.init();
    var background = try impeller.Paint.init();

    var style = try impeller.ParagraphStyle.init();
    defer style.deinit();

    style.setForeground(foreground);
    style.setBackground(background);

    foreground.deinit();
    background.deinit();
}
