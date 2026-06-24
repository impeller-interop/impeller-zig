const c = @import("impeller_c");
const Error = @import("errors.zig").Error;

pub const value = c.IMPELLER_VERSION;
pub const variant = c.IMPELLER_VERSION_VARIANT;
pub const major = c.IMPELLER_VERSION_MAJOR;
pub const minor = c.IMPELLER_VERSION_MINOR;
pub const patch = c.IMPELLER_VERSION_PATCH;

/// Returns the linked Impeller runtime version.
pub fn runtime() u32 {
    return c.ImpellerGetVersion();
}

/// Packs Impeller version components into a single version value.
pub fn make(variant_value: u32, major_value: u32, minor_value: u32, patch_value: u32) u32 {
    return ((variant_value << 29) | (major_value << 22) | (minor_value << 12) | patch_value);
}

/// Returns the variant component from a packed Impeller version.
pub fn variantOf(version_value: u32) u32 {
    return version_value >> 29;
}

/// Returns the major component from a packed Impeller version.
pub fn majorOf(version_value: u32) u32 {
    return (version_value >> 22) & 0x7f;
}

/// Returns the minor component from a packed Impeller version.
pub fn minorOf(version_value: u32) u32 {
    return (version_value >> 12) & 0x3ff;
}

/// Returns the patch component from a packed Impeller version.
pub fn patchOf(version_value: u32) u32 {
    return version_value & 0xfff;
}

/// Verifies that the imported header version matches the linked runtime.
pub fn check() Error!void {
    if (runtime() != value) return Error.VersionMismatch;
}
