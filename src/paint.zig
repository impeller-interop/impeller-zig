const std = @import("std");
const c = @import("impeller_c");
const Error = @import("errors.zig").Error;
const Context = @import("context.zig").Context;
const Mapping = @import("mapping.zig").Mapping;
const OwnedMapping = @import("mapping.zig").OwnedMapping;
const geometry = @import("geometry.zig");
const color_mod = @import("color.zig");
const texture_mod = @import("texture.zig");

const Color = color_mod.Color;
const ColorMatrix = geometry.ColorMatrix;
const ContextType = Context;
const Matrix = geometry.Matrix;
const Point = geometry.Point;
const Texture = texture_mod.Texture;
const TextureSampling = texture_mod.Sampling;

pub const BlendMode = enum(c.ImpellerBlendMode) {
    clear = c.kImpellerBlendModeClear,
    source = c.kImpellerBlendModeSource,
    destination = c.kImpellerBlendModeDestination,
    source_over = c.kImpellerBlendModeSourceOver,
    destination_over = c.kImpellerBlendModeDestinationOver,
    source_in = c.kImpellerBlendModeSourceIn,
    destination_in = c.kImpellerBlendModeDestinationIn,
    source_out = c.kImpellerBlendModeSourceOut,
    destination_out = c.kImpellerBlendModeDestinationOut,
    source_atop = c.kImpellerBlendModeSourceATop,
    destination_atop = c.kImpellerBlendModeDestinationATop,
    xor = c.kImpellerBlendModeXor,
    plus = c.kImpellerBlendModePlus,
    modulate = c.kImpellerBlendModeModulate,
    screen = c.kImpellerBlendModeScreen,
    overlay = c.kImpellerBlendModeOverlay,
    darken = c.kImpellerBlendModeDarken,
    lighten = c.kImpellerBlendModeLighten,
    color_dodge = c.kImpellerBlendModeColorDodge,
    color_burn = c.kImpellerBlendModeColorBurn,
    hard_light = c.kImpellerBlendModeHardLight,
    soft_light = c.kImpellerBlendModeSoftLight,
    difference = c.kImpellerBlendModeDifference,
    exclusion = c.kImpellerBlendModeExclusion,
    multiply = c.kImpellerBlendModeMultiply,
    hue = c.kImpellerBlendModeHue,
    saturation = c.kImpellerBlendModeSaturation,
    color = c.kImpellerBlendModeColor,
    luminosity = c.kImpellerBlendModeLuminosity,

    pub fn toC(self: BlendMode) c.ImpellerBlendMode {
        return @intFromEnum(self);
    }
};

pub const DrawStyle = enum(c.ImpellerDrawStyle) {
    fill = c.kImpellerDrawStyleFill,
    stroke = c.kImpellerDrawStyleStroke,
    stroke_and_fill = c.kImpellerDrawStyleStrokeAndFill,

    pub fn toC(self: DrawStyle) c.ImpellerDrawStyle {
        return @intFromEnum(self);
    }
};

pub const StrokeCap = enum(c.ImpellerStrokeCap) {
    butt = c.kImpellerStrokeCapButt,
    round = c.kImpellerStrokeCapRound,
    square = c.kImpellerStrokeCapSquare,

    pub fn toC(self: StrokeCap) c.ImpellerStrokeCap {
        return @intFromEnum(self);
    }
};

pub const StrokeJoin = enum(c.ImpellerStrokeJoin) {
    miter = c.kImpellerStrokeJoinMiter,
    round = c.kImpellerStrokeJoinRound,
    bevel = c.kImpellerStrokeJoinBevel,

    pub fn toC(self: StrokeJoin) c.ImpellerStrokeJoin {
        return @intFromEnum(self);
    }
};

pub const TileMode = enum(c.ImpellerTileMode) {
    clamp = c.kImpellerTileModeClamp,
    repeat = c.kImpellerTileModeRepeat,
    mirror = c.kImpellerTileModeMirror,
    decal = c.kImpellerTileModeDecal,

    pub fn toC(self: TileMode) c.ImpellerTileMode {
        return @intFromEnum(self);
    }
};

pub const BlurStyle = enum(c.ImpellerBlurStyle) {
    normal = c.kImpellerBlurStyleNormal,
    solid = c.kImpellerBlurStyleSolid,
    outer = c.kImpellerBlurStyleOuter,
    inner = c.kImpellerBlurStyleInner,

    pub fn toC(self: BlurStyle) c.ImpellerBlurStyle {
        return @intFromEnum(self);
    }
};

pub const Paint = struct {
    handle: c.ImpellerPaint,

    /// Creates a paint object with Impeller defaults.
    pub fn init() Error!Paint {
        const handle = c.ImpellerPaintNew() orelse return Error.CreatePaintFailed;
        return .{ .handle = handle };
    }

    /// Returns a retained paint owner that must be deinitialized independently.
    pub fn clone(self: Paint) Paint {
        c.ImpellerPaintRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this paint reference.
    pub fn deinit(self: *Paint) void {
        if (self.handle == null) return;
        c.ImpellerPaintRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller paint handle.
    pub fn raw(self: Paint) c.ImpellerPaint {
        return self.handle;
    }

    /// Sets the paint color.
    pub fn setColor(self: Paint, color: Color) void {
        var local_color = color.toC();
        c.ImpellerPaintSetColor(self.handle, &local_color);
    }

    /// Sets the paint blend mode.
    pub fn setBlendMode(self: Paint, mode: BlendMode) void {
        c.ImpellerPaintSetBlendMode(self.handle, mode.toC());
    }

    /// Sets whether this paint fills, strokes, or does both.
    pub fn setDrawStyle(self: Paint, style: DrawStyle) void {
        c.ImpellerPaintSetDrawStyle(self.handle, style.toC());
    }

    /// Sets how open stroke ends are capped.
    pub fn setStrokeCap(self: Paint, cap: StrokeCap) void {
        c.ImpellerPaintSetStrokeCap(self.handle, cap.toC());
    }

    /// Sets how connected stroke segments are joined.
    pub fn setStrokeJoin(self: Paint, join: StrokeJoin) void {
        c.ImpellerPaintSetStrokeJoin(self.handle, join.toC());
    }

    /// Sets the stroke width used by this paint.
    pub fn setStrokeWidth(self: Paint, width: f32) void {
        c.ImpellerPaintSetStrokeWidth(self.handle, width);
    }

    /// Sets the stroke miter limit used by this paint.
    pub fn setStrokeMiter(self: Paint, miter: f32) void {
        c.ImpellerPaintSetStrokeMiter(self.handle, miter);
    }

    /// Sets the color source applied by this paint.
    /// The paint keeps the required state after the call returns.
    pub fn setColorSource(self: Paint, color_source: ColorSource) void {
        c.ImpellerPaintSetColorSource(self.handle, color_source.handle);
    }

    /// Sets the color filter applied by this paint.
    /// The paint keeps the required state after the call returns.
    pub fn setColorFilter(self: Paint, color_filter: ColorFilter) void {
        c.ImpellerPaintSetColorFilter(self.handle, color_filter.handle);
    }

    /// Sets the mask filter applied by this paint.
    /// The paint keeps the required state after the call returns.
    pub fn setMaskFilter(self: Paint, mask_filter: MaskFilter) void {
        c.ImpellerPaintSetMaskFilter(self.handle, mask_filter.handle);
    }

    /// Sets the image filter applied by this paint.
    /// The paint keeps the required state after the call returns.
    pub fn setImageFilter(self: Paint, image_filter: ImageFilter) void {
        c.ImpellerPaintSetImageFilter(self.handle, image_filter.handle);
    }
};

pub const ColorFilter = struct {
    handle: c.ImpellerColorFilter,

    /// Creates a color filter that blends every sampled color with the provided color.
    pub fn initBlend(color: Color, blend_mode: BlendMode) Error!ColorFilter {
        var local_color = color.toC();
        const handle = c.ImpellerColorFilterCreateBlendNew(
            &local_color,
            blend_mode.toC(),
        ) orelse return Error.CreateColorFilterFailed;
        return .{ .handle = handle };
    }

    /// Creates a color filter from a 4x5 color matrix.
    pub fn initColorMatrix(color_matrix: ColorMatrix) Error!ColorFilter {
        var local_color_matrix = color_matrix.toC();
        const handle = c.ImpellerColorFilterCreateColorMatrixNew(&local_color_matrix) orelse return Error.CreateColorFilterFailed;
        return .{ .handle = handle };
    }

    /// Returns a retained color filter owner that must be deinitialized independently.
    pub fn clone(self: ColorFilter) ColorFilter {
        c.ImpellerColorFilterRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this color filter reference.
    pub fn deinit(self: *ColorFilter) void {
        if (self.handle == null) return;
        c.ImpellerColorFilterRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller color filter handle.
    pub fn raw(self: ColorFilter) c.ImpellerColorFilter {
        return self.handle;
    }
};

pub const ColorSource = struct {
    handle: c.ImpellerColorSource,

    /// Creates a linear gradient color source.
    pub fn initLinearGradient(
        start_point: Point,
        end_point: Point,
        colors: []const Color,
        stops: []const f32,
        tile_mode: TileMode,
        transformation: ?Matrix,
    ) Error!ColorSource {
        var local_start_point = start_point.toC();
        var local_end_point = end_point.toC();
        var local_transformation = if (transformation) |value| value.toC() else null;
        const transform_ptr = if (local_transformation) |*value| value else null;
        const handle = c.ImpellerColorSourceCreateLinearGradientNew(
            &local_start_point,
            &local_end_point,
            @intCast(colors.len),
            @ptrCast(colors.ptr),
            stops.ptr,
            tile_mode.toC(),
            transform_ptr,
        ) orelse return Error.CreateColorSourceFailed;
        return .{ .handle = handle };
    }

    /// Creates a radial gradient color source.
    pub fn initRadialGradient(
        center: Point,
        radius: f32,
        colors: []const Color,
        stops: []const f32,
        tile_mode: TileMode,
        transformation: ?Matrix,
    ) Error!ColorSource {
        var local_center = center.toC();
        var local_transformation = if (transformation) |value| value.toC() else null;
        const transform_ptr = if (local_transformation) |*value| value else null;
        const handle = c.ImpellerColorSourceCreateRadialGradientNew(
            &local_center,
            radius,
            @intCast(colors.len),
            @ptrCast(colors.ptr),
            stops.ptr,
            tile_mode.toC(),
            transform_ptr,
        ) orelse return Error.CreateColorSourceFailed;
        return .{ .handle = handle };
    }

    /// Creates a conical gradient color source.
    pub fn initConicalGradient(
        start_center: Point,
        start_radius: f32,
        end_center: Point,
        end_radius: f32,
        colors: []const Color,
        stops: []const f32,
        tile_mode: TileMode,
        transformation: ?Matrix,
    ) Error!ColorSource {
        var local_start_center = start_center.toC();
        var local_end_center = end_center.toC();
        var local_transformation = if (transformation) |value| value.toC() else null;
        const transform_ptr = if (local_transformation) |*value| value else null;
        const handle = c.ImpellerColorSourceCreateConicalGradientNew(
            &local_start_center,
            start_radius,
            &local_end_center,
            end_radius,
            @intCast(colors.len),
            @ptrCast(colors.ptr),
            stops.ptr,
            tile_mode.toC(),
            transform_ptr,
        ) orelse return Error.CreateColorSourceFailed;
        return .{ .handle = handle };
    }

    /// Creates a sweep gradient color source.
    pub fn initSweepGradient(
        center: Point,
        start_angle: f32,
        end_angle: f32,
        colors: []const Color,
        stops: []const f32,
        tile_mode: TileMode,
        transformation: ?Matrix,
    ) Error!ColorSource {
        var local_center = center.toC();
        var local_transformation = if (transformation) |value| value.toC() else null;
        const transform_ptr = if (local_transformation) |*value| value else null;
        const handle = c.ImpellerColorSourceCreateSweepGradientNew(
            &local_center,
            start_angle,
            end_angle,
            @intCast(colors.len),
            @ptrCast(colors.ptr),
            stops.ptr,
            tile_mode.toC(),
            transform_ptr,
        ) orelse return Error.CreateColorSourceFailed;
        return .{ .handle = handle };
    }

    /// Creates an image-backed color source.
    pub fn initImage(
        texture: Texture,
        horizontal_tile_mode: TileMode,
        vertical_tile_mode: TileMode,
        sampling: TextureSampling,
        transformation: ?Matrix,
    ) Error!ColorSource {
        var local_transformation = if (transformation) |value| value.toC() else null;
        const transform_ptr = if (local_transformation) |*value| value else null;
        const handle = c.ImpellerColorSourceCreateImageNew(
            texture.handle,
            horizontal_tile_mode.toC(),
            vertical_tile_mode.toC(),
            sampling.toC(),
            transform_ptr,
        ) orelse return Error.CreateColorSourceFailed;
        return .{ .handle = handle };
    }

    /// Creates a fragment-program color source from a compiled program, sampler
    /// textures, and a uniform data buffer.
    pub fn initFragmentProgram(
        allocator: std.mem.Allocator,
        context: ContextType,
        fragment_program: FragmentProgram,
        samplers: []const Texture,
        data: []const u8,
    ) Error!ColorSource {
        const sampler_handles = try texture_mod.handlesFromSlice(allocator, samplers);
        defer allocator.free(sampler_handles);
        const handle = c.ImpellerColorSourceCreateFragmentProgramNew(
            context.handle,
            fragment_program.handle,
            if (sampler_handles.len == 0) null else sampler_handles.ptr,
            sampler_handles.len,
            if (data.len == 0) null else data.ptr,
            data.len,
        ) orelse return Error.CreateColorSourceFailed;
        return .{ .handle = handle };
    }

    /// Returns a retained color source owner that must be deinitialized independently.
    pub fn clone(self: ColorSource) ColorSource {
        c.ImpellerColorSourceRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this color source reference.
    pub fn deinit(self: *ColorSource) void {
        if (self.handle == null) return;
        c.ImpellerColorSourceRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller color source handle.
    pub fn raw(self: ColorSource) c.ImpellerColorSource {
        return self.handle;
    }
};

pub const FragmentProgram = struct {
    handle: c.ImpellerFragmentProgram,

    /// Creates a fragment program from a caller-managed mapping.
    /// The release callback may run on any thread.
    pub fn initMapping(data: Mapping) Error!FragmentProgram {
        var local_data = data.value;
        const handle = c.ImpellerFragmentProgramNew(
            &local_data,
            data.release_user_data,
        ) orelse return Error.CreateFragmentProgramFailed;
        return .{ .handle = handle };
    }

    /// Creates a fragment program borrowing impellerc-compiled bytes.
    /// The bytes must outlive all Impeller use of the program.
    pub fn initBorrowed(data: []const u8) Error!FragmentProgram {
        return FragmentProgram.initMapping(Mapping.borrowed(data));
    }

    /// Copies impellerc-compiled bytes and transfers cleanup to Impeller.
    /// The allocator must remain valid until the release callback has run.
    pub fn initCopy(allocator: std.mem.Allocator, data: []const u8) Error!FragmentProgram {
        var owned = try OwnedMapping.copy(allocator, data);
        errdefer owned.deinit();

        const fragment_program = try FragmentProgram.initMapping(owned.mapping);
        owned.releaseToImpeller();
        return fragment_program;
    }

    /// Returns a retained fragment program owner that must be deinitialized independently.
    pub fn clone(self: FragmentProgram) FragmentProgram {
        c.ImpellerFragmentProgramRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this fragment program reference.
    pub fn deinit(self: *FragmentProgram) void {
        if (self.handle == null) return;
        c.ImpellerFragmentProgramRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller fragment program handle.
    pub fn raw(self: FragmentProgram) c.ImpellerFragmentProgram {
        return self.handle;
    }
};

pub const ImageFilter = struct {
    handle: c.ImpellerImageFilter,

    /// Creates a Gaussian blur image filter.
    pub fn initBlur(x_sigma: f32, y_sigma: f32, tile_mode: TileMode) Error!ImageFilter {
        const handle = c.ImpellerImageFilterCreateBlurNew(
            x_sigma,
            y_sigma,
            tile_mode.toC(),
        ) orelse return Error.CreateImageFilterFailed;
        return .{ .handle = handle };
    }

    /// Creates a dilate image filter.
    pub fn initDilate(x_radius: f32, y_radius: f32) Error!ImageFilter {
        const handle = c.ImpellerImageFilterCreateDilateNew(x_radius, y_radius) orelse return Error.CreateImageFilterFailed;
        return .{ .handle = handle };
    }

    /// Creates an erode image filter.
    pub fn initErode(x_radius: f32, y_radius: f32) Error!ImageFilter {
        const handle = c.ImpellerImageFilterCreateErodeNew(x_radius, y_radius) orelse return Error.CreateImageFilterFailed;
        return .{ .handle = handle };
    }

    /// Creates a matrix image filter.
    pub fn initMatrix(matrix: Matrix, sampling: TextureSampling) Error!ImageFilter {
        var local_matrix = matrix.toC();
        const handle = c.ImpellerImageFilterCreateMatrixNew(
            &local_matrix,
            sampling.toC(),
        ) orelse return Error.CreateImageFilterFailed;
        return .{ .handle = handle };
    }

    /// Creates a fragment-program image filter from a compiled program, sampler
    /// textures, and a uniform data buffer.
    pub fn initFragmentProgram(
        allocator: std.mem.Allocator,
        context: ContextType,
        fragment_program: FragmentProgram,
        samplers: []const Texture,
        data: []const u8,
    ) Error!ImageFilter {
        const sampler_handles = try texture_mod.handlesFromSlice(allocator, samplers);
        defer allocator.free(sampler_handles);
        const handle = c.ImpellerImageFilterCreateFragmentProgramNew(
            context.handle,
            fragment_program.handle,
            if (sampler_handles.len == 0) null else sampler_handles.ptr,
            sampler_handles.len,
            if (data.len == 0) null else data.ptr,
            data.len,
        ) orelse return Error.CreateImageFilterFailed;
        return .{ .handle = handle };
    }

    /// Creates a composed image filter.
    pub fn initCompose(outer: ImageFilter, inner: ImageFilter) Error!ImageFilter {
        const handle = c.ImpellerImageFilterCreateComposeNew(outer.handle, inner.handle) orelse return Error.CreateImageFilterFailed;
        return .{ .handle = handle };
    }

    /// Returns a retained image filter owner that must be deinitialized independently.
    pub fn clone(self: ImageFilter) ImageFilter {
        c.ImpellerImageFilterRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this image filter reference.
    pub fn deinit(self: *ImageFilter) void {
        if (self.handle == null) return;
        c.ImpellerImageFilterRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller image filter handle.
    pub fn raw(self: ImageFilter) c.ImpellerImageFilter {
        return self.handle;
    }
};

pub const MaskFilter = struct {
    handle: c.ImpellerMaskFilter,

    /// Creates a blur mask filter.
    pub fn initBlur(style: BlurStyle, sigma: f32) Error!MaskFilter {
        const handle = c.ImpellerMaskFilterCreateBlurNew(style.toC(), sigma) orelse return Error.CreateMaskFilterFailed;
        return .{ .handle = handle };
    }

    /// Returns a retained mask filter owner that must be deinitialized independently.
    pub fn clone(self: MaskFilter) MaskFilter {
        c.ImpellerMaskFilterRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this mask filter reference.
    pub fn deinit(self: *MaskFilter) void {
        if (self.handle == null) return;
        c.ImpellerMaskFilterRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller mask filter handle.
    pub fn raw(self: MaskFilter) c.ImpellerMaskFilter {
        return self.handle;
    }
};
