const std = @import("std");
const c = @import("impeller_c");
const Error = @import("errors.zig").Error;
const geometry = @import("geometry.zig");
const color_mod = @import("color.zig");
const paint_mod = @import("paint.zig");
const path_mod = @import("path.zig");
const texture_mod = @import("texture.zig");
const text_mod = @import("text.zig");

const Color = color_mod.Color;
const ImageFilter = paint_mod.ImageFilter;
const Matrix = geometry.Matrix;
const Paint = paint_mod.Paint;
const Paragraph = text_mod.Paragraph;
const Path = path_mod.Path;
const Point = geometry.Point;
const Rect = geometry.Rect;
const RoundingRadii = geometry.RoundingRadii;
const Texture = texture_mod.Texture;
const TextureSampling = texture_mod.Sampling;

pub const ClipOperation = enum(c.ImpellerClipOperation) {
    difference = c.kImpellerClipOperationDifference,
    intersect = c.kImpellerClipOperationIntersect,

    pub fn toC(self: ClipOperation) c.ImpellerClipOperation {
        return @intFromEnum(self);
    }
};

pub const DisplayList = struct {
    handle: c.ImpellerDisplayList,

    /// Returns a retained display list owner that must be deinitialized independently.
    pub fn clone(self: DisplayList) DisplayList {
        c.ImpellerDisplayListRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this display list reference.
    pub fn deinit(self: *DisplayList) void {
        if (self.handle == null) return;
        c.ImpellerDisplayListRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller display list handle.
    pub fn raw(self: DisplayList) c.ImpellerDisplayList {
        return self.handle;
    }
};

pub const Builder = struct {
    handle: c.ImpellerDisplayListBuilder,

    /// Creates a display list builder with an optional cull rect.
    pub fn init(cull_rect: ?Rect) Error!Builder {
        var local_rect = if (cull_rect) |value| value.toC() else null;
        const cull_rect_ptr = if (local_rect) |*cull_rect_value| cull_rect_value else null;
        const handle = c.ImpellerDisplayListBuilderNew(cull_rect_ptr) orelse return Error.CreateDisplayListBuilderFailed;
        return .{ .handle = handle };
    }

    /// Returns a retained display list builder owner that must be deinitialized independently.
    pub fn clone(self: Builder) Builder {
        c.ImpellerDisplayListBuilderRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this display list builder reference.
    pub fn deinit(self: *Builder) void {
        if (self.handle == null) return;
        c.ImpellerDisplayListBuilderRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller display list builder handle.
    pub fn raw(self: Builder) c.ImpellerDisplayListBuilder {
        return self.handle;
    }

    /// Builds an immutable display list and resets the builder.
    pub fn build(self: Builder) Error!DisplayList {
        const handle = c.ImpellerDisplayListBuilderCreateDisplayListNew(self.handle) orelse return Error.CreateDisplayListFailed;
        return .{ .handle = handle };
    }

    /// Draws a line segment into the display list.
    pub fn drawLine(self: Builder, from: Point, to: Point, paint: Paint) void {
        var local_from = from.toC();
        var local_to = to.toC();
        c.ImpellerDisplayListBuilderDrawLine(self.handle, &local_from, &local_to, paint.handle);
    }

    /// Draws a dashed line segment into the display list.
    pub fn drawDashedLine(self: Builder, from: Point, to: Point, on_length: f32, off_length: f32, paint: Paint) void {
        var local_from = from.toC();
        var local_to = to.toC();
        c.ImpellerDisplayListBuilderDrawDashedLine(self.handle, &local_from, &local_to, on_length, off_length, paint.handle);
    }

    /// Draws a rectangle into the display list.
    pub fn drawRect(self: Builder, rectangle: Rect, paint: Paint) void {
        var local_rect = rectangle.toC();
        c.ImpellerDisplayListBuilderDrawRect(self.handle, &local_rect, paint.handle);
    }

    /// Draws an oval into the display list.
    pub fn drawOval(self: Builder, oval_bounds: Rect, paint: Paint) void {
        var local_rect = oval_bounds.toC();
        c.ImpellerDisplayListBuilderDrawOval(self.handle, &local_rect, paint.handle);
    }

    /// Draws a rounded rectangle into the display list.
    pub fn drawRoundedRect(self: Builder, rectangle: Rect, radii: RoundingRadii, paint: Paint) void {
        var local_rect = rectangle.toC();
        var local_radii = radii.toC();
        c.ImpellerDisplayListBuilderDrawRoundedRect(self.handle, &local_rect, &local_radii, paint.handle);
    }

    /// Draws the difference between two rounded rectangles.
    pub fn drawRoundedRectDifference(
        self: Builder,
        outer_rect: Rect,
        outer_radii: RoundingRadii,
        inner_rect: Rect,
        inner_radii: RoundingRadii,
        paint: Paint,
    ) void {
        var local_outer_rect = outer_rect.toC();
        var local_outer_radii = outer_radii.toC();
        var local_inner_rect = inner_rect.toC();
        var local_inner_radii = inner_radii.toC();
        c.ImpellerDisplayListBuilderDrawRoundedRectDifference(
            self.handle,
            &local_outer_rect,
            &local_outer_radii,
            &local_inner_rect,
            &local_inner_radii,
            paint.handle,
        );
    }

    /// Draws the specified shape.
    /// The builder keeps the required draw state after the call returns.
    pub fn drawPath(self: Builder, path: Path, paint: Paint) void {
        c.ImpellerDisplayListBuilderDrawPath(self.handle, path.raw(), paint.handle);
    }

    /// Draws a drop shadow for the specified path.
    pub fn drawShadow(
        self: Builder,
        path: Path,
        color: Color,
        elevation: f32,
        occluder_is_transparent: bool,
        device_pixel_ratio: f32,
    ) void {
        var local_color = color.toC();
        c.ImpellerDisplayListBuilderDrawShadow(
            self.handle,
            path.raw(),
            &local_color,
            elevation,
            occluder_is_transparent,
            device_pixel_ratio,
        );
    }

    /// Flattens another display list into this one.
    /// The builder keeps the required draw state after the call returns.
    pub fn drawDisplayList(self: Builder, display_list: DisplayList, opacity: f32) void {
        c.ImpellerDisplayListBuilderDrawDisplayList(self.handle, display_list.handle, opacity);
    }

    /// Draws a texture at the specified point.
    pub fn drawTexture(
        self: Builder,
        texture: Texture,
        point_value: Point,
        sampling: TextureSampling,
        paint: ?Paint,
    ) void {
        var local_point = point_value.toC();
        c.ImpellerDisplayListBuilderDrawTexture(
            self.handle,
            texture.handle,
            &local_point,
            sampling.toC(),
            if (paint) |value| value.raw() else null,
        );
    }

    /// Draws a sub-rectangle of a texture into the destination rectangle.
    pub fn drawTextureRect(
        self: Builder,
        texture: Texture,
        src_rect: Rect,
        dst_rect: Rect,
        sampling: TextureSampling,
        paint: ?Paint,
    ) void {
        var local_src_rect = src_rect.toC();
        var local_dst_rect = dst_rect.toC();
        c.ImpellerDisplayListBuilderDrawTextureRect(
            self.handle,
            texture.handle,
            &local_src_rect,
            &local_dst_rect,
            sampling.toC(),
            if (paint) |value| value.raw() else null,
        );
    }

    /// Draws a paint over the current clip.
    pub fn drawPaint(self: Builder, paint: Paint) void {
        c.ImpellerDisplayListBuilderDrawPaint(self.handle, paint.handle);
    }

    /// Draws a laid out paragraph at the specified point.
    pub fn drawParagraph(self: Builder, paragraph: Paragraph, point_value: Point) void {
        var local_point = point_value.toC();
        c.ImpellerDisplayListBuilderDrawParagraph(self.handle, paragraph.handle, &local_point);
    }

    /// Saves the current clip and transform state.
    pub fn save(self: Builder) void {
        c.ImpellerDisplayListBuilderSave(self.handle);
    }

    /// Saves a new layer with optional paint and backdrop filtering.
    pub fn saveLayer(self: Builder, bounds: Rect, paint: ?Paint, backdrop: ?ImageFilter) void {
        var local_bounds = bounds.toC();
        c.ImpellerDisplayListBuilderSaveLayer(
            self.handle,
            &local_bounds,
            if (paint) |value| value.raw() else null,
            if (backdrop) |value| value.raw() else null,
        );
    }

    /// Returns the current save stack depth.
    pub fn getSaveCount(self: Builder) u32 {
        return c.ImpellerDisplayListBuilderGetSaveCount(self.handle);
    }

    /// Restores the save stack until it reaches the requested depth.
    pub fn restoreToCount(self: Builder, count: u32) void {
        c.ImpellerDisplayListBuilderRestoreToCount(self.handle, count);
    }

    /// Restores the last saved clip and transform state.
    pub fn restore(self: Builder) void {
        c.ImpellerDisplayListBuilderRestore(self.handle);
    }

    /// Clips subsequent drawing operations to a rectangle.
    pub fn clipRect(self: Builder, rectangle: Rect, operation: ClipOperation) void {
        var local_rect = rectangle.toC();
        c.ImpellerDisplayListBuilderClipRect(self.handle, &local_rect, operation.toC());
    }

    /// Clips subsequent drawing operations to an oval.
    pub fn clipOval(self: Builder, oval_bounds: Rect, operation: ClipOperation) void {
        var local_rect = oval_bounds.toC();
        c.ImpellerDisplayListBuilderClipOval(self.handle, &local_rect, operation.toC());
    }

    /// Clips subsequent drawing operations to a rounded rectangle.
    pub fn clipRoundedRect(self: Builder, rectangle: Rect, radii: RoundingRadii, operation: ClipOperation) void {
        var local_rect = rectangle.toC();
        var local_radii = radii.toC();
        c.ImpellerDisplayListBuilderClipRoundedRect(self.handle, &local_rect, &local_radii, operation.toC());
    }

    /// Clips subsequent drawing operations to a path.
    pub fn clipPath(self: Builder, path: Path, operation: ClipOperation) void {
        c.ImpellerDisplayListBuilderClipPath(self.handle, path.raw(), operation.toC());
    }

    /// Applies a scale transform to the current transform.
    pub fn scale(self: Builder, x: f32, y: f32) void {
        c.ImpellerDisplayListBuilderScale(self.handle, x, y);
    }

    /// Applies a rotation transform in degrees to the current transform.
    pub fn rotate(self: Builder, degrees: f32) void {
        c.ImpellerDisplayListBuilderRotate(self.handle, degrees);
    }

    /// Applies a translation to the current transform.
    pub fn translate(self: Builder, x: f32, y: f32) void {
        c.ImpellerDisplayListBuilderTranslate(self.handle, x, y);
    }

    /// Appends a transform to the current transform.
    pub fn transform(self: Builder, matrix: Matrix) void {
        var local_matrix = matrix.toC();
        c.ImpellerDisplayListBuilderTransform(self.handle, &local_matrix);
    }

    /// Replaces the current transform.
    pub fn setTransform(self: Builder, matrix: Matrix) void {
        var local_matrix = matrix.toC();
        c.ImpellerDisplayListBuilderSetTransform(self.handle, &local_matrix);
    }

    /// Returns the current transform.
    pub fn getTransform(self: Builder) Matrix {
        var matrix: c.ImpellerMatrix = undefined;
        c.ImpellerDisplayListBuilderGetTransform(self.handle, &matrix);
        return Matrix.fromC(matrix);
    }

    /// Resets the current transform to identity.
    pub fn resetTransform(self: Builder) void {
        c.ImpellerDisplayListBuilderResetTransform(self.handle);
    }
};

test "clip operations" {
    try std.testing.expectEqual(c.kImpellerClipOperationDifference, ClipOperation.difference.toC());
    try std.testing.expectEqual(c.kImpellerClipOperationIntersect, ClipOperation.intersect.toC());
}
