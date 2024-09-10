const std = @import("std");
const opCodes = @import("./op_codes.zig");
const ChallengeLoaderModule = @import("./challenge_loader.zig");

const OpCode = opCodes.OpCode;
const ChallengeLoader = ChallengeLoaderModule.ChallengeLoader;

const NUMBER_CAP = std.math.pow(u16, 2, 15);
const REGISTER_START = NUMBER_CAP;
const REGISTERS_COUNT = 8;
const MEMORY_SIZE = std.math.pow(u16, 2, 15);

const WordType = u16;
const RegState = [REGISTERS_COUNT]WordType;

pub const Vm = struct {
    allocator: std.mem.Allocator,
    // registers: [8]u16,
    // registers: [8]u16 = undefined,
    registers: [8]u16 = .{0} ** 8,
    stack: std.ArrayList(u16),
    memory: [MEMORY_SIZE]u16 = std.mem.zeroes([MEMORY_SIZE]u16),
    pc: u16 = 0,

    fn add(a: u16, b: u16) u16 {
        return a +% b;
    }

    fn mult(a: u16, b: u16) u16 {
        return a *% b;
    }

    fn mod(a: u16, b: u16) u16 {
        return a % b;
    }

    fn andFn(a: u16, b: u16) u16 {
        return a & b;
    }

    fn orFn(a: u16, b: u16) u16 {
        return a | b;
    }

    pub fn initVm(allocator: std.mem.Allocator, binary_data: []u16) !Vm {
        var memory = std.mem.zeroes([MEMORY_SIZE]u16);

        try std.testing.expect(memory.len >= binary_data.len);

        @memcpy(memory[0..binary_data.len], binary_data);

        return .{
            .allocator = allocator,
            // .registers = [_]u16{0} ** 8,
            .stack = std.ArrayList(u16).init(allocator),
            .memory = memory,
        };
    }

    pub fn deinit(vm: *Vm) void {
        defer vm.stack.deinit();
    }

    // TODO: delete
    // fn _operand3(self: *Vm, comptime op_code: OpCode) !void {
    //     comptime std.debug.assert(op_code == .ADD or op_code == .MULT);
    //
    //     const register = try read_register_id();
    //     const a = try read_value_at(self, self.pc + 1);
    //     const b = try read_value_at(self, self.pc + 2);
    //
    //     const value = switch (op_code) {
    //         OpCode.ADD => (a +% b),
    //         OpCode.MULT => (a *% b),
    //         else => unreachable,
    //     };
    //
    //     put_value_into_register(&self.registers, register, value % NUMBER_CAP);
    // }

    fn getMemoryCell(self: *Vm, memory_address: u16) !u16 {
        if (memory_address < self.memory.len) {
            return self.memory[memory_address];
        }
        return error.InvalidBinaryAccess;
    }

    fn operand3(self: *Vm, comptime func: (fn (a: u16, b: u16) u16)) !void {
        const register = try read_register_id(try self.getMemoryCell(self.pc));
        const a = try read_value_at(self, self.pc + 1);
        const b = try read_value_at(self, self.pc + 2);

        const value = func(a, b);

        put_value_into_register(&self.registers, register, value % NUMBER_CAP);
    }

    pub fn run(self: *Vm) !void {
        while (true) {
            const op = try self.getMemoryCell(self.pc);
            self.pc += 1;

            // std.debug.print("op code {d}\n", .{op});

            const op_code = try OpCode.parse(op);
            const args_length = opCodes.getOpCodeArgsLength(op_code);
            var jump_to: ?u16 = null;

            switch (op_code) {
                OpCode.HALT => {
                    return;
                },
                OpCode.SET => {
                    const register = try read_register_id(try self.getMemoryCell(self.pc));
                    const value = try read_value_at(self, self.pc + 1);
                    put_value_into_register(&self.registers, register, value);
                },
                OpCode.PUSH => {
                    const value = try read_value_at(self, self.pc);
                    try self.stack.append(value);
                },
                OpCode.POP => {
                    const register = try read_register_id(try self.getMemoryCell(self.pc));
                    const optional_value = self.stack.popOrNull();
                    if (optional_value) |value| {
                        put_value_into_register(&self.registers, register, value);
                    } else {
                        return error.StackExhausted;
                    }
                },
                OpCode.EQ => {
                    const register = try read_register_id(try self.getMemoryCell(self.pc));
                    const a = try read_value_at(self, self.pc + 1);
                    const b = try read_value_at(self, self.pc + 2);
                    put_value_into_register(&self.registers, register, if (a == b) 1 else 0);
                },
                OpCode.GT => {
                    const register = try read_register_id(try self.getMemoryCell(self.pc));
                    const a = try read_value_at(self, self.pc + 1);
                    const b = try read_value_at(self, self.pc + 2);
                    put_value_into_register(&self.registers, register, if (a > b) 1 else 0);
                },
                OpCode.JUMP => {
                    jump_to = try read_value_at(self, self.pc);
                },
                OpCode.JT => {
                    const value = try read_value_at(self, self.pc);
                    if (value > 0) {
                        jump_to = try read_value_at(self, self.pc + 1);
                    }
                },
                OpCode.JF => {
                    const value = try read_value_at(self, self.pc);
                    if (value == 0) {
                        jump_to = try read_value_at(self, self.pc + 1);
                    }
                },
                OpCode.ADD => {
                    try self.operand3(add);
                },
                // mult: 10 a b c
                //   store into <a> the product of <b> and <c> (modulo 32768)
                OpCode.MULT => {
                    try self.operand3(mult);
                },
                // mod: 11 a b c
                //   store into <a> the remainder of <b> divided by <c>
                OpCode.MOD => {
                    try self.operand3(mod);
                },
                OpCode.AND => {
                    try self.operand3(andFn);
                },
                // or: 13 a b c
                //   stores into <a> the bitwise or of <b> and <c>
                OpCode.OR => {
                    try self.operand3(orFn);
                },
                // not: 14 a b
                //   stores 15-bit bitwise inverse of <b> in <a>
                OpCode.NOT => {
                    const register = try read_register_id(try self.getMemoryCell(self.pc));
                    const a = try read_value_at(self, self.pc + 1);
                    put_value_into_register(&self.registers, register, (~a) % NUMBER_CAP);
                },
                // rmem: 15 a b
                //   read memory at address <b> and write it to <a>
                OpCode.READ_MEM => {
                    const register = try read_register_id(try self.getMemoryCell(self.pc));
                    const memory_address = try read_value_at(self, self.pc + 1);
                    const value = try read_memory(&self.memory, memory_address);

                    put_value_into_register(&self.registers, register, value);
                },
                // wmem: 16 a b
                //   write the value from <b> into memory at address <a>
                OpCode.WRITE_MEM => {
                    const memory_address = try read_value_at(self, self.pc);
                    const b = try read_value_at(self, self.pc + 1);

                    try write_memory(&self.memory, memory_address, b);
                },
                // call: 17 a
                //   write the address of the next instruction to the stack and jump to <a>
                OpCode.CALL => {
                    const a = try read_value_at(self, self.pc);
                    try self.stack.append(self.pc + 1);
                    jump_to = a;
                },
                OpCode.OUT => {
                    const output_char: u8 = @truncate(try read_value_at(self, self.pc));
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
                self.pc = new_pc;
            } else {
                self.pc += args_length;
            }
        }
    }
};

fn read_value_at(vm: *Vm, pc: u16) !u16 {
    return read_value(&vm.registers, try vm.getMemoryCell(pc));
}

fn read_value(reg_state: *RegState, value: u16) !u16 {
    if (value < NUMBER_CAP) {
        return value;
    }
    if (value < REGISTER_START + REGISTERS_COUNT) {
        return read_value(reg_state, reg_state.*[value - REGISTER_START]);
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

fn read_memory(memory: []u16, cell: u16) !u16 {
    if (cell >= memory.len) {
        return error.InvalidMemoryAddress;
    }
    return memory[cell];
}

fn write_memory(memory: []u16, memory_address: u16, value: u16) !void {
    if (memory_address >= memory.len) {
        return error.InvalidMemoryAddress;
    }
    memory[memory_address] = value;
}
