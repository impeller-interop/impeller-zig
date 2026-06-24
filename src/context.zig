const c = @import("impeller_c");
const Error = @import("errors.zig").Error;
const version = @import("version.zig");

pub const ProcAddressCallback = c.ImpellerProcAddressCallback;
pub const VulkanProcAddressCallback = c.ImpellerVulkanProcAddressCallback;
pub const VulkanSettings = c.ImpellerContextVulkanSettings;

pub const VulkanInfo = extern struct {
    vk_instance: ?*anyopaque,
    vk_physical_device: ?*anyopaque,
    vk_logical_device: ?*anyopaque,
    graphics_queue_family_index: u32,
    graphics_queue_index: u32,

    pub fn fromC(value: c.ImpellerContextVulkanInfo) VulkanInfo {
        return .{
            .vk_instance = value.vk_instance,
            .vk_physical_device = value.vk_physical_device,
            .vk_logical_device = value.vk_logical_device,
            .graphics_queue_family_index = value.graphics_queue_family_index,
            .graphics_queue_index = value.graphics_queue_index,
        };
    }
};

pub const Context = struct {
    handle: c.ImpellerContext,

    /// Creates a Vulkan Impeller context from user-provided Vulkan resolver settings.
    pub fn initVulkan(settings: VulkanSettings) Error!Context {
        try version.check();
        var local_settings = settings;
        const handle = c.ImpellerContextCreateVulkanNew(
            version.value,
            &local_settings,
        ) orelse return Error.CreateContextFailed;
        return .{ .handle = handle };
    }

    /// Creates a Metal Impeller context using the system default Metal device.
    pub fn initMetal() Error!Context {
        try version.check();
        const handle = c.ImpellerContextCreateMetalNew(version.value) orelse return Error.CreateContextFailed;
        return .{ .handle = handle };
    }

    /// Creates an OpenGL ES Impeller context using a GL procedure resolver.
    pub fn initOpenGLES(callback: ProcAddressCallback, user_data: ?*anyopaque) Error!Context {
        try version.check();
        const handle = c.ImpellerContextCreateOpenGLESNew(version.value, callback, user_data) orelse return Error.CreateContextFailed;
        return .{ .handle = handle };
    }

    /// Returns a retained context owner that must be deinitialized independently.
    pub fn clone(self: Context) Context {
        c.ImpellerContextRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this context reference.
    pub fn deinit(self: *Context) void {
        if (self.handle == null) return;
        c.ImpellerContextRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller context handle.
    pub fn raw(self: Context) c.ImpellerContext {
        return self.handle;
    }

    /// Reads Vulkan handles owned by this context.
    pub fn vulkanInfo(self: Context) ?VulkanInfo {
        var info: c.ImpellerContextVulkanInfo = undefined;
        if (!c.ImpellerContextGetVulkanInfo(self.handle, &info)) return null;
        return VulkanInfo.fromC(info);
    }
};
