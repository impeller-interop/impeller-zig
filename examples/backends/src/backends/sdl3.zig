const std = @import("std");
const builtin = @import("builtin");
const impeller = @import("impeller");
const draw = @import("draw");
const sdl3 = @import("sdl3");

pub fn run(_: std.process.Init) !void {
    defer sdl3.shutdown();

    const init_flags = sdl3.InitFlags{ .video = true };
    if (builtin.os.tag == .linux) {
        try sdl3.hints.setWithPriority(.video_driver, "x11", .override);
    }
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

    const window_size = .{ .width = draw.canvas_width, .height = draw.canvas_height };
    const window = if (builtin.os.tag == .macos)
        try sdl3.video.Window.init("Impeller + SDL3", window_size.width, window_size.height, .{
            .metal = true,
            .resizable = true,
            .high_pixel_density = true,
        })
    else
        try sdl3.video.Window.init("Impeller + SDL3", window_size.width, window_size.height, .{
            .vulkan = true,
            .resizable = true,
            .high_pixel_density = true,
        });
    defer window.deinit();

    if (builtin.os.tag == .macos) {
        try runMetal(window);
    } else {
        try runVulkan(window);
    }
}

fn runVulkan(window: sdl3.video.Window) !void {
    var context = try impeller.Context.initVulkan(.{
        .user_data = null,
        .proc_address_callback = VulkanProcResolver.resolve,
        .enable_validation = false,
    });
    defer context.deinit();

    const vulkan_info = context.vulkanInfo() orelse return error.VulkanInfoUnavailable;

    if (!sdl3.vulkan.getPresentationSupport(
        @ptrCast(vulkan_info.vk_instance),
        @ptrCast(vulkan_info.vk_physical_device),
        vulkan_info.graphics_queue_family_index,
    )) {
        return error.PresentationUnsupported;
    }

    const vulkan_surface = try sdl3.vulkan.Surface.init(
        window,
        @ptrCast(vulkan_info.vk_instance),
        null,
    );
    var swapchain = try impeller.VulkanSwapchain.init(context, @ptrCast(vulkan_surface.surface));
    defer swapchain.deinit();

    var scene = try draw.createScene(context, "SDL3");
    defer scene.deinit();

    var quit = false;
    while (!quit) {
        while (sdl3.events.poll()) |event| {
            switch (event) {
                .quit, .terminating => quit = true,
                .key_down => |key| {
                    if (key.key == .escape) quit = true;
                },
                else => {},
            }
        }
        if (quit) break;

        if (window.getFlags().minimized) {
            sdl3.timer.delayMilliseconds(10);
            continue;
        }

        var width: c_int = 0;
        var height: c_int = 0;
        _ = sdl3.c.SDL_GetWindowSizeInPixels(window.value, &width, &height);
        if (width <= 0 or height <= 0) continue;

        var surface = swapchain.acquireNextSurface() catch continue;
        defer surface.deinit();

        try draw.drawScene(surface, scene, .{
            .width = @intCast(width),
            .height = @intCast(height),
        });
        try surface.present();
    }
}

fn runMetal(window: sdl3.video.Window) !void {
    const metal_view = sdl3.c.SDL_Metal_CreateView(window.value) orelse return error.MetalViewCreateFailed;
    defer sdl3.c.SDL_Metal_DestroyView(metal_view);

    const layer = metalConfigureLayer(sdl3.c.SDL_Metal_GetLayer(metal_view)) orelse {
        return error.MetalLayerUnavailable;
    };

    var context = try impeller.Context.initMetal();
    defer context.deinit();

    var scene = try draw.createScene(context, "SDL3");
    defer scene.deinit();

    var quit = false;
    while (!quit) {
        while (sdl3.events.poll()) |event| {
            switch (event) {
                .quit, .terminating => quit = true,
                .key_down => |key| {
                    if (key.key == .escape) quit = true;
                },
                else => {},
            }
        }
        if (quit) break;

        if (window.getFlags().minimized) {
            sdl3.timer.delayMilliseconds(10);
            continue;
        }

        var width: c_int = 0;
        var height: c_int = 0;
        _ = sdl3.c.SDL_GetWindowSizeInPixels(window.value, &width, &height);
        if (width <= 0 or height <= 0) continue;

        const drawable = metalAcquireDrawable(
            layer,
            @floatFromInt(width),
            @floatFromInt(height),
        ) orelse continue;
        defer metalReleaseDrawable(drawable);

        var surface = try impeller.Surface.wrapMetalDrawable(context, drawable);
        defer surface.deinit();

        try draw.drawScene(surface, scene, .{
            .width = @intCast(width),
            .height = @intCast(height),
        });
        try surface.present();
    }
}

const VulkanProcResolver = struct {
    fn resolve(instance: ?*anyopaque, proc_name: [*c]const u8, user_data: ?*anyopaque) callconv(.c) ?*anyopaque {
        _ = user_data;
        const GetProcAddr = *const fn (?*anyopaque, [*c]const u8) callconv(.c) ?*anyopaque;
        const get_proc_addr: GetProcAddr = @ptrCast(@alignCast(sdl3.vulkan.getVkGetInstanceProcAddr() catch return null));
        return get_proc_addr(instance, proc_name);
    }
};

extern fn metalConfigureLayer(layer: ?*anyopaque) ?*anyopaque;
extern fn metalAcquireDrawable(layer: ?*anyopaque, width: f64, height: f64) ?*anyopaque;
extern fn metalReleaseDrawable(drawable: ?*anyopaque) void;
