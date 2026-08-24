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

test "paint setters" {
    var paint = try impeller.Paint.init();
    defer paint.deinit();

    paint.setColor(impeller.srgb(0.2, 0.3, 0.4, 0.5));
    paint.setBlendMode(impeller.blend_modes.multiply);
    paint.setDrawStyle(impeller.draw_styles.stroke_and_fill);
    paint.setStrokeCap(impeller.stroke_caps.round);
    paint.setStrokeJoin(impeller.stroke_joins.bevel);
    paint.setStrokeWidth(3.5);
    paint.setStrokeMiter(4.5);
    try std.testing.expect(paint.raw() != null);
}

test "color sources" {
    const colors = [_]impeller.Color{
        impeller.srgb(1.0, 0.0, 0.0, 1.0),
        impeller.srgb(0.0, 0.0, 1.0, 1.0),
    };
    const stops = [_]f32{ 0.0, 1.0 };
    const transform = impeller.Matrix{ .m = [_]f32{
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    } };

    var linear = try impeller.ColorSource.initLinearGradient(
        impeller.point(0.0, 0.0),
        impeller.point(10.0, 10.0),
        colors[0..],
        stops[0..],
        impeller.tile_modes.clamp,
        transform,
    );
    defer linear.deinit();

    var radial = try impeller.ColorSource.initRadialGradient(
        impeller.point(5.0, 5.0),
        5.0,
        colors[0..],
        stops[0..],
        impeller.tile_modes.repeat,
        null,
    );
    defer radial.deinit();

    var conical = try impeller.ColorSource.initConicalGradient(
        impeller.point(0.0, 0.0),
        1.0,
        impeller.point(10.0, 10.0),
        8.0,
        colors[0..],
        stops[0..],
        impeller.tile_modes.mirror,
        null,
    );
    defer conical.deinit();

    var sweep = try impeller.ColorSource.initSweepGradient(
        impeller.point(5.0, 5.0),
        0.0,
        360.0,
        colors[0..],
        stops[0..],
        impeller.tile_modes.decal,
        transform,
    );
    defer sweep.deinit();

    try std.testing.expect(linear.raw() != null);
    try std.testing.expect(radial.raw() != null);
    try std.testing.expect(conical.raw() != null);
    try std.testing.expect(sweep.raw() != null);
}

test "filters" {
    const matrix = impeller.Matrix{ .m = [_]f32{
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    } };

    var blur = try impeller.ImageFilter.initBlur(2.0, 3.0, impeller.tile_modes.clamp);
    defer blur.deinit();
    var dilate = try impeller.ImageFilter.initDilate(1.0, 2.0);
    defer dilate.deinit();
    var erode = try impeller.ImageFilter.initErode(1.0, 2.0);
    defer erode.deinit();
    if (impeller.ImageFilter.initMatrix(matrix, impeller.texture_samplings.linear)) |matrix_filter| {
        var filter = matrix_filter;
        defer filter.deinit();
        try std.testing.expect(filter.raw() != null);
    } else |err| {
        try std.testing.expectEqual(error.CreateImageFilterFailed, err);
    }
    var composed = try impeller.ImageFilter.initCompose(dilate, erode);
    defer composed.deinit();

    var color_filter = try impeller.ColorFilter.initColorMatrix(impeller.colorMatrix([_]f32{1.0} ** 20));
    defer color_filter.deinit();
    var mask_filter = try impeller.MaskFilter.initBlur(impeller.blur_styles.outer, 2.0);
    defer mask_filter.deinit();

    try std.testing.expect(composed.raw() != null);
    try std.testing.expect(color_filter.raw() != null);
    try std.testing.expect(mask_filter.raw() != null);
}

test "path builder" {
    var builder = try impeller.PathBuilder.init();
    defer builder.deinit();

    builder.moveTo(impeller.point(0.0, 0.0));
    builder.lineTo(impeller.point(1.0, 1.0));
    builder.quadraticCurveTo(impeller.point(2.0, 0.0), impeller.point(3.0, 1.0));
    builder.cubicCurveTo(
        impeller.point(4.0, 0.0),
        impeller.point(5.0, 1.0),
        impeller.point(6.0, 0.0),
    );
    builder.addRect(impeller.rect(0.0, 0.0, 10.0, 10.0));
    builder.addArc(impeller.rect(0.0, 0.0, 10.0, 10.0), 0.0, 90.0);
    builder.addOval(impeller.rect(0.0, 0.0, 10.0, 10.0));
    builder.addRoundedRect(impeller.rect(0.0, 0.0, 10.0, 10.0), impeller.uniformRadii(1.0));
    builder.close();

    var copied = try builder.copyPath(impeller.fill_types.non_zero);
    defer copied.deinit();
    const bounds = copied.getBounds();
    try std.testing.expect(bounds.width >= 10.0);
    try std.testing.expect(bounds.height >= 10.0);

    var taken = try builder.takePath(impeller.fill_types.odd);
    defer taken.deinit();
    try std.testing.expect(taken.raw() != null);
}

test "display list state" {
    var paint = try impeller.Paint.init();
    defer paint.deinit();
    var path_builder = try impeller.PathBuilder.init();
    defer path_builder.deinit();
    path_builder.addRect(impeller.rect(0.0, 0.0, 8.0, 8.0));
    var path = try path_builder.takePath(impeller.fill_types.non_zero);
    defer path.deinit();

    var backdrop = try impeller.ImageFilter.initBlur(1.0, 1.0, impeller.tile_modes.clamp);
    defer backdrop.deinit();
    var builder = try impeller.DisplayListBuilder.init(impeller.rect(0.0, 0.0, 100.0, 100.0));
    defer builder.deinit();

    builder.drawLine(impeller.point(0.0, 0.0), impeller.point(10.0, 10.0), paint);
    builder.drawDashedLine(impeller.point(0.0, 1.0), impeller.point(10.0, 11.0), 2.0, 1.0, paint);
    builder.drawRect(impeller.rect(0.0, 0.0, 8.0, 8.0), paint);
    builder.drawOval(impeller.rect(0.0, 0.0, 8.0, 8.0), paint);
    builder.drawRoundedRect(impeller.rect(0.0, 0.0, 8.0, 8.0), impeller.uniformRadii(1.0), paint);
    builder.drawRoundedRectDifference(
        impeller.rect(0.0, 0.0, 10.0, 10.0),
        impeller.uniformRadii(2.0),
        impeller.rect(2.0, 2.0, 6.0, 6.0),
        impeller.uniformRadii(1.0),
        paint,
    );
    builder.drawPath(path, paint);
    builder.drawShadow(path, impeller.srgb(0.0, 0.0, 0.0, 0.5), 2.0, false, 1.0);
    builder.drawPaint(paint);

    builder.clipRect(impeller.rect(0.0, 0.0, 20.0, 20.0), impeller.clip_operations.intersect);
    builder.clipOval(impeller.rect(0.0, 0.0, 20.0, 20.0), impeller.clip_operations.difference);
    builder.clipRoundedRect(
        impeller.rect(0.0, 0.0, 20.0, 20.0),
        impeller.uniformRadii(2.0),
        impeller.clip_operations.intersect,
    );
    builder.clipPath(path, impeller.clip_operations.intersect);

    try std.testing.expectEqual(@as(u32, 1), builder.getSaveCount());
    builder.save();
    try std.testing.expectEqual(@as(u32, 2), builder.getSaveCount());
    builder.saveLayer(impeller.rect(0.0, 0.0, 20.0, 20.0), paint, backdrop);
    try std.testing.expectEqual(@as(u32, 3), builder.getSaveCount());
    builder.restore();
    builder.restoreToCount(1);

    builder.scale(2.0, 3.0);
    builder.rotate(30.0);
    builder.translate(4.0, 5.0);
    const transform = impeller.Matrix{ .m = [_]f32{
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        1.0, 2.0, 0.0, 1.0,
    } };
    builder.transform(transform);
    builder.setTransform(transform);
    try std.testing.expectEqual(transform, builder.getTransform());
    builder.resetTransform();
    try std.testing.expectEqual(impeller.Matrix{ .m = [_]f32{
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
    } }, builder.getTransform());

    var display_list = try builder.build();
    defer display_list.deinit();
    var cloned = display_list.clone();
    defer cloned.deinit();
    try std.testing.expect(display_list.raw() != null);
    try std.testing.expectEqual(display_list.raw(), cloned.raw());
}

test "paragraph layout" {
    var typography = try impeller.TypographyContext.init();
    defer typography.deinit();
    var typography_clone = typography.clone();
    defer typography_clone.deinit();

    var style = try impeller.ParagraphStyle.init();
    defer style.deinit();
    style.setFontWeight(impeller.font_weights.bold);
    style.setFontStyle(impeller.font_styles.italic);
    style.setFontFamily("sans-serif");
    style.setFontSize(16.0);
    style.setHeight(1.2);
    style.setTextAlignment(impeller.text_alignments.center);
    style.setTextDirection(impeller.text_directions.ltr);
    style.setTextDecoration(.{
        .types = .{ .underline = true },
        .color = impeller.srgb(1.0, 0.0, 0.0, 1.0),
        .style = .solid,
        .thickness_multiplier = 1.0,
    });
    style.setMaxLines(3);
    style.setLocale("en-US");
    style.setEllipsis("...");

    var builder = try impeller.ParagraphBuilder.init(typography);
    defer builder.deinit();
    builder.pushStyle(style);
    builder.addText("Impeller Zig");
    builder.popStyle();
    builder.addText(" text");

    var paragraph = try builder.build(160.0);
    defer paragraph.deinit();
    var paragraph_clone = paragraph.clone();
    defer paragraph_clone.deinit();
    try std.testing.expectEqual(@as(f32, 160.0), paragraph.getMaxWidth());
    try std.testing.expect(paragraph.getHeight() >= 0.0);
    try std.testing.expect(paragraph.getLongestLineWidth() >= 0.0);
    try std.testing.expect(paragraph.getMinIntrinsicWidth() >= 0.0);
    try std.testing.expect(paragraph.getMaxIntrinsicWidth() >= 0.0);
    try std.testing.expect(paragraph.getIdeographicBaseline() >= 0.0);
    try std.testing.expect(paragraph.getAlphabeticBaseline() >= 0.0);
    try std.testing.expect(paragraph.getLineCount() >= 1);

    const word = paragraph.getWordBoundary(1);
    try std.testing.expect(word.end >= word.start);
    var metrics = try paragraph.getLineMetrics();
    defer metrics.deinit();
    var metrics_clone = metrics.clone();
    defer metrics_clone.deinit();
    try std.testing.expect(metrics.raw() == metrics_clone.raw());
    _ = metrics.getUnscaledAscent(0);
    _ = metrics.getAscent(0);
    _ = metrics.getDescent(0);
    _ = metrics.getBaseline(0);
    _ = metrics.isHardbreak(0);
    try std.testing.expect(metrics.getHeight(0) >= 0.0);
    try std.testing.expect(metrics.getWidth(0) >= 0.0);
    _ = metrics.getLeft(0);
    try std.testing.expect(metrics.getCodeUnitEndIndex(0) >= metrics.getCodeUnitStartIndex(0));
    _ = metrics.getCodeUnitEndIndexExcludingWhitespace(0);
    _ = metrics.getCodeUnitEndIndexIncludingNewline(0);

    var glyph = try paragraph.createGlyphInfoAtCodeUnitIndex(1);
    defer glyph.deinit();
    var glyph_clone = glyph.clone();
    defer glyph_clone.deinit();
    try std.testing.expect(glyph.raw() == glyph_clone.raw());
    try std.testing.expect(glyph.getGraphemeClusterCodeUnitRangeEnd() >= glyph.getGraphemeClusterCodeUnitRangeBegin());
    _ = glyph.getGraphemeClusterBounds();
    _ = glyph.isEllipsis();
    _ = try glyph.getTextDirection();
}

test "resource clones" {
    var paint = try impeller.Paint.init();
    var paint_clone = paint.clone();
    defer paint_clone.deinit();
    try std.testing.expectEqual(paint.raw(), paint_clone.raw());
    paint.deinit();
    paint_clone.setColor(impeller.srgb(1.0, 0.0, 0.0, 1.0));

    var color_filter = try impeller.ColorFilter.initBlend(
        impeller.srgb(1.0, 1.0, 1.0, 1.0),
        impeller.blend_modes.source_over,
    );
    defer color_filter.deinit();
    var color_filter_clone = color_filter.clone();
    defer color_filter_clone.deinit();
    try std.testing.expectEqual(color_filter.raw(), color_filter_clone.raw());

    var color_source = try impeller.ColorSource.initSweepGradient(
        impeller.point(0.0, 0.0),
        0.0,
        1.0,
        &[_]impeller.Color{impeller.srgb(1.0, 0.0, 0.0, 1.0)},
        &[_]f32{0.0},
        impeller.tile_modes.clamp,
        null,
    );
    defer color_source.deinit();
    var color_source_clone = color_source.clone();
    defer color_source_clone.deinit();
    try std.testing.expectEqual(color_source.raw(), color_source_clone.raw());

    var image_filter = try impeller.ImageFilter.initBlur(1.0, 1.0, impeller.tile_modes.clamp);
    defer image_filter.deinit();
    var image_filter_clone = image_filter.clone();
    defer image_filter_clone.deinit();
    try std.testing.expectEqual(image_filter.raw(), image_filter_clone.raw());

    var mask_filter = try impeller.MaskFilter.initBlur(impeller.blur_styles.normal, 1.0);
    defer mask_filter.deinit();
    var mask_filter_clone = mask_filter.clone();
    defer mask_filter_clone.deinit();
    try std.testing.expectEqual(mask_filter.raw(), mask_filter_clone.raw());

    var path_builder = try impeller.PathBuilder.init();
    defer path_builder.deinit();
    var path_builder_clone = path_builder.clone();
    defer path_builder_clone.deinit();
    try std.testing.expectEqual(path_builder.raw(), path_builder_clone.raw());

    path_builder.addRect(impeller.rect(0.0, 0.0, 1.0, 1.0));
    var path = try path_builder.takePath(impeller.fill_types.non_zero);
    var path_clone = path.clone();
    defer path_clone.deinit();
    try std.testing.expectEqual(path.raw(), path_clone.raw());
    path.deinit();
    try std.testing.expectEqual(impeller.rect(0.0, 0.0, 1.0, 1.0), path_clone.getBounds());

    var typography = try impeller.TypographyContext.init();
    defer typography.deinit();
    var style = try impeller.ParagraphStyle.init();
    defer style.deinit();
    var style_clone = style.clone();
    defer style_clone.deinit();
    try std.testing.expectEqual(style.raw(), style_clone.raw());
    var paragraph_builder = try impeller.ParagraphBuilder.init(typography);
    defer paragraph_builder.deinit();
    var paragraph_builder_clone = paragraph_builder.clone();
    defer paragraph_builder_clone.deinit();
    try std.testing.expectEqual(paragraph_builder.raw(), paragraph_builder_clone.raw());
}

test "resource cleanup" {
    var paint = try impeller.Paint.init();
    paint.deinit();
    paint.deinit();
    try std.testing.expect(paint.raw() == null);

    var style = try impeller.ParagraphStyle.init();
    style.deinit();
    style.deinit();
    try std.testing.expect(style.raw() == null);
}
