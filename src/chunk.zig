const std = @import("std");
const debug = std.debug;
const print = debug.print;
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const Opcode = @import("opcode.zig").Opcode;
const Value = @import("value.zig").Value;

const LineOffset = struct {
    offset: usize = 0,
    line: u32 = 0,
};

pub const Chunk = struct {
    code: ArrayList(u8),
    lines: ArrayList(LineOffset),
    constants: ArrayList(Value),

    const Self = @This();

    pub fn init(allocator: *Allocator) !Self {
        var code = try ArrayList(u8).initCapacity(allocator, 8);
        var lines = try ArrayList(LineOffset).initCapacity(allocator, 8);
        var constants = try ArrayList(Value).initCapacity(allocator, 8);
        return Self{
            .code = code,
            .lines = lines,
            .constants = constants,
        };
    }

    pub fn deinit(self: Self) void {
        self.code.deinit();
        self.lines.deinit();
        self.constants.deinit();
    }

    fn addLine(self: *Self, line: u32, len: usize) !void {
        // Check if the byte is on the same line.
        if (self.lines.items.len > 0 and self.lines.items[self.lines.items.len - 1].line == line) {
            return;
        }

        try self.lines.append(LineOffset{
            .offset = self.code.items.len - len,
            .line = line,
        });
    }

    fn addConstant(self: *Self, value: Value) !usize {
        try self.constants.append(value);
        return self.constants.items.len - 1;
    }

    pub fn writeByte(self: *Self, byte: u8, line: u32) !void {
        try self.code.append(byte);
        try self.addLine(line, 1);
    }

    pub fn writeBytes(self: *Self, bytes: []const u8, line: u32) !void {
        try self.code.appendSlice(bytes);
        try self.addLine(line, bytes.len);
    }

    pub fn writeOpcode(self: *Self, opcode: Opcode, line: u32) !void {
        try self.writeByte(@enumToInt(opcode), line);
    }

    pub fn writeConstant(self: *Self, value: Value, line: u32) !void {
        const index = try self.addConstant(value);

        if (0 <= index and index <= 0xff) {
            try self.writeOpcode(Opcode.CONSTANT, line);
            try self.writeByte(@intCast(u8, index), line);
        } else if (index <= 0xffffff) {
            const byte1 = @intCast(u8, index & 0xff);
            const byte2 = @intCast(u8, (index >> 8) & 0xff);
            const byte3 = @intCast(u8, (index >> 16) & 0xff);
            const bytes = [_]u8{ @enumToInt(Opcode.CONSTANT_LONG), byte1, byte2, byte3 };

            try self.writeBytes(&bytes, line);
        } else {
            unreachable;
        }
    }

    pub fn getLine(self: Self, offset: usize) u32 {
        var start: usize = 0;
        const lend: usize = self.lines.items.len - 1;
        var end: usize = lend;

        // Binary search which LineOffset contains the offset.
        while (true) {
            const mid = (start + end) / 2;
            const lineInfo = self.lines.items[mid];
            if (offset < lineInfo.offset) {
                end = mid - 1;
            } else if (mid == lend or offset < self.lines.items[mid + 1].offset) {
                return lineInfo.line;
            } else {
                start = mid + 1;
            }
        }
    }

    pub fn disassemble(self: Self, name: []const u8) void {
        print("== {s} ==\n", .{name});

        var offset: usize = 0;
        while (offset < self.code.items.len) {
            offset = self.disassembleInstruction(offset);
        }
    }

    pub fn disassembleInstruction(self: Self, offset: usize) usize {
        print("{x:0>4} ", .{offset});
        const line = self.getLine(offset);
        if (offset > 0 and line == self.getLine(offset - 1)) {
            print("   | ", .{});
        } else {
            print("{d:>4} ", .{line});
        }

        const opcode = @intToEnum(Opcode, self.code.items[offset]);
        return switch (opcode) {
            Opcode.CONSTANT => constantInstruction("OP_CONSTANT", self, offset),
            Opcode.CONSTANT_LONG => constantLongInstruction("OP_CONSTANT_LONG", self, offset),
            Opcode.RETURN => simpleInstruction("OP_RETURN", offset),
        };
    }

    pub fn printBytes(self: Self) void {
        print("Chunk: {any}", .{self.code.items});
    }
};

fn simpleInstruction(name: []const u8, offset: usize) usize {
    print("{s}\n", .{name});
    return offset + 1;
}

fn constantInstruction(name: []const u8, chunk: Chunk, offset: usize) usize {
    const index = chunk.code.items[offset + 1];
    print("{s} {d:>4} '", .{ name, index });
    const value = chunk.constants.items[index];
    value.print();
    print("'\n", .{});
    return offset + 2;
}

fn constantLongInstruction(name: []const u8, chunk: Chunk, offset: usize) usize {
    const byte1: usize = chunk.code.items[offset + 1];
    const byte2: usize = chunk.code.items[offset + 2];
    const byte3: usize = chunk.code.items[offset + 3];
    const index = byte1 | (byte2 << 8) | (byte3 << 16);
    print("{s} {d:>4} '", .{ name, index });

    const value = chunk.constants.items[index];
    value.print();
    print("'\n", .{});
    return offset + 4;
}
