const std = @import("std");
const c = @import("impeller_c");
const Error = @import("errors.zig").Error;

pub const Callback = c.ImpellerCallback;

pub const Mapping = struct {
    value: c.ImpellerMapping,
    release_user_data: ?*anyopaque = null,

    /// Borrows bytes using the lifetime required by the receiving Impeller API.
    pub fn borrowed(bytes: []const u8) Mapping {
        return .{
            .value = .{
                .data = bytes.ptr,
                .length = bytes.len,
                .on_release = null,
            },
        };
    }

    /// Creates a low-level callback-backed mapping.
    /// Most callers should prefer borrowed mappings or OwnedMapping.copy().
    pub fn withRelease(
        bytes: []const u8,
        on_release: Callback,
        release_user_data: ?*anyopaque,
    ) Mapping {
        return .{
            .value = .{
                .data = bytes.ptr,
                .length = bytes.len,
                .on_release = on_release,
            },
            .release_user_data = release_user_data,
        };
    }
};

/// Owns copied mapping bytes until cleanup is transferred or deinitialized.
pub const OwnedMapping = struct {
    mapping: Mapping,
    release_state: ?*ReleaseState,

    const ReleaseState = struct {
        allocator: std.mem.Allocator,
        bytes: []u8,
    };

    /// Copies bytes into allocator-backed storage with callback-driven cleanup.
    /// The allocator must remain valid until the release callback has run.
    pub fn copy(allocator: std.mem.Allocator, bytes: []const u8) Error!OwnedMapping {
        const owned_bytes = try allocator.dupe(u8, bytes);
        errdefer allocator.free(owned_bytes);

        const release_state = try allocator.create(ReleaseState);
        release_state.* = .{
            .allocator = allocator,
            .bytes = owned_bytes,
        };

        return .{
            .mapping = Mapping.withRelease(owned_bytes, release, release_state),
            .release_state = release_state,
        };
    }

    /// Releases the copied bytes unless cleanup has been transferred.
    pub fn deinit(self: *OwnedMapping) void {
        const release_state = self.release_state orelse return;
        releaseOwnedBytes(release_state);
        self.release_state = null;
        self.mapping = Mapping.borrowed("");
    }

    /// Transfers cleanup responsibility after the receiving Impeller API succeeds.
    pub fn releaseToImpeller(self: *OwnedMapping) void {
        self.release_state = null;
        self.mapping = Mapping.borrowed("");
    }

    fn release(user_data: ?*anyopaque) callconv(.c) void {
        const data = user_data orelse return;
        const release_state: *ReleaseState = @ptrCast(@alignCast(data));
        releaseOwnedBytes(release_state);
    }

    fn releaseOwnedBytes(release_state: *ReleaseState) void {
        const allocator = release_state.allocator;
        allocator.free(release_state.bytes);
        allocator.destroy(release_state);
    }
};

test "mapping deinit" {
    var owned = try OwnedMapping.copy(std.testing.allocator, "impeller");
    owned.deinit();
    owned.deinit();

    try std.testing.expectEqual(@as(?*anyopaque, null), owned.release_state);
    try std.testing.expectEqual(@as(?*anyopaque, null), owned.mapping.value.on_release);
    try std.testing.expectEqual(@as(u64, 0), owned.mapping.value.length);
}

test "mapping transfer" {
    var owned = try OwnedMapping.copy(std.testing.allocator, "impeller");
    owned.releaseToImpeller();

    try std.testing.expectEqual(@as(?*anyopaque, null), owned.release_state);
    try std.testing.expectEqual(@as(?*anyopaque, null), owned.mapping.value.on_release);
    try std.testing.expectEqual(@as(u64, 0), owned.mapping.value.length);
}
