const std = @import("std");
const c = @import("impeller_c");

pub const Space = enum(c.ImpellerColorSpace) {
    srgb = c.kImpellerColorSpaceSRGB,
    extended_srgb = c.kImpellerColorSpaceExtendedSRGB,
    display_p3 = c.kImpellerColorSpaceDisplayP3,

    pub fn fromC(value: c.ImpellerColorSpace) Space {
        return @enumFromInt(value);
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
