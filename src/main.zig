const std = @import("std");
const opCodes = @import("./op_codes.zig");

const OpCode = opCodes.OpCode;

const NUMBER_CAP = std.math.pow(u16, 2, 15);
const REGISTER_START = NUMBER_CAP;
const REGISTERS_COUNT = 8;
const MEMORY_SIZE = std.math.pow(u16, 2, 15);

const WordType = u16;
const RegState = [REGISTERS_COUNT]WordType;

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

    try run(allocator, buffer_u16);
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

fn run(allocator: std.mem.Allocator, binary: [*]u16) !void {
    var pc: u16 = 0;
    var reg_state_buffer = ([_]u16{ 0, 0, 0, 0, 0, 0, 0, 0 });
    var reg_state = &reg_state_buffer;
    reg_state[0] = 0;
    // var memory = std.mem.zeroes([MEMORY_SIZE]u16);
    var stack = std.ArrayList(u16).init(allocator);
    defer stack.deinit();

    while (true) {
        const op = binary[pc];
        pc += 1;

        // std.debug.print("op code {d}\n", .{op});

        const op_code = try OpCode.parse(op);
        const args_length = opCodes.getOpCodeArgsLength(op_code);
        var jump_to: ?u16 = null;

        switch (op_code) {
            OpCode.HALT => {
                return;
            },
            OpCode.SET => {
                const register = try read_register_id(binary[pc]);
                const value = try read_value_at(binary, reg_state, pc + 1);
                put_value_into_register(reg_state, register, value);
            },
            OpCode.PUSH => {
                const value = try read_value_at(binary, reg_state, pc);
                try stack.append(value);
            },
            OpCode.POP => {
                const register = try read_register_id(binary[pc]);
                const optional_value = stack.popOrNull();
                if (optional_value) |value| {
                    put_value_into_register(reg_state, register, value);
                } else {
                    return error.StackExhausted;
                }
            },
            OpCode.EQ => {
                const register = try read_register_id(binary[pc]);
                const a = try read_value_at(binary, reg_state, pc + 1);
                const b = try read_value_at(binary, reg_state, pc + 2);
                put_value_into_register(reg_state, register, if (a == b) 1 else 0);
            },
            OpCode.GT => {
                const register = try read_register_id(binary[pc]);
                const a = try read_value_at(binary, reg_state, pc + 1);
                const b = try read_value_at(binary, reg_state, pc + 2);
                put_value_into_register(reg_state, register, if (a > b) 1 else 0);
            },
            OpCode.JUMP => {
                jump_to = try read_value_at(binary, reg_state, pc);
            },
            OpCode.JT => {
                const value = try read_value_at(binary, reg_state, pc);
                if (value > 0) {
                    jump_to = try read_value_at(binary, reg_state, pc + 1);
                }
            },
            OpCode.JF => {
                const value = try read_value_at(binary, reg_state, pc);
                if (value == 0) {
                    jump_to = try read_value_at(binary, reg_state, pc + 1);
                }
            },
            OpCode.ADD => {
                const register = try read_register_id(binary[pc]);
                const a = try read_value_at(binary, reg_state, pc + 1);
                const b = try read_value_at(binary, reg_state, pc + 2);
                put_value_into_register(reg_state, register, (a + b) % NUMBER_CAP);
            },
            OpCode.AND => {
                const register = try read_register_id(binary[pc]);
                const a = try read_value_at(binary, reg_state, pc + 1);
                const b = try read_value_at(binary, reg_state, pc + 2);
                put_value_into_register(reg_state, register, (a & b) % NUMBER_CAP);
            },
            OpCode.OUT => {
                const output_char: u8 = @truncate(try read_value_at(binary, reg_state, pc));
                std.debug.print("{c}", .{output_char});
            },
            OpCode.NOOP => {
                // noop;
            },
            else => {
                std.debug.print("Unsupported opcode {}\n", .{op});
                return;
            },
        }

        if (jump_to) |new_pc| {
            pc = new_pc;
        } else {
            pc += args_length;
        }
    }
}

fn read_value_at(binary: [*]u16, reg_state: *RegState, pc: u16) !u16 {
    return read_value(binary, reg_state, binary[pc]);
}

fn read_value(binary: [*]u16, reg_state: *RegState, value: u16) !u16 {
    if (value < NUMBER_CAP) {
        return value;
    }
    if (value < REGISTER_START + REGISTERS_COUNT) {
        return read_value(binary, reg_state, reg_state.*[value - REGISTER_START]);
    }
    return error.InvalidRef;
}

fn is_register(value: u16) bool {
    return value >= REGISTER_START and value < REGISTER_START + REGISTERS_COUNT;
}

fn read_register_id(value: u16) !u16 {
    if (!is_register(value)) {
        return error.NotRegister;
    }
    return value - REGISTER_START;
}

fn put_value_into_register(reg_state: *RegState, register: u16, value: u16) void {
    reg_state.*[register] = value;
}

fn set_memory(memory: []u16, cell: u16, value: u16) !void {
    if (cell >= memory.len) {
        return error.InvalidMemoryAddress;
    }
    memory[cell] = value;
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
