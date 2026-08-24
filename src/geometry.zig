const std = @import("std");
const c = @import("impeller_c");

pub const Point = extern struct {
    x: f32,
    y: f32,

    pub fn fromC(value: c.ImpellerPoint) Point {
        return .{ .x = value.x, .y = value.y };
    }

    pub fn toC(self: Point) c.ImpellerPoint {
        return .{ .x = self.x, .y = self.y };
    }
};

pub const Size = extern struct {
    width: f32,
    height: f32,

    pub fn fromC(value: c.ImpellerSize) Size {
        return .{ .width = value.width, .height = value.height };
    }

    pub fn toC(self: Size) c.ImpellerSize {
        return .{ .width = self.width, .height = self.height };
    }
};

pub const ISize = extern struct {
    width: i64,
    height: i64,

    pub fn fromC(value: c.ImpellerISize) ISize {
        return .{ .width = value.width, .height = value.height };
    }

    pub fn toC(self: ISize) c.ImpellerISize {
        return .{ .width = self.width, .height = self.height };
    }
};

pub const Range = extern struct {
    start: u64,
    end: u64,

    pub fn fromC(value: c.ImpellerRange) Range {
        return .{ .start = value.start, .end = value.end };
    }
};

pub const Rect = extern struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub fn fromC(value: c.ImpellerRect) Rect {
        return .{
            .x = value.x,
            .y = value.y,
            .width = value.width,
            .height = value.height,
        };
    }

    pub fn toC(self: Rect) c.ImpellerRect {
        return .{
            .x = self.x,
            .y = self.y,
            .width = self.width,
            .height = self.height,
        };
    }
};

pub const Matrix = extern struct {
    m: [16]f32,

    pub fn fromC(value: c.ImpellerMatrix) Matrix {
        return .{ .m = value.m };
    }

    pub fn toC(self: Matrix) c.ImpellerMatrix {
        return .{ .m = self.m };
    }
};

pub const ColorMatrix = extern struct {
    m: [20]f32,

    pub fn toC(self: ColorMatrix) c.ImpellerColorMatrix {
        return .{ .m = self.m };
    }
};

pub const RoundingRadii = extern struct {
    top_left: Point,
    bottom_left: Point,
    top_right: Point,
    bottom_right: Point,

    pub fn toC(self: RoundingRadii) c.ImpellerRoundingRadii {
        return .{
            .top_left = self.top_left.toC(),
            .bottom_left = self.bottom_left.toC(),
            .top_right = self.top_right.toC(),
            .bottom_right = self.bottom_right.toC(),
        };
    }
};

/// Creates a rectangle value.
pub fn rect(x: f32, y: f32, width: f32, height: f32) Rect {
    return .{ .x = x, .y = y, .width = width, .height = height };
}

/// Creates a point value.
pub fn point(x: f32, y: f32) Point {
    return .{ .x = x, .y = y };
}

/// Creates equal x/y radii for every rounded-rectangle corner.
pub fn uniformRadii(radius: f32) RoundingRadii {
    const corner = point(radius, radius);
    return .{
        .top_left = corner,
        .bottom_left = corner,
        .top_right = corner,
        .bottom_right = corner,
    };
}

/// Creates a 4x5 color matrix value.
pub fn colorMatrix(values: [20]f32) ColorMatrix {
    return .{ .m = values };
}

/// Creates a pixel size value.
pub fn pixelSize(width: i64, height: i64) ISize {
    return .{ .width = width, .height = height };
}

comptime {
    assertSameLayout(Point, c.ImpellerPoint);
    assertSameLayout(Size, c.ImpellerSize);
    assertSameLayout(ISize, c.ImpellerISize);
    assertSameLayout(Range, c.ImpellerRange);
    assertSameLayout(Rect, c.ImpellerRect);
    assertSameLayout(Matrix, c.ImpellerMatrix);
    assertSameLayout(ColorMatrix, c.ImpellerColorMatrix);
}

fn assertSameLayout(comptime Wrapper: type, comptime Raw: type) void {
    std.debug.assert(@sizeOf(Wrapper) == @sizeOf(Raw));
    std.debug.assert(@alignOf(Wrapper) == @alignOf(Raw));
}

test "geometry round trips" {
    const point_value = Point{ .x = 1.5, .y = -2.5 };
    try std.testing.expectEqual(point_value, Point.fromC(point_value.toC()));

    const size_value = Size{ .width = 320.0, .height = 240.0 };
    try std.testing.expectEqual(size_value, Size.fromC(size_value.toC()));

    const pixel_size = ISize{ .width = -3, .height = 7 };
    try std.testing.expectEqual(pixel_size, ISize.fromC(pixel_size.toC()));

    const range_value = Range{ .start = 4, .end = 12 };
    try std.testing.expectEqual(range_value, Range.fromC(.{ .start = 4, .end = 12 }));

    const rect_value = rect(1.0, 2.0, 3.0, 4.0);
    try std.testing.expectEqual(rect_value, Rect.fromC(rect_value.toC()));

    const matrix_value = Matrix{ .m = [_]f32{1} ** 16 };
    try std.testing.expectEqual(matrix_value, Matrix.fromC(matrix_value.toC()));
}

test "geometry constructors" {
    try std.testing.expectEqual(ISize{ .width = 8, .height = 9 }, pixelSize(8, 9));
    try std.testing.expectEqual(
        RoundingRadii{
            .top_left = point(6.0, 6.0),
            .bottom_left = point(6.0, 6.0),
            .top_right = point(6.0, 6.0),
            .bottom_right = point(6.0, 6.0),
        },
        uniformRadii(6.0),
    );

    const values = [_]f32{0} ** 20;
    try std.testing.expectEqual(values, colorMatrix(values).m);
}

test "radii conversion" {
    const radii = RoundingRadii{
        .top_left = point(1.0, 2.0),
        .bottom_left = point(3.0, 4.0),
        .top_right = point(5.0, 6.0),
        .bottom_right = point(7.0, 8.0),
    };
    const converted = radii.toC();
    try std.testing.expectEqual(radii.top_left.toC(), converted.top_left);
    try std.testing.expectEqual(radii.bottom_right.toC(), converted.bottom_right);
}
