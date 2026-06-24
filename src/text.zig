const std = @import("std");
const c = @import("impeller_c");
const Error = @import("errors.zig").Error;
const geometry = @import("geometry.zig");
const color_mod = @import("color.zig");
const mapping = @import("mapping.zig");
const paint_mod = @import("paint.zig");

const Mapping = mapping.Mapping;
const OwnedMapping = mapping.OwnedMapping;
const Paint = paint_mod.Paint;
const Range = geometry.Range;
const Rect = geometry.Rect;

pub const FontWeight = enum(c.ImpellerFontWeight) {
    thin = c.kImpellerFontWeight100,
    extra_light = c.kImpellerFontWeight200,
    light = c.kImpellerFontWeight300,
    normal = c.kImpellerFontWeight400,
    medium = c.kImpellerFontWeight500,
    semi_bold = c.kImpellerFontWeight600,
    bold = c.kImpellerFontWeight700,
    extra_bold = c.kImpellerFontWeight800,
    black = c.kImpellerFontWeight900,

    pub const w100 = FontWeight.thin;
    pub const w200 = FontWeight.extra_light;
    pub const w300 = FontWeight.light;
    pub const w400 = FontWeight.normal;
    pub const w500 = FontWeight.medium;
    pub const w600 = FontWeight.semi_bold;
    pub const w700 = FontWeight.bold;
    pub const w800 = FontWeight.extra_bold;
    pub const w900 = FontWeight.black;

    pub fn toC(self: FontWeight) c.ImpellerFontWeight {
        return @intFromEnum(self);
    }
};

pub const FontStyle = enum(c.ImpellerFontStyle) {
    normal = c.kImpellerFontStyleNormal,
    italic = c.kImpellerFontStyleItalic,

    pub fn toC(self: FontStyle) c.ImpellerFontStyle {
        return @intFromEnum(self);
    }
};

pub const TextAlignment = enum(c.ImpellerTextAlignment) {
    left = c.kImpellerTextAlignmentLeft,
    right = c.kImpellerTextAlignmentRight,
    center = c.kImpellerTextAlignmentCenter,
    justify = c.kImpellerTextAlignmentJustify,
    start = c.kImpellerTextAlignmentStart,
    end = c.kImpellerTextAlignmentEnd,

    pub fn toC(self: TextAlignment) c.ImpellerTextAlignment {
        return @intFromEnum(self);
    }
};

pub const TextDirection = enum(c.ImpellerTextDirection) {
    rtl = c.kImpellerTextDirectionRTL,
    ltr = c.kImpellerTextDirectionLTR,

    pub fn fromC(value: c.ImpellerTextDirection) TextDirection {
        return @enumFromInt(value);
    }

    pub fn toC(self: TextDirection) c.ImpellerTextDirection {
        return @intFromEnum(self);
    }
};

pub const TextDecorationStyle = enum(c.ImpellerTextDecorationStyle) {
    solid = c.kImpellerTextDecorationStyleSolid,
    double = c.kImpellerTextDecorationStyleDouble,
    dotted = c.kImpellerTextDecorationStyleDotted,
    dashed = c.kImpellerTextDecorationStyleDashed,
    wavy = c.kImpellerTextDecorationStyleWavy,

    pub fn toC(self: TextDecorationStyle) c.ImpellerTextDecorationStyle {
        return @intFromEnum(self);
    }
};

pub const TextDecorationType = packed struct(i32) {
    underline: bool = false,
    overline: bool = false,
    line_through: bool = false,
    _: u29 = 0,

    pub const none: TextDecorationType = .{};

    pub fn toC(self: TextDecorationType) c_int {
        return @bitCast(self);
    }
};

pub const TextDecoration = extern struct {
    types: TextDecorationType,
    color: color_mod.Color,
    style: TextDecorationStyle,
    thickness_multiplier: f32,

    pub fn toC(self: TextDecoration) c.ImpellerTextDecoration {
        return .{
            .types = self.types.toC(),
            .color = self.color.toC(),
            .style = self.style.toC(),
            .thickness_multiplier = self.thickness_multiplier,
        };
    }
};

pub const font_weights = struct {
    pub const thin = FontWeight.thin;
    pub const extra_light = FontWeight.extra_light;
    pub const light = FontWeight.light;
    pub const normal = FontWeight.normal;
    pub const medium = FontWeight.medium;
    pub const semi_bold = FontWeight.semi_bold;
    pub const bold = FontWeight.bold;
    pub const extra_bold = FontWeight.extra_bold;
    pub const black = FontWeight.black;
    pub const w100 = FontWeight.w100;
    pub const w200 = FontWeight.w200;
    pub const w300 = FontWeight.w300;
    pub const w400 = FontWeight.w400;
    pub const w500 = FontWeight.w500;
    pub const w600 = FontWeight.w600;
    pub const w700 = FontWeight.w700;
    pub const w800 = FontWeight.w800;
    pub const w900 = FontWeight.w900;
};

pub const font_styles = struct {
    pub const normal = FontStyle.normal;
    pub const italic = FontStyle.italic;
};

pub const text_alignments = struct {
    pub const left = TextAlignment.left;
    pub const right = TextAlignment.right;
    pub const center = TextAlignment.center;
    pub const justify = TextAlignment.justify;
    pub const start = TextAlignment.start;
    pub const end = TextAlignment.end;
};

pub const text_directions = struct {
    pub const rtl = TextDirection.rtl;
    pub const ltr = TextDirection.ltr;
};

pub const text_decoration_types = struct {
    pub const none = TextDecorationType.none;
    pub const underline: TextDecorationType = .{ .underline = true };
    pub const overline: TextDecorationType = .{ .overline = true };
    pub const line_through: TextDecorationType = .{ .line_through = true };
};

pub const text_decoration_styles = struct {
    pub const solid = TextDecorationStyle.solid;
    pub const double = TextDecorationStyle.double;
    pub const dotted = TextDecorationStyle.dotted;
    pub const dashed = TextDecorationStyle.dashed;
    pub const wavy = TextDecorationStyle.wavy;
};

pub const TypographyContext = struct {
    handle: c.ImpellerTypographyContext,

    /// Creates a typography context used for font registration and paragraph layout.
    pub fn init() Error!TypographyContext {
        const handle = c.ImpellerTypographyContextNew() orelse return Error.CreateTypographyContextFailed;
        return .{ .handle = handle };
    }

    /// Returns a retained typography context owner that must be deinitialized independently.
    pub fn clone(self: TypographyContext) TypographyContext {
        c.ImpellerTypographyContextRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this typography context reference.
    pub fn deinit(self: *TypographyContext) void {
        if (self.handle == null) return;
        c.ImpellerTypographyContextRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller typography context handle.
    pub fn raw(self: TypographyContext) c.ImpellerTypographyContext {
        return self.handle;
    }

    /// Registers a font from a caller-managed mapping.
    /// Its release callback may run after context destruction.
    pub fn registerFontMapping(
        self: TypographyContext,
        contents: Mapping,
        family_name_alias: ?[:0]const u8,
    ) Error!void {
        return self.registerFontMappingPtr(
            contents,
            if (family_name_alias) |alias| alias.ptr else null,
        );
    }

    /// Registers a font from a caller-managed mapping with an optional C string alias.
    /// Prefer `registerFontMapping()` unless a lower-level API already owns the pointer.
    pub fn registerFontMappingPtr(
        self: TypographyContext,
        contents: Mapping,
        family_name_alias: ?[*:0]const u8,
    ) Error!void {
        var local_contents = contents.value;
        if (!c.ImpellerTypographyContextRegisterFont(
            self.handle,
            &local_contents,
            contents.release_user_data,
            family_name_alias,
        )) {
            return Error.RegisterFontFailed;
        }
    }

    /// Registers a font borrowing bytes that must remain valid for all font use.
    pub fn registerFontBorrowed(
        self: TypographyContext,
        bytes: []const u8,
        family_name_alias: ?[:0]const u8,
    ) Error!void {
        return self.registerFontMapping(Mapping.borrowed(bytes), family_name_alias);
    }

    /// Registers a font borrowing bytes with an optional C string alias.
    /// Prefer `registerFontBorrowed()` unless a lower-level API already owns the pointer.
    pub fn registerFontBorrowedPtr(
        self: TypographyContext,
        bytes: []const u8,
        family_name_alias: ?[*:0]const u8,
    ) Error!void {
        return self.registerFontMappingPtr(Mapping.borrowed(bytes), family_name_alias);
    }

    /// Copies font bytes and transfers cleanup to Impeller on successful registration.
    /// The allocator must remain valid until the release callback has run.
    pub fn registerFontCopy(
        self: TypographyContext,
        allocator: std.mem.Allocator,
        bytes: []const u8,
        family_name_alias: ?[:0]const u8,
    ) Error!void {
        var owned = try OwnedMapping.copy(allocator, bytes);
        errdefer owned.deinit();

        try self.registerFontMapping(owned.mapping, family_name_alias);
        owned.releaseToImpeller();
    }

    /// Copies font bytes and registers them with an optional C string alias.
    /// Prefer `registerFontCopy()` unless a lower-level API already owns the pointer.
    pub fn registerFontCopyPtr(
        self: TypographyContext,
        allocator: std.mem.Allocator,
        bytes: []const u8,
        family_name_alias: ?[*:0]const u8,
    ) Error!void {
        var owned = try OwnedMapping.copy(allocator, bytes);
        errdefer owned.deinit();

        try self.registerFontMappingPtr(owned.mapping, family_name_alias);
        owned.releaseToImpeller();
    }
};

pub const ParagraphStyle = struct {
    handle: c.ImpellerParagraphStyle,

    /// Creates a paragraph style for text layout and rendering.
    pub fn init() Error!ParagraphStyle {
        const handle = c.ImpellerParagraphStyleNew() orelse return Error.CreateParagraphStyleFailed;
        return .{ .handle = handle };
    }

    /// Returns a retained paragraph style owner that must be deinitialized independently.
    pub fn clone(self: ParagraphStyle) ParagraphStyle {
        c.ImpellerParagraphStyleRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this paragraph style reference.
    pub fn deinit(self: *ParagraphStyle) void {
        if (self.handle == null) return;
        c.ImpellerParagraphStyleRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller paragraph style handle.
    pub fn raw(self: ParagraphStyle) c.ImpellerParagraphStyle {
        return self.handle;
    }

    /// Sets the paint used to fill glyphs.
    /// The style keeps the required state after the call returns.
    pub fn setForeground(self: ParagraphStyle, paint: Paint) void {
        c.ImpellerParagraphStyleSetForeground(self.handle, paint.handle);
    }

    /// Sets the paint used behind glyphs.
    /// The style keeps the required state after the call returns.
    pub fn setBackground(self: ParagraphStyle, paint: Paint) void {
        c.ImpellerParagraphStyleSetBackground(self.handle, paint.handle);
    }

    /// Sets the font weight used for glyph selection.
    pub fn setFontWeight(self: ParagraphStyle, weight: FontWeight) void {
        c.ImpellerParagraphStyleSetFontWeight(self.handle, weight.toC());
    }

    /// Sets whether glyphs should be upright or italic.
    pub fn setFontStyle(self: ParagraphStyle, style: FontStyle) void {
        c.ImpellerParagraphStyleSetFontStyle(self.handle, style.toC());
    }

    /// Sets the font family name.
    pub fn setFontFamily(self: ParagraphStyle, family_name: [:0]const u8) void {
        self.setFontFamilyPtr(family_name.ptr);
    }

    /// Sets the font family name from a C string pointer.
    /// Prefer `setFontFamily()` unless a lower-level API already owns the pointer.
    pub fn setFontFamilyPtr(self: ParagraphStyle, family_name: [*:0]const u8) void {
        c.ImpellerParagraphStyleSetFontFamily(self.handle, family_name);
    }

    /// Sets the font size in logical pixels.
    pub fn setFontSize(self: ParagraphStyle, size: f32) void {
        c.ImpellerParagraphStyleSetFontSize(self.handle, size);
    }

    /// Sets the line height multiplier.
    pub fn setHeight(self: ParagraphStyle, height: f32) void {
        c.ImpellerParagraphStyleSetHeight(self.handle, height);
    }

    /// Sets the horizontal text alignment.
    pub fn setTextAlignment(self: ParagraphStyle, text_align: TextAlignment) void {
        c.ImpellerParagraphStyleSetTextAlignment(self.handle, text_align.toC());
    }

    /// Sets the text direction.
    pub fn setTextDirection(self: ParagraphStyle, direction: TextDirection) void {
        c.ImpellerParagraphStyleSetTextDirection(self.handle, direction.toC());
    }

    /// Sets text decorations such as underline or strikethrough.
    pub fn setTextDecoration(self: ParagraphStyle, decoration: TextDecoration) void {
        var local_decoration = decoration.toC();
        c.ImpellerParagraphStyleSetTextDecoration(self.handle, &local_decoration);
    }

    /// Limits the number of visible lines in the paragraph.
    pub fn setMaxLines(self: ParagraphStyle, max_lines: u32) void {
        c.ImpellerParagraphStyleSetMaxLines(self.handle, max_lines);
    }

    /// Sets the locale used during paragraph layout.
    pub fn setLocale(self: ParagraphStyle, locale: [:0]const u8) void {
        self.setLocalePtr(locale.ptr);
    }

    /// Sets the locale used during paragraph layout from a C string pointer.
    /// Prefer `setLocale()` unless a lower-level API already owns the pointer.
    pub fn setLocalePtr(self: ParagraphStyle, locale: [*:0]const u8) void {
        c.ImpellerParagraphStyleSetLocale(self.handle, locale);
    }

    /// Sets the ellipsis string used when text is truncated.
    pub fn setEllipsis(self: ParagraphStyle, ellipsis: ?[:0]const u8) void {
        self.setEllipsisPtr(if (ellipsis) |value| value.ptr else null);
    }

    /// Sets the ellipsis string from a C string pointer.
    /// Prefer `setEllipsis()` unless a lower-level API already owns the pointer.
    pub fn setEllipsisPtr(self: ParagraphStyle, ellipsis: ?[*:0]const u8) void {
        c.ImpellerParagraphStyleSetEllipsis(self.handle, ellipsis);
    }
};

pub const ParagraphBuilder = struct {
    handle: c.ImpellerParagraphBuilder,

    /// Creates a paragraph builder associated with a typography context.
    pub fn init(context: TypographyContext) Error!ParagraphBuilder {
        const handle = c.ImpellerParagraphBuilderNew(context.handle) orelse return Error.CreateParagraphBuilderFailed;
        return .{ .handle = handle };
    }

    /// Returns a retained paragraph builder owner that must be deinitialized independently.
    pub fn clone(self: ParagraphBuilder) ParagraphBuilder {
        c.ImpellerParagraphBuilderRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this paragraph builder reference.
    pub fn deinit(self: *ParagraphBuilder) void {
        if (self.handle == null) return;
        c.ImpellerParagraphBuilderRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller paragraph builder handle.
    pub fn raw(self: ParagraphBuilder) c.ImpellerParagraphBuilder {
        return self.handle;
    }

    /// Pushes a paragraph style onto the style stack.
    pub fn pushStyle(self: ParagraphBuilder, style: ParagraphStyle) void {
        c.ImpellerParagraphBuilderPushStyle(self.handle, style.handle);
    }

    /// Pops the current paragraph style from the style stack.
    pub fn popStyle(self: ParagraphBuilder) void {
        c.ImpellerParagraphBuilderPopStyle(self.handle);
    }

    /// Appends UTF-8 text using the current style.
    pub fn addText(self: ParagraphBuilder, text: []const u8) void {
        c.ImpellerParagraphBuilderAddText(self.handle, text.ptr, @intCast(text.len));
    }

    /// Lays out text within the specified width and returns an immutable paragraph.
    pub fn build(self: ParagraphBuilder, width: f32) Error!Paragraph {
        const handle = c.ImpellerParagraphBuilderBuildParagraphNew(self.handle, width) orelse return Error.CreateParagraphFailed;
        return .{ .handle = handle };
    }
};

pub const Paragraph = struct {
    handle: c.ImpellerParagraph,

    /// Returns a retained paragraph owner that must be deinitialized independently.
    pub fn clone(self: Paragraph) Paragraph {
        c.ImpellerParagraphRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this paragraph reference.
    pub fn deinit(self: *Paragraph) void {
        if (self.handle == null) return;
        c.ImpellerParagraphRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller paragraph handle.
    pub fn raw(self: Paragraph) c.ImpellerParagraph {
        return self.handle;
    }

    /// Returns the layout width used for the paragraph.
    pub fn getMaxWidth(self: Paragraph) f32 {
        return c.ImpellerParagraphGetMaxWidth(self.handle);
    }

    /// Returns the total paragraph height.
    pub fn getHeight(self: Paragraph) f32 {
        return c.ImpellerParagraphGetHeight(self.handle);
    }

    /// Returns the width of the longest visible line.
    pub fn getLongestLineWidth(self: Paragraph) f32 {
        return c.ImpellerParagraphGetLongestLineWidth(self.handle);
    }

    /// Returns the actual width of the laid out paragraph.
    pub fn getMinIntrinsicWidth(self: Paragraph) f32 {
        return c.ImpellerParagraphGetMinIntrinsicWidth(self.handle);
    }

    /// Returns the width needed without line breaking.
    pub fn getMaxIntrinsicWidth(self: Paragraph) f32 {
        return c.ImpellerParagraphGetMaxIntrinsicWidth(self.handle);
    }

    /// Returns the ideographic baseline of the first line.
    pub fn getIdeographicBaseline(self: Paragraph) f32 {
        return c.ImpellerParagraphGetIdeographicBaseline(self.handle);
    }

    /// Returns the alphabetic baseline of the first line.
    pub fn getAlphabeticBaseline(self: Paragraph) f32 {
        return c.ImpellerParagraphGetAlphabeticBaseline(self.handle);
    }

    /// Returns the number of visible lines.
    pub fn getLineCount(self: Paragraph) u32 {
        return c.ImpellerParagraphGetLineCount(self.handle);
    }

    /// Returns the UTF-16 code unit range for the word at the given index.
    pub fn getWordBoundary(self: Paragraph, code_unit_index: usize) Range {
        var range: c.ImpellerRange = undefined;
        c.ImpellerParagraphGetWordBoundary(self.handle, code_unit_index, &range);
        return Range.fromC(range);
    }

    /// Returns cached line metrics for this paragraph.
    pub fn getLineMetrics(self: Paragraph) Error!LineMetrics {
        const handle = c.ImpellerParagraphGetLineMetrics(self.handle) orelse return Error.CreateLineMetricsFailed;
        return .{ .handle = handle };
    }

    /// Returns glyph information for the glyph nearest the UTF-16 code unit index.
    pub fn createGlyphInfoAtCodeUnitIndex(self: Paragraph, code_unit_index: usize) Error!GlyphInfo {
        const handle = c.ImpellerParagraphCreateGlyphInfoAtCodeUnitIndexNew(self.handle, code_unit_index) orelse return Error.CreateGlyphInfoFailed;
        return .{ .handle = handle };
    }

    /// Returns glyph information for the glyph nearest the given paragraph coordinates.
    pub fn createGlyphInfoAtParagraphCoordinates(self: Paragraph, x: f64, y: f64) Error!GlyphInfo {
        const handle = c.ImpellerParagraphCreateGlyphInfoAtParagraphCoordinatesNew(self.handle, x, y) orelse return Error.CreateGlyphInfoFailed;
        return .{ .handle = handle };
    }
};

pub const LineMetrics = struct {
    handle: c.ImpellerLineMetrics,

    /// Returns a retained line metrics owner that must be deinitialized independently.
    pub fn clone(self: LineMetrics) LineMetrics {
        c.ImpellerLineMetricsRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this line metrics reference.
    pub fn deinit(self: *LineMetrics) void {
        if (self.handle == null) return;
        c.ImpellerLineMetricsRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller line metrics handle.
    pub fn raw(self: LineMetrics) c.ImpellerLineMetrics {
        return self.handle;
    }

    /// Returns the unscaled ascent for the specified line.
    pub fn getUnscaledAscent(self: LineMetrics, line: usize) f64 {
        return c.ImpellerLineMetricsGetUnscaledAscent(self.handle, line);
    }

    /// Returns the ascent for the specified line.
    pub fn getAscent(self: LineMetrics, line: usize) f64 {
        return c.ImpellerLineMetricsGetAscent(self.handle, line);
    }

    /// Returns the descent for the specified line.
    pub fn getDescent(self: LineMetrics, line: usize) f64 {
        return c.ImpellerLineMetricsGetDescent(self.handle, line);
    }

    /// Returns the baseline y coordinate for the specified line.
    pub fn getBaseline(self: LineMetrics, line: usize) f64 {
        return c.ImpellerLineMetricsGetBaseline(self.handle, line);
    }

    /// Returns whether the specified line ends with an explicit hard break.
    pub fn isHardbreak(self: LineMetrics, line: usize) bool {
        return c.ImpellerLineMetricsIsHardbreak(self.handle, line);
    }

    /// Returns the width of the specified line.
    pub fn getWidth(self: LineMetrics, line: usize) f64 {
        return c.ImpellerLineMetricsGetWidth(self.handle, line);
    }

    /// Returns the height of the specified line.
    pub fn getHeight(self: LineMetrics, line: usize) f64 {
        return c.ImpellerLineMetricsGetHeight(self.handle, line);
    }

    /// Returns the left edge x coordinate of the specified line.
    pub fn getLeft(self: LineMetrics, line: usize) f64 {
        return c.ImpellerLineMetricsGetLeft(self.handle, line);
    }

    /// Returns the UTF-16 start index of the specified line.
    pub fn getCodeUnitStartIndex(self: LineMetrics, line: usize) usize {
        return c.ImpellerLineMetricsGetCodeUnitStartIndex(self.handle, line);
    }

    /// Returns the UTF-16 end index of the specified line.
    pub fn getCodeUnitEndIndex(self: LineMetrics, line: usize) usize {
        return c.ImpellerLineMetricsGetCodeUnitEndIndex(self.handle, line);
    }

    /// Returns the UTF-16 end index of the specified line excluding trailing whitespace.
    pub fn getCodeUnitEndIndexExcludingWhitespace(self: LineMetrics, line: usize) usize {
        return c.ImpellerLineMetricsGetCodeUnitEndIndexExcludingWhitespace(self.handle, line);
    }

    /// Returns the UTF-16 end index of the specified line including a trailing newline.
    pub fn getCodeUnitEndIndexIncludingNewline(self: LineMetrics, line: usize) usize {
        return c.ImpellerLineMetricsGetCodeUnitEndIndexIncludingNewline(self.handle, line);
    }
};

pub const GlyphInfo = struct {
    handle: c.ImpellerGlyphInfo,

    /// Returns a retained glyph info owner that must be deinitialized independently.
    pub fn clone(self: GlyphInfo) GlyphInfo {
        c.ImpellerGlyphInfoRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this glyph info reference.
    pub fn deinit(self: *GlyphInfo) void {
        if (self.handle == null) return;
        c.ImpellerGlyphInfoRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller glyph info handle.
    pub fn raw(self: GlyphInfo) c.ImpellerGlyphInfo {
        return self.handle;
    }

    /// Returns the UTF-16 start index of the grapheme cluster.
    pub fn getGraphemeClusterCodeUnitRangeBegin(self: GlyphInfo) usize {
        return c.ImpellerGlyphInfoGetGraphemeClusterCodeUnitRangeBegin(self.handle);
    }

    /// Returns the UTF-16 end index of the grapheme cluster.
    pub fn getGraphemeClusterCodeUnitRangeEnd(self: GlyphInfo) usize {
        return c.ImpellerGlyphInfoGetGraphemeClusterCodeUnitRangeEnd(self.handle);
    }

    /// Returns the grapheme cluster bounds in paragraph coordinates.
    pub fn getGraphemeClusterBounds(self: GlyphInfo) Rect {
        var bounds: c.ImpellerRect = undefined;
        c.ImpellerGlyphInfoGetGraphemeClusterBounds(self.handle, &bounds);
        return Rect.fromC(bounds);
    }

    /// Returns whether this glyph info refers to an ellipsis glyph.
    pub fn isEllipsis(self: GlyphInfo) bool {
        return c.ImpellerGlyphInfoIsEllipsis(self.handle);
    }

    /// Returns the direction of the run containing this glyph.
    pub fn getTextDirection(self: GlyphInfo) TextDirection {
        return TextDirection.fromC(c.ImpellerGlyphInfoGetTextDirection(self.handle));
    }
};
