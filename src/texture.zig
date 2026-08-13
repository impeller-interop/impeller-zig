const std = @import("std");
const c = @import("impeller_c");
const Error = @import("errors.zig").Error;
const Context = @import("context.zig").Context;
const ISize = @import("geometry.zig").ISize;
const Mapping = @import("mapping.zig").Mapping;
const OwnedMapping = @import("mapping.zig").OwnedMapping;

pub const TextureHandle = c.ImpellerTexture;

pub const PixelFormat = enum(c.ImpellerPixelFormat) {
    rgba8888 = c.kImpellerPixelFormatRGBA8888,

    pub fn fromC(value: c.ImpellerPixelFormat) error{InvalidEnumTag}!PixelFormat {
        return std.enums.fromInt(PixelFormat, value) orelse error.InvalidEnumTag;
    }

    pub fn toC(self: PixelFormat) c.ImpellerPixelFormat {
        return @intFromEnum(self);
    }
};

pub const Sampling = enum(c.ImpellerTextureSampling) {
    nearest_neighbor = c.kImpellerTextureSamplingNearestNeighbor,
    linear = c.kImpellerTextureSamplingLinear,

    pub fn toC(self: Sampling) c.ImpellerTextureSampling {
        return @intFromEnum(self);
    }
};

pub const Descriptor = extern struct {
    pixel_format: PixelFormat,
    size: ISize,
    mip_count: u32,

    /// Creates a descriptor for tightly packed textures.
    pub fn init(pixel_format: PixelFormat, size: ISize, mip_count: u32) Descriptor {
        return .{ .pixel_format = pixel_format, .size = size, .mip_count = mip_count };
    }

    pub fn toC(self: Descriptor) c.ImpellerTextureDescriptor {
        return .{
            .pixel_format = self.pixel_format.toC(),
            .size = self.size.toC(),
            .mip_count = self.mip_count,
        };
    }
};

/// Creates a texture descriptor for tightly packed textures.
pub fn createDescriptor(pixel_format: PixelFormat, size: ISize, mip_count: u32) Descriptor {
    return Descriptor.init(pixel_format, size, mip_count);
}

pub const Texture = struct {
    handle: c.ImpellerTexture,

    /// Creates a texture from a caller-managed mapping.
    /// The release callback may run on a background thread.
    pub fn initWithMapping(context: Context, descriptor: Descriptor, contents: Mapping) Error!Texture {
        var local_descriptor = descriptor.toC();
        var local_contents = contents.value;
        const handle = c.ImpellerTextureCreateWithContentsNew(
            context.handle,
            &local_descriptor,
            &local_contents,
            contents.release_user_data,
        ) orelse return Error.CreateTextureFailed;
        return .{ .handle = handle };
    }

    /// Creates a texture from borrowed tightly packed, decompressed pixel bytes.
    /// The bytes must remain valid until Impeller has finished any deferred upload.
    pub fn initWithBorrowedBytes(context: Context, descriptor: Descriptor, bytes: []const u8) Error!Texture {
        return Texture.initWithMapping(context, descriptor, Mapping.borrowed(bytes));
    }

    /// Copies tightly packed, decompressed pixel bytes and transfers cleanup to Impeller.
    /// The allocator must remain valid until the release callback has run.
    pub fn initWithBytesCopy(
        context: Context,
        descriptor: Descriptor,
        allocator: std.mem.Allocator,
        bytes: []const u8,
    ) Error!Texture {
        var owned = try OwnedMapping.copy(allocator, bytes);
        errdefer owned.deinit();

        const texture = try Texture.initWithMapping(context, descriptor, owned.mapping);
        owned.releaseToImpeller();
        return texture;
    }

    /// Adopts an existing OpenGL texture handle.
    pub fn initWithOpenGLTextureHandle(context: Context, descriptor: Descriptor, handle: u64) Error!Texture {
        var local_descriptor = descriptor.toC();
        const texture = c.ImpellerTextureCreateWithOpenGLTextureHandleNew(context.handle, &local_descriptor, handle) orelse return Error.CreateTextureFailed;
        return .{ .handle = texture };
    }

    /// Returns a retained texture owner that must be deinitialized independently.
    pub fn clone(self: Texture) Texture {
        c.ImpellerTextureRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this texture reference.
    pub fn deinit(self: *Texture) void {
        if (self.handle == null) return;
        c.ImpellerTextureRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller texture handle.
    pub fn raw(self: Texture) c.ImpellerTexture {
        return self.handle;
    }

    /// Returns the backing OpenGL texture name when available.
    pub fn getOpenGLHandle(self: Texture) u64 {
        return c.ImpellerTextureGetOpenGLHandle(self.handle);
    }
};

pub fn handlesFromSlice(allocator: std.mem.Allocator, textures: []const Texture) ![]TextureHandle {
    const handles = try allocator.alloc(TextureHandle, textures.len);
    for (textures, 0..) |texture, index| {
        handles[index] = texture.handle;
    }
    return handles;
}
