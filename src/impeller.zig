/// Raw Impeller C API.
///
/// Prefer the Zig wrappers re-exported from this module for normal use. This
/// namespace is an escape hatch for API surface that has not been wrapped yet.
pub const c = @import("impeller_c");

pub const errors = @import("errors.zig");
pub const version_info = @import("version.zig");
pub const geometry = @import("geometry.zig");
pub const color = @import("color.zig");
pub const context = @import("context.zig");
pub const mapping = @import("mapping.zig");
pub const texture = @import("texture.zig");
pub const paint = @import("paint.zig");
pub const path = @import("path.zig");
pub const display_list = @import("display_list.zig");
pub const surface = @import("surface.zig");
pub const text = @import("text.zig");

pub const Error = errors.Error;

pub const version = version_info.value;
pub const version_variant = version_info.variant;
pub const version_major = version_info.major;
pub const version_minor = version_info.minor;
pub const version_patch = version_info.patch;
pub const runtimeVersion = version_info.runtime;
pub const makeVersion = version_info.make;
pub const versionVariant = version_info.variantOf;
pub const versionMajor = version_info.majorOf;
pub const versionMinor = version_info.minorOf;
pub const versionPatch = version_info.patchOf;
pub const checkVersion = version_info.check;

pub const Callback = mapping.Callback;
pub const Mapping = mapping.Mapping;
pub const OwnedMapping = mapping.OwnedMapping;

pub const Point = geometry.Point;
pub const Size = geometry.Size;
pub const ISize = geometry.ISize;
pub const Range = geometry.Range;
pub const Rect = geometry.Rect;
pub const Matrix = geometry.Matrix;
pub const ColorMatrix = geometry.ColorMatrix;
pub const RoundingRadii = geometry.RoundingRadii;
pub const rect = geometry.rect;
pub const point = geometry.point;
pub const uniformRadii = geometry.uniformRadii;
pub const colorMatrix = geometry.colorMatrix;
pub const pixelSize = geometry.pixelSize;

pub const Color = color.Color;
pub const ColorSpace = color.Space;
pub const srgb = color.srgb;
pub const color_spaces = color.spaces;

pub const Context = context.Context;
pub const VulkanInfo = context.VulkanInfo;
pub const VulkanSettings = context.VulkanSettings;
pub const ProcAddressCallback = context.ProcAddressCallback;
pub const VulkanProcAddressCallback = context.VulkanProcAddressCallback;

pub const PixelFormat = texture.PixelFormat;
pub const TextureSampling = texture.Sampling;
pub const TextureDescriptor = texture.Descriptor;
pub const Texture = texture.Texture;
pub const TextureHandle = texture.TextureHandle;
pub const textureDescriptor = texture.createDescriptor;
pub const pixel_formats = struct {
    pub const rgba8888 = PixelFormat.rgba8888;
};
pub const texture_samplings = struct {
    pub const nearest_neighbor = TextureSampling.nearest_neighbor;
    pub const linear = TextureSampling.linear;
};

pub const Paint = paint.Paint;
pub const ColorFilter = paint.ColorFilter;
pub const ColorSource = paint.ColorSource;
pub const FragmentProgram = paint.FragmentProgram;
pub const ImageFilter = paint.ImageFilter;
pub const MaskFilter = paint.MaskFilter;
pub const ImageFilterHandle = c.ImpellerImageFilter;
pub const BlendMode = paint.BlendMode;
pub const DrawStyle = paint.DrawStyle;
pub const StrokeCap = paint.StrokeCap;
pub const StrokeJoin = paint.StrokeJoin;
pub const TileMode = paint.TileMode;
pub const BlurStyle = paint.BlurStyle;

pub const Path = path.Path;
pub const PathBuilder = path.Builder;
pub const FillType = path.FillType;

pub const DisplayList = display_list.DisplayList;
pub const DisplayListBuilder = display_list.Builder;
pub const ClipOperation = display_list.ClipOperation;

pub const Surface = surface.Surface;
pub const VulkanSwapchain = surface.VulkanSwapchain;

pub const TypographyContext = text.TypographyContext;
pub const ParagraphStyle = text.ParagraphStyle;
pub const ParagraphBuilder = text.ParagraphBuilder;
pub const Paragraph = text.Paragraph;
pub const LineMetrics = text.LineMetrics;
pub const GlyphInfo = text.GlyphInfo;
pub const FontWeight = text.FontWeight;
pub const FontStyle = text.FontStyle;
pub const TextAlignment = text.TextAlignment;
pub const TextDirection = text.TextDirection;
pub const TextDecorationType = text.TextDecorationType;
pub const TextDecorationStyle = text.TextDecorationStyle;
pub const TextDecoration = text.TextDecoration;

pub const fill_types = struct {
    pub const non_zero = FillType.non_zero;
    pub const odd = FillType.odd;
};
pub const clip_operations = struct {
    pub const difference = ClipOperation.difference;
    pub const intersect = ClipOperation.intersect;
};
pub const blend_modes = struct {
    pub const clear = BlendMode.clear;
    pub const source = BlendMode.source;
    pub const destination = BlendMode.destination;
    pub const source_over = BlendMode.source_over;
    pub const destination_over = BlendMode.destination_over;
    pub const source_in = BlendMode.source_in;
    pub const destination_in = BlendMode.destination_in;
    pub const source_out = BlendMode.source_out;
    pub const destination_out = BlendMode.destination_out;
    pub const source_atop = BlendMode.source_atop;
    pub const destination_atop = BlendMode.destination_atop;
    pub const xor = BlendMode.xor;
    pub const plus = BlendMode.plus;
    pub const modulate = BlendMode.modulate;
    pub const screen = BlendMode.screen;
    pub const overlay = BlendMode.overlay;
    pub const darken = BlendMode.darken;
    pub const lighten = BlendMode.lighten;
    pub const color_dodge = BlendMode.color_dodge;
    pub const color_burn = BlendMode.color_burn;
    pub const hard_light = BlendMode.hard_light;
    pub const soft_light = BlendMode.soft_light;
    pub const difference = BlendMode.difference;
    pub const exclusion = BlendMode.exclusion;
    pub const multiply = BlendMode.multiply;
    pub const hue = BlendMode.hue;
    pub const saturation = BlendMode.saturation;
    pub const color = BlendMode.color;
    pub const luminosity = BlendMode.luminosity;
};
pub const draw_styles = struct {
    pub const fill = DrawStyle.fill;
    pub const stroke = DrawStyle.stroke;
    pub const stroke_and_fill = DrawStyle.stroke_and_fill;
};
pub const stroke_caps = struct {
    pub const butt = StrokeCap.butt;
    pub const round = StrokeCap.round;
    pub const square = StrokeCap.square;
};
pub const stroke_joins = struct {
    pub const miter = StrokeJoin.miter;
    pub const round = StrokeJoin.round;
    pub const bevel = StrokeJoin.bevel;
};
pub const tile_modes = struct {
    pub const clamp = TileMode.clamp;
    pub const repeat = TileMode.repeat;
    pub const mirror = TileMode.mirror;
    pub const decal = TileMode.decal;
};
pub const blur_styles = struct {
    pub const normal = BlurStyle.normal;
    pub const solid = BlurStyle.solid;
    pub const outer = BlurStyle.outer;
    pub const inner = BlurStyle.inner;
};
pub const font_weights = text.font_weights;
pub const font_styles = text.font_styles;
pub const text_alignments = text.text_alignments;
pub const text_directions = text.text_directions;
pub const text_decoration_types = text.text_decoration_types;
pub const text_decoration_styles = text.text_decoration_styles;
