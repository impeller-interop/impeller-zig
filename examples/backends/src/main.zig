const std = @import("std");
const backend = @import("backend");

pub fn main(init: std.process.Init) !void {
    return backend.run(init);
}
