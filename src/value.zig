const std = @import("std");

pub const Value = struct {
    value: f64 = 0,

    const Self = @This();

    pub fn print(self: Self) void {
        std.debug.print("{d}", .{self.value});
    }
};
