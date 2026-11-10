const std = @import("std");
const builtin = @import("builtin");
const impeller = @import("impeller");
const sdl3 = @import("sdl3");
const build_options = @import("build_options");

const title: [:0]const u8 = if (std.mem.eql(u8, build_options.shader, "planet")) "Impeller planet" else "Impeller liquid glass";

const shader_bytes = if (std.mem.eql(u8, build_options.shader, "planet"))
    @embedFile("shaders/planet.iplr")
else
    @embedFile("shaders/liquid_glass.iplr");

const canvas_width = 960;
const canvas_height = 640;

const ShaderUniforms = extern struct {
    resolution: [2]f32,
    time: f32,
};

const SurfaceSize = struct {
    width: usize,
    height: usize,
};

const Scene = struct {
    fragment_program: impeller.FragmentProgram,

    fn deinit(self: *Scene) void {
        self.fragment_program.deinit();
    }
};

fn createScene(context: impeller.Context, platform_name: []const u8) !Scene {
    _ = context;
    _ = platform_name;
    return .{
        .fragment_program = try impeller.FragmentProgram.initBorrowed(shader_bytes),
    };
}

fn drawScene(
    surface: impeller.Surface,
    context: impeller.Context,
    scene: Scene,
    surface_size: SurfaceSize,
    elapsed_seconds: f32,
) !void {
    std.debug.assert(surface_size.width > 0);
    std.debug.assert(surface_size.height > 0);

    const width: f32 = @floatFromInt(surface_size.width);
    const height: f32 = @floatFromInt(surface_size.height);
    const uniforms = ShaderUniforms{
        .resolution = .{ width, height },
        .time = elapsed_seconds,
    };

    var color_source = try impeller.ColorSource.initFragmentProgram(
        std.heap.page_allocator,
        context,
        scene.fragment_program,
        &.{},
        std.mem.asBytes(&uniforms),
    );
    defer color_source.deinit();

    var paint = try impeller.Paint.init();
    defer paint.deinit();
    paint.setColorSource(color_source);

    var builder = try impeller.DisplayListBuilder.init(impeller.rect(0.0, 0.0, width, height));
    defer builder.deinit();
    builder.drawRect(impeller.rect(0.0, 0.0, width, height), paint);

    var display_list = try builder.build();
    defer display_list.deinit();
    try surface.draw(display_list);
}

pub fn run(_: std.process.Init) !void {
    defer sdl3.shutdown();

    const init_flags = sdl3.InitFlags{ .video = true };
    if (builtin.os.tag == .linux) {
        try sdl3.hints.setWithPriority(.video_driver, "x11", .override);
    }
    try sdl3.init(init_flags);
    defer sdl3.quit(init_flags);

    const window = if (builtin.os.tag == .macos)
        try sdl3.video.Window.init(title, canvas_width, canvas_height, .{
            .metal = true,
            .resizable = true,
            .high_pixel_density = true,
        })
    else
        try sdl3.video.Window.init(title, canvas_width, canvas_height, .{
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

    var scene = try createScene(context, build_options.shader);
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

        var width: c_int = 0;
        var height: c_int = 0;
        _ = sdl3.c.SDL_GetWindowSizeInPixels(window.value, &width, &height);
        if (width <= 0 or height <= 0) continue;

        var surface = swapchain.acquireNextSurface() catch continue;
        defer surface.deinit();

        try drawScene(surface, context, scene, .{
            .width = @intCast(width),
            .height = @intCast(height),
        }, elapsedSeconds());
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

    var scene = try createScene(context, build_options.shader);
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

        try drawScene(surface, context, scene, .{
            .width = @intCast(width),
            .height = @intCast(height),
        }, elapsedSeconds());
        try surface.present();
    }
}

fn elapsedSeconds() f32 {
    return @as(f32, @floatFromInt(sdl3.c.SDL_GetTicks())) / 1000.0;
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
