const std = @import("std");
const testing = std.testing;

const Chunk = @import("chunk.zig").Chunk;
const Opcode = @import("opcode.zig").Opcode;
const Value = @import("value.zig").Value;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var chunk = try Chunk.init(&arena.allocator);
    defer chunk.deinit();

    // const index = try chunk.addConstant(Value{ .value = 1.2 });
    // try chunk.writeOpcode(Opcode.CONSTANT, 123);
    // try chunk.writeConstant(index, 123);

    try chunk.writeConstant(Value{ .value = 1.2 }, 123);
    try chunk.writeOpcode(Opcode.RETURN, 123);

    chunk.disassemble("Test");
}
