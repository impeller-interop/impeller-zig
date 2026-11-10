const std = @import("std");
const builtin = @import("builtin");
const impeller = @import("impeller");
const draw = @import("draw");
const glfw = @import("glfw_c");

pub fn run(_: std.process.Init) !void {
    _ = glfw.glfwSetErrorCallback(glfwErrorCallback);

    if (builtin.os.tag == .linux) {
        glfw.glfwInitHint(glfw.GLFW_PLATFORM, glfw.GLFW_PLATFORM_X11);
    }

    if (glfw.glfwInit() != glfw.GLFW_TRUE) {
        return error.GlfwInitFailed;
    }
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);
    if (builtin.os.tag == .macos) {
        glfw.glfwWindowHint(glfw.GLFW_COCOA_RETINA_FRAMEBUFFER, glfw.GLFW_TRUE);
    }

    const width: c_int = @intCast(draw.canvas_width);
    const height: c_int = @intCast(draw.canvas_height);
    const window = glfw.glfwCreateWindow(width, height, "Impeller + GLFW", null, null) orelse {
        return error.WindowCreateFailed;
    };
    defer glfw.glfwDestroyWindow(window);

    if (builtin.os.tag == .macos) {
        try runMetal(window);
    } else {
        try runVulkan(window);
    }
}

fn runVulkan(window: *glfw.GLFWwindow) !void {
    if (glfw.glfwVulkanSupported() != glfw.GLFW_TRUE) {
        return error.VulkanUnavailable;
    }

    var context = try impeller.Context.initVulkan(.{
        .user_data = null,
        .proc_address_callback = VulkanProcResolver.resolve,
        .enable_validation = false,
    });
    defer context.deinit();

    const vulkan_info = context.vulkanInfo() orelse return error.VulkanInfoUnavailable;

    if (glfw.glfwGetPhysicalDevicePresentationSupport(
        @ptrCast(vulkan_info.vk_instance),
        @ptrCast(vulkan_info.vk_physical_device),
        vulkan_info.graphics_queue_family_index,
    ) != glfw.GLFW_TRUE) {
        return error.PresentationUnsupported;
    }

    var vulkan_surface: glfw.VkSurfaceKHR = null;
    if (glfw.glfwCreateWindowSurface(@ptrCast(vulkan_info.vk_instance), window, null, &vulkan_surface) != 0) {
        return error.SurfaceCreateFailed;
    }
    var swapchain = try impeller.VulkanSwapchain.init(context, @ptrCast(vulkan_surface));
    defer swapchain.deinit();

    var scene = try draw.createScene(context, "GLFW");
    defer scene.deinit();

    while (glfw.glfwWindowShouldClose(window) == glfw.GLFW_FALSE) {
        glfw.glfwPollEvents();
        if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
            glfw.glfwSetWindowShouldClose(window, glfw.GLFW_TRUE);
        }

        var fb_width: c_int = 0;
        var fb_height: c_int = 0;
        glfw.glfwGetFramebufferSize(window, &fb_width, &fb_height);
        if (fb_width <= 0 or fb_height <= 0) continue;

        var surface = swapchain.acquireNextSurface() catch continue;
        defer surface.deinit();

        try draw.drawScene(surface, scene, .{
            .width = @intCast(fb_width),
            .height = @intCast(fb_height),
        });
        try surface.present();
    }
}

fn runMetal(window: *glfw.GLFWwindow) !void {
    const view = glfwGetCocoaView(window) orelse return error.MetalViewUnavailable;

    var scale_x: f32 = 1.0;
    var scale_y: f32 = 1.0;
    glfw.glfwGetWindowContentScale(window, &scale_x, &scale_y);

    const layer = metalLayerFromView(view, @floatCast(scale_x)) orelse return error.MetalLayerUnavailable;
    defer metalLayerDestroy(layer);

    var context = try impeller.Context.initMetal();
    defer context.deinit();

    var scene = try draw.createScene(context, "GLFW");
    defer scene.deinit();

    while (glfw.glfwWindowShouldClose(window) == glfw.GLFW_FALSE) {
        glfw.glfwPollEvents();
        if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS) {
            glfw.glfwSetWindowShouldClose(window, glfw.GLFW_TRUE);
        }

        var fb_width: c_int = 0;
        var fb_height: c_int = 0;
        glfw.glfwGetFramebufferSize(window, &fb_width, &fb_height);
        if (fb_width <= 0 or fb_height <= 0) continue;

        const drawable = metalAcquireDrawable(
            layer,
            @floatFromInt(fb_width),
            @floatFromInt(fb_height),
        ) orelse continue;
        defer metalReleaseDrawable(drawable);

        var surface = try impeller.Surface.wrapMetalDrawable(context, drawable);
        defer surface.deinit();

        try draw.drawScene(surface, scene, .{
            .width = @intCast(fb_width),
            .height = @intCast(fb_height),
        });
        try surface.present();
    }
}

const VulkanProcResolver = struct {
    fn resolve(instance: ?*anyopaque, proc_name: [*c]const u8, user_data: ?*anyopaque) callconv(.c) ?*anyopaque {
        _ = user_data;
        return @ptrCast(@constCast(glfw.glfwGetInstanceProcAddress(
            if (instance) |handle| @ptrCast(handle) else null,
            proc_name,
        )));
    }
};

fn glfwErrorCallback(code: c_int, description: [*c]const u8) callconv(.c) void {
    std.debug.print("GLFW error ({d}): {s}\n", .{ code, std.mem.span(description) });
}

extern fn glfwGetCocoaView(window: ?*glfw.GLFWwindow) ?*anyopaque;
extern fn metalLayerFromView(view: ?*anyopaque, scale: f64) ?*anyopaque;
extern fn metalLayerDestroy(layer: ?*anyopaque) void;
extern fn metalAcquireDrawable(layer: ?*anyopaque, width: f64, height: f64) ?*anyopaque;
extern fn metalReleaseDrawable(drawable: ?*anyopaque) void;
