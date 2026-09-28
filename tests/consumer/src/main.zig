const std = @import("std");
const impeller = @import("impeller");

pub fn main() !void {
    var paint = try impeller.Paint.init();
    defer paint.deinit();

    paint.setColor(impeller.srgb(1.0, 0.2, 0.1, 1.0));

    var builder = try impeller.DisplayListBuilder.init(null);
    defer builder.deinit();
    builder.drawRect(impeller.rect(0.0, 0.0, 8.0, 8.0), paint);

    var list = try builder.build();
    defer list.deinit();

    std.debug.print("app ok: version={d}\n", .{impeller.version});
}
