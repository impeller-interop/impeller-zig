const c = @import("impeller_c");
const Error = @import("errors.zig").Error;
const geometry = @import("geometry.zig");

const Point = geometry.Point;
const Rect = geometry.Rect;
const RoundingRadii = geometry.RoundingRadii;

pub const FillType = enum(c.ImpellerFillType) {
    non_zero = c.kImpellerFillTypeNonZero,
    odd = c.kImpellerFillTypeOdd,

    pub fn toC(self: FillType) c.ImpellerFillType {
        return @intFromEnum(self);
    }
};

pub const Path = struct {
    handle: c.ImpellerPath,

    /// Returns a retained path owner that must be deinitialized independently.
    pub fn clone(self: Path) Path {
        c.ImpellerPathRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this path reference.
    pub fn deinit(self: *Path) void {
        if (self.handle == null) return;
        c.ImpellerPathRelease(self.handle);
        self.handle = null;
    }

    /// Returns the conservative bounds of this path.
    pub fn getBounds(self: Path) Rect {
        var bounds: c.ImpellerRect = undefined;
        c.ImpellerPathGetBounds(self.handle, &bounds);
        return Rect.fromC(bounds);
    }

    /// Returns the underlying Impeller path handle.
    pub fn raw(self: Path) c.ImpellerPath {
        return self.handle;
    }
};

pub const Builder = struct {
    handle: c.ImpellerPathBuilder,

    /// Creates a new path builder.
    pub fn init() Error!Builder {
        const handle = c.ImpellerPathBuilderNew() orelse return Error.CreatePathBuilderFailed;
        return .{ .handle = handle };
    }

    /// Returns a retained path builder owner that must be deinitialized independently.
    pub fn clone(self: Builder) Builder {
        c.ImpellerPathBuilderRetain(self.handle);
        return .{ .handle = self.handle };
    }

    /// Releases this path builder reference.
    pub fn deinit(self: *Builder) void {
        if (self.handle == null) return;
        c.ImpellerPathBuilderRelease(self.handle);
        self.handle = null;
    }

    /// Returns the underlying Impeller path builder handle.
    pub fn raw(self: Builder) c.ImpellerPathBuilder {
        return self.handle;
    }

    /// Moves the current point to the specified location.
    pub fn moveTo(self: Builder, location: Point) void {
        var local_point = location.toC();
        c.ImpellerPathBuilderMoveTo(self.handle, &local_point);
    }

    /// Adds a line segment to the specified location.
    pub fn lineTo(self: Builder, location: Point) void {
        var local_point = location.toC();
        c.ImpellerPathBuilderLineTo(self.handle, &local_point);
    }

    /// Adds a quadratic curve to the specified end point.
    pub fn quadraticCurveTo(self: Builder, control_point: Point, end_point: Point) void {
        var local_control_point = control_point.toC();
        var local_end_point = end_point.toC();
        c.ImpellerPathBuilderQuadraticCurveTo(self.handle, &local_control_point, &local_end_point);
    }

    /// Adds a cubic curve to the specified end point.
    pub fn cubicCurveTo(self: Builder, control_point_1: Point, control_point_2: Point, end_point: Point) void {
        var local_control_point_1 = control_point_1.toC();
        var local_control_point_2 = control_point_2.toC();
        var local_end_point = end_point.toC();
        c.ImpellerPathBuilderCubicCurveTo(self.handle, &local_control_point_1, &local_control_point_2, &local_end_point);
    }

    /// Adds a rectangle to the path.
    pub fn addRect(self: Builder, rectangle: Rect) void {
        var local_rect = rectangle.toC();
        c.ImpellerPathBuilderAddRect(self.handle, &local_rect);
    }

    /// Adds an arc to the path.
    pub fn addArc(self: Builder, oval_bounds: Rect, start_angle_degrees: f32, end_angle_degrees: f32) void {
        var local_rect = oval_bounds.toC();
        c.ImpellerPathBuilderAddArc(self.handle, &local_rect, start_angle_degrees, end_angle_degrees);
    }

    /// Adds an oval to the path.
    pub fn addOval(self: Builder, oval_bounds: Rect) void {
        var local_rect = oval_bounds.toC();
        c.ImpellerPathBuilderAddOval(self.handle, &local_rect);
    }

    /// Adds a rounded rectangle to the path.
    pub fn addRoundedRect(self: Builder, rectangle: Rect, radii: RoundingRadii) void {
        var local_rect = rectangle.toC();
        var local_radii = radii.toC();
        c.ImpellerPathBuilderAddRoundedRect(self.handle, &local_rect, &local_radii);
    }

    /// Closes the current contour.
    pub fn close(self: Builder) void {
        c.ImpellerPathBuilderClose(self.handle);
    }

    /// Copies the current path without resetting the builder.
    pub fn copyPath(self: Builder, fill: FillType) Error!Path {
        const handle = c.ImpellerPathBuilderCopyPathNew(self.handle, fill.toC()) orelse return Error.CreatePathFailed;
        return .{ .handle = handle };
    }

    /// Takes the current path and resets the builder.
    pub fn takePath(self: Builder, fill: FillType) Error!Path {
        const handle = c.ImpellerPathBuilderTakePathNew(self.handle, fill.toC()) orelse return Error.CreatePathFailed;
        return .{ .handle = handle };
    }
};
