const std = @import("std");

const CHALLENGE_BIN_SIZE = 60100;
const wordType = u16;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

    const buffer = try get_binary(allocator);
    defer {
        allocator.free(buffer);
    }

    const buffer_u16: [*]u16 = @ptrCast(buffer);

    try run(buffer_u16);
}

fn get_binary(allocator: std.mem.Allocator) ![]align(2) u8 {
    var is_success = false;

    const file = try std.fs.cwd().openFile("./challenge/challenge.bin", .{});

    const stat = try file.stat();
    const binarySize = stat.size;

    const buffer = try allocator.alignedAlloc(u8, 2, binarySize);
    defer {
        if (!is_success) {
            allocator.free(buffer);
        }
    }

    const bytes_read = file.readAll(buffer) catch |err| {
        std.debug.print("can't read the file: {!}", .{err});
        return err;
    };

    try std.testing.expect(bytes_read == binarySize);

    is_success = true;
    return buffer;
}

fn run(binary: [*]u16) !void {
    var pc: u16 = 0;
    var reg_state = [_]u16{ 0, 0, 0, 0, 0, 0, 0, 0 };

    while (true) {
        const op = binary[pc];
        pc += 1;

        // std.debug.print("op code {d}\n", .{op});

        switch (op) {
            // halt: 0
            0 => {
                return;
            },
            // jmp: 6 a
            6 => {
                pc = try read_value_at(binary, &reg_state, pc);
            },
            // jt: 7 a b
            7 => {
                const value = try read_value_at(binary, &reg_state, pc);
                if (value > 0) {
                    pc = try read_value_at(binary, &reg_state, pc + 1);
                } else {
                    pc += 2;
                }
            },
            // jf: 8 a b
            8 => {
                const value = try read_value_at(binary, &reg_state, pc);
                if (value == 0) {
                    pc = try read_value_at(binary, &reg_state, pc + 1);
                } else {
                    pc += 2;
                }
            },
            // out: 19 a
            19 => {
                const output_char: u8 = @truncate(try read_value_at(binary, &reg_state, pc));
                pc += 1;
                std.debug.print("{c}", .{output_char});
            },
            // noop: 21
            21 => {
                // noop;
            },
            else => {
                std.debug.print("Unsupported opcode {}\n", .{op});
                return;
            },
        }
    }
}

fn read_value_at(binary: [*]u16, reg_state: *[8]u16, pc: u16) !u16 {
    return read_value(binary, reg_state, binary[pc]);
}

fn read_value(binary: [*]u16, reg_state: *[8]u16, value: u16) !u16 {
    if (value < 32768) {
        return value;
    }
    if (value < 32776) {
        return read_value(binary, reg_state, reg_state.*[value - 32768]);
    }
    return error.InvalidRef;
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
