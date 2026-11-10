const std = @import("std");
const draw = @import("draw");

pub fn main(init: std.process.Init) !void {
    return draw.run(init);
}
