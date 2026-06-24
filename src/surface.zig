const c = @import("impeller_c");
const Error = @import("errors.zig").Error;
const Context = @import("context.zig").Context;
const DisplayList = @import("display_list.zig").DisplayList;
const geometry = @import("geometry.zig");
const texture = @import("texture.zig");

const ISize = geometry.ISize;

pub const Surface = struct {
    handle: c.ImpellerSurface,

    /// Wraps an existing framebuffer object as an Impeller surface.
    pub fn wrapFBO(context: Context, fbo: u64, format: texture.PixelFormat, size: ISize) Error!Surface {
        var local_size = size.toC();
        const handle = c.ImpellerSurfaceCreateWrappedFBONew(context.handle, fbo, format.toC(), &local_size) orelse return Error.AcquireSurfaceFailed;
        return .{ .handle = handle };
    }

    /// Wraps an existing Metal drawable as an Impeller surface.
    pub fn wrapMetalDrawable(context: Context, metal_drawable: *anyopaque) Error!Surface {
        const handle = c.ImpellerSurfaceCreateWrappedMetalDrawableNew(context.handle, metal_drawable) orelse return Error.AcquireSurfaceFailed;
        return .{ .handle = handle };
    }

    /// Returns a retained surface owner that must be deinitialized independently.
    pub fn clone(self: Surface) Surface {
        c.ImpellerSurfaceRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this surface reference.
    pub fn deinit(self: *Surface) void {
        if (self.handle == null) return;
        c.ImpellerSurfaceRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller surface handle.
    pub fn raw(self: Surface) c.ImpellerSurface {
        return self.handle;
    }

    /// Draws a display list onto this surface.
    pub fn draw(self: Surface, display_list: DisplayList) Error!void {
        if (!c.ImpellerSurfaceDrawDisplayList(self.handle, display_list.handle)) return Error.DrawFailed;
    }

    /// Presents this surface to the window system.
    pub fn present(self: Surface) Error!void {
        if (!c.ImpellerSurfacePresent(self.handle)) return Error.PresentFailed;
    }
};

pub const VulkanSwapchain = struct {
    handle: c.ImpellerVulkanSwapchain,

    /// Creates a Vulkan swapchain and transfers VkSurfaceKHR ownership to Impeller.
    pub fn init(context: Context, vulkan_surface_khr: *anyopaque) Error!VulkanSwapchain {
        const handle = c.ImpellerVulkanSwapchainCreateNew(context.handle, vulkan_surface_khr) orelse return Error.CreateVulkanSwapchainFailed;
        return .{ .handle = handle };
    }

    /// Returns a retained Vulkan swapchain owner that must be deinitialized independently.
    pub fn clone(self: VulkanSwapchain) VulkanSwapchain {
        c.ImpellerVulkanSwapchainRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this Vulkan swapchain reference.
    pub fn deinit(self: *VulkanSwapchain) void {
        if (self.handle == null) return;
        c.ImpellerVulkanSwapchainRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller Vulkan swapchain handle.
    pub fn raw(self: VulkanSwapchain) c.ImpellerVulkanSwapchain {
        return self.handle;
    }

    /// Acquires the next renderable surface from this swapchain.
    pub fn acquireNextSurface(self: VulkanSwapchain) Error!Surface {
        const handle = c.ImpellerVulkanSwapchainAcquireNextSurfaceNew(self.handle) orelse return Error.AcquireSurfaceFailed;
        return .{ .handle = handle };
    }
};
