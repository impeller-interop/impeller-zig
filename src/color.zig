const std = @import("std");
const c = @import("impeller_c");

pub const Space = enum(c.ImpellerColorSpace) {
    srgb = c.kImpellerColorSpaceSRGB,
    extended_srgb = c.kImpellerColorSpaceExtendedSRGB,
    display_p3 = c.kImpellerColorSpaceDisplayP3,

    pub fn fromC(value: c.ImpellerColorSpace) error{InvalidEnumTag}!Space {
        return std.enums.fromInt(Space, value) orelse error.InvalidEnumTag;
    }

    pub fn toC(self: Space) c.ImpellerColorSpace {
        return @intFromEnum(self);
    }
};

pub const Color = extern struct {
    red: f32,
    green: f32,
    blue: f32,
    alpha: f32,
    color_space: Space,

    pub fn toC(self: Color) c.ImpellerColor {
        return .{
            .red = self.red,
            .green = self.green,
            .blue = self.blue,
            .alpha = self.alpha,
            .color_space = self.color_space.toC(),
        };
    }
};

/// Creates an sRGB color value for Impeller drawing APIs.
pub fn srgb(red: f32, green: f32, blue: f32, alpha: f32) Color {
    return .{
        .red = red,
        .green = green,
        .blue = blue,
        .alpha = alpha,
        .color_space = .srgb,
    };
}

pub const spaces = struct {
    pub const srgb = Space.srgb;
    pub const extended_srgb = Space.extended_srgb;
    pub const display_p3 = Space.display_p3;
};

comptime {
    std.debug.assert(@sizeOf(Color) == @sizeOf(c.ImpellerColor));
    std.debug.assert(@alignOf(Color) == @alignOf(c.ImpellerColor));
}

test "color round trips" {
    const colors = [_]Space{ .srgb, .extended_srgb, .display_p3 };
    for (colors) |space| {
        try std.testing.expectEqual(space, try Space.fromC(space.toC()));
    }

    const value = Color{
        .red = 0.1,
        .green = 0.2,
        .blue = 0.3,
        .alpha = 0.4,
        .color_space = .display_p3,
    };
    const converted = value.toC();
    try std.testing.expectEqual(value.red, converted.red);
    try std.testing.expectEqual(value.green, converted.green);
    try std.testing.expectEqual(value.blue, converted.blue);
    try std.testing.expectEqual(value.alpha, converted.alpha);
    try std.testing.expectEqual(value.color_space.toC(), converted.color_space);
}

test "color spaces" {
    try std.testing.expectEqual(Space.srgb, spaces.srgb);
    try std.testing.expectEqual(Space.extended_srgb, spaces.extended_srgb);
    try std.testing.expectEqual(Space.display_p3, spaces.display_p3);
}
