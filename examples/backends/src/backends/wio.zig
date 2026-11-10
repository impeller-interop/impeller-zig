const std = @import("std");
const builtin = @import("builtin");
const wio = @import("wio");
const impeller = @import("impeller");
const draw = @import("draw");

const initial_size: wio.Size = .{ .width = draw.canvas_width, .height = draw.canvas_height };

pub fn run(init: std.process.Init) !void {
    try wio.init(.{
        .allocator = init.gpa,
        .io = init.io,
        .eventFn = wio.EventQueue.eventFn,
    });
    defer wio.deinit();

    var events: wio.EventQueue = .empty;
    defer events.deinit();

    var window = try wio.Window.create(.{
        .event_fn_data = &events,
        .title = "Impeller + wio",
        .app_id = "impeller-wio",
        .size = initial_size,
    });
    defer window.destroy();

    var app = try App.init(&window, initial_size);
    defer app.deinit();

    var visible = true;

    while (true) {
        while (events.pop()) |event| {
            switch (event) {
                .close => return,
                .visible => visible = true,
                .hidden => visible = false,
                .size_physical => |size| app.resize(size),
                else => {},
            }
        }

        if (visible and app.size.width > 0 and app.size.height > 0) {
            try app.renderFrame();
        } else {
            wio.wait(.{});
        }

        wio.update();
    }
}

const App = struct {
    context: impeller.Context,
    backend: Backend,
    scene: draw.Scene,
    size: wio.Size,
    frame: u64 = 0,

    const Backend = union(enum) {
        vulkan: impeller.VulkanSwapchain,
        metal: *anyopaque,
    };

    fn init(window: *wio.Window, size: wio.Size) !App {
        var context = try createContext();
        errdefer context.deinit();

        const backend: Backend = if (builtin.os.tag == .macos) blk: {
            const layer = metalLayerFromWindow(@ptrCast(window.backend.window)) orelse {
                return error.MetalLayerUnavailable;
            };
            break :blk .{ .metal = layer };
        } else blk: {
            const info = context.vulkanInfo() orelse return error.VulkanInfoUnavailable;
            const instance = info.vk_instance orelse return error.VulkanInfoUnavailable;

            var surface: u64 = undefined;
            try window.vkCreateSurface(@intFromPtr(instance), null, &surface);

            break :blk .{ .vulkan = try impeller.VulkanSwapchain.init(context, @ptrFromInt(surface)) };
        };
        errdefer destroyBackendValue(backend);

        var scene = try draw.createScene(context, "wio");
        errdefer scene.deinit();

        return .{
            .context = context,
            .backend = backend,
            .scene = scene,
            .size = size,
        };
    }

    fn deinit(self: *App) void {
        self.scene.deinit();
        self.destroyBackend();
        self.context.deinit();
    }

    fn destroyBackend(self: *App) void {
        destroyBackendValue(self.backend);
    }

    fn resize(self: *App, size: wio.Size) void {
        self.size = size;
    }

    fn renderFrame(self: *App) !void {
        if (builtin.os.tag == .macos) {
            switch (self.backend) {
                .metal => |layer| {
                    const width: f64 = @floatFromInt(self.size.width);
                    const height: f64 = @floatFromInt(self.size.height);
                    const drawable = metalAcquireDrawable(layer, width, height) orelse return;
                    defer metalReleaseDrawable(drawable);

                    var surface = try impeller.Surface.wrapMetalDrawable(self.context, drawable);
                    defer surface.deinit();

                    try self.drawScene(surface);
                    try surface.present();
                },
                .vulkan => unreachable,
            }
        } else {
            switch (self.backend) {
                .vulkan => |*swapchain| {
                    var surface = swapchain.acquireNextSurface() catch return;
                    defer surface.deinit();

                    try self.drawScene(surface);
                    try surface.present();
                },
                .metal => unreachable,
            }
        }

        if (self.frame == 0) {
            std.log.info("first Impeller frame presented ({d}x{d})", .{
                self.size.width,
                self.size.height,
            });
        }
        self.frame += 1;
    }

    fn drawScene(self: *App, surface: impeller.Surface) !void {
        try draw.drawScene(surface, self.scene, .{
            .width = self.size.width,
            .height = self.size.height,
        });
    }
};

fn destroyBackendValue(backend: App.Backend) void {
    if (builtin.os.tag == .macos) {
        switch (backend) {
            .metal => |layer| metalLayerDestroy(layer),
            .vulkan => unreachable,
        }
    } else {
        switch (backend) {
            .vulkan => |swapchain| {
                var value = swapchain;
                value.deinit();
            },
            .metal => unreachable,
        }
    }
}

fn createContext() !impeller.Context {
    if (builtin.os.tag == .macos) {
        return impeller.Context.initMetal();
    }

    return impeller.Context.initVulkan(.{
        .user_data = null,
        .proc_address_callback = vulkanProc,
        .enable_validation = false,
    });
}

fn vulkanProc(
    instance: ?*anyopaque,
    proc_name: [*c]const u8,
    user_data: ?*anyopaque,
) callconv(.c) ?*anyopaque {
    _ = user_data;
    if (proc_name == null) return null;

    const handle: usize = if (instance) |value| @intFromPtr(value) else 0;
    const proc = wio.vkGetInstanceProcAddr(handle, @ptrCast(proc_name)) orelse return null;
    return @ptrCast(@constCast(proc));
}

extern fn metalLayerFromWindow(window: ?*anyopaque) ?*anyopaque;
extern fn metalLayerDestroy(layer: ?*anyopaque) void;
extern fn metalAcquireDrawable(layer: ?*anyopaque, width: f64, height: f64) ?*anyopaque;
extern fn metalReleaseDrawable(drawable: ?*anyopaque) void;
