const std = @import("std");
const opCodes = @import("./op_codes.zig");
const ChallengeLoaderModule = @import("./challenge_loader.zig");
const input_lines = @import("./input.zig").input_lines;
const print_listing = @import("./debug.zig").print_listing;
const print_registers = @import("./debug.zig").print_registers;

var input_line: usize = 0;

pub const OpCode = opCodes.OpCode;
const ChallengeLoader = ChallengeLoaderModule.ChallengeLoader;

pub const WordType = u15;
pub const MemoryAddress = u15;
pub const MemoryValue = u16;
pub const RegisterId = u3;

pub const NUMBER_CAP = std.math.pow(u16, 2, @bitSizeOf(WordType));
pub const REGISTER_START = NUMBER_CAP;
pub const REGISTERS_COUNT = 8;
pub const MEMORY_SIZE = std.math.pow(u16, 2, @bitSizeOf(MemoryAddress));

const Registers = [REGISTERS_COUNT]WordType;
const Memory = [MEMORY_SIZE]MemoryValue;

pub const Vm = struct {
    allocator: std.mem.Allocator,
    // registers: [8]u16,
    // registers: [8]u16 = undefined,
    registers: Registers = .{0} ** REGISTERS_COUNT,
    stack: std.ArrayList(WordType),
    memory: Memory = std.mem.zeroes([MEMORY_SIZE]MemoryValue),
    pc: MemoryAddress = 0,
    previous_op: MemoryAddress = 0,

    input_buffer: [100]u8 = undefined,
    input_buffer_rest: ?[]const u8 = null,

    is_debug_mode: bool = false,
    breakpoints: std.ArrayList(MemoryAddress),

    pub fn initVm(allocator: std.mem.Allocator, binary_data: []MemoryValue) !Vm {
        var memory = std.mem.zeroes([MEMORY_SIZE]MemoryValue);

        try std.testing.expect(memory.len >= binary_data.len);

        @memcpy(memory[0..binary_data.len], binary_data);

        return .{
            .allocator = allocator,
            // .registers = [_]u16{0} ** 8,
            .stack = std.ArrayList(WordType).init(allocator),
            .memory = memory,

            .breakpoints = std.ArrayList(MemoryAddress).init(allocator),
        };
    }

    pub fn deinit(self: *Vm) void {
        self.stack.deinit();
        self.breakpoints.deinit();
    }

    fn add(a: WordType, b: WordType) WordType {
        return a +% b;
    }

    fn mult(a: WordType, b: WordType) WordType {
        return a *% b;
    }

    fn mod(a: WordType, b: WordType) WordType {
        return a % b;
    }

    fn andFn(a: WordType, b: WordType) WordType {
        return a & b;
    }

    fn orFn(a: WordType, b: WordType) WordType {
        return a | b;
    }

    fn getMemoryCell(self: *Vm, memory_address: MemoryAddress) !MemoryValue {
        if (memory_address < self.memory.len) {
            return self.memory[memory_address];
        }
        return error.InvalidBinaryAccess;
    }

    fn operand3(self: *Vm, comptime func: (fn (a: WordType, b: WordType) WordType)) !void {
        const register = try self.read_register_id(try self.getMemoryCell(self.pc + 1));
        const a = try read_value_at(self, self.pc + 2);
        const b = try read_value_at(self, self.pc + 3);

        const value = func(a, b);

        put_value_into_register(&self.registers, register, value);
    }

    pub fn run(self: *Vm) !void {
        var skip_debug_listening_one_time = false;
        var debug_input_buffer: [100]u8 = undefined;

        while (true) {
            var need_to_reset_debug = false;

            if (!self.is_debug_mode) {
                for (self.breakpoints.items) |item| {
                    if (item == self.pc) {
                        self.is_debug_mode = true;
                        break;
                    }
                }
            }

            if (self.is_debug_mode) {
                if (skip_debug_listening_one_time) {
                    skip_debug_listening_one_time = false;
                } else {
                    std.debug.print("=====\n", .{});
                    print_registers(self);
                    std.debug.print("-----\n", .{});
                    try print_listing(self, 5);
                }

                std.debug.print("[debug]> ", .{});
                const std_in_reader = std.io.getStdIn().reader();
                const line = try std_in_reader.readUntilDelimiterOrEof(&debug_input_buffer, '\n');

                if (line) |actual_line| {
                    const is_it_continue = std.mem.eql(u8, actual_line, "c");

                    if (is_it_continue) {
                        need_to_reset_debug = true;
                    }

                    if (!std.mem.eql(u8, actual_line, "") and !is_it_continue) {
                        if (std.mem.indexOf(u8, actual_line, "set ") == 0) {
                            const rest = actual_line[4..];

                            var arguments = std.mem.split(u8, rest, " ");

                            const register_id_string = arguments.first();

                            if (arguments.next()) |value_string| {
                                const register_id = std.fmt.parseInt(usize, register_id_string, 10) catch {
                                    std.debug.print("[debug] invalid arguments\n", .{});
                                    skip_debug_listening_one_time = true;
                                    continue;
                                };

                                const value = std.fmt.parseInt(usize, value_string, 10) catch {
                                    std.debug.print("[debug] invalid arguments\n", .{});
                                    skip_debug_listening_one_time = true;
                                    continue;
                                };

                                if (register_id >= REGISTERS_COUNT) {
                                    std.debug.print("[debug] invalid arguments\n", .{});
                                    skip_debug_listening_one_time = true;
                                    continue;
                                }

                                if (value >= NUMBER_CAP) {
                                    std.debug.print("[debug] invalid arguments\n", .{});
                                    skip_debug_listening_one_time = true;
                                    continue;
                                }

                                put_value_into_register(&self.registers, @truncate(register_id), @truncate(value));
                                continue;
                            }

                            std.debug.print("[debug] invalid arguments\n", .{});
                            skip_debug_listening_one_time = true;
                        } else if (std.mem.indexOf(u8, actual_line, "breakpoint ") == 0) {
                            var arguments = std.mem.split(u8, actual_line, " ");

                            _ = arguments.next();
                            const address_string = arguments.next();

                            if (address_string) |address| {
                                const op_address = std.fmt.parseInt(usize, address, 10) catch {
                                    std.debug.print("[debug] invalid arguments\n", .{});
                                    skip_debug_listening_one_time = true;
                                    continue;
                                };

                                if (op_address >= self.memory.len) {
                                    std.debug.print("[debug] invalid arguments\n", .{});
                                    skip_debug_listening_one_time = true;
                                    continue;
                                }

                                try self.breakpoints.append(@intCast(op_address));
                            } else {
                                std.debug.print("[debug] invalid arguments\n", .{});
                                skip_debug_listening_one_time = true;
                                continue;
                            }
                        } else {
                            std.debug.print("[debug] unknown command \"{s}\"\n", .{actual_line});
                            skip_debug_listening_one_time = true;
                        }
                        continue;
                    }
                }
            }

            self.execute_op() catch |err| {
                if (err == error.RepeatOp) {
                    continue;
                } else {
                    return err;
                }
            };

            if (need_to_reset_debug) {
                self.is_debug_mode = false;
            }
        }
    }

    fn execute_op(self: *Vm) !void {
        const current_op = self.pc;
        const op = try self.getMemoryCell(current_op);

        const op_code = try OpCode.parse(op);
        const args_length = opCodes.getOpCodeArgsLength(op_code);
        var jump_to: ?MemoryAddress = null;

        const arg0 = self.pc + 1;
        const arg1 = self.pc + 2;
        const arg2 = self.pc + 3;

        switch (op_code) {
            OpCode.HALT => {
                return;
            },
            OpCode.SET => {
                const register = try self.read_register_id(try self.getMemoryCell(arg0));
                const value = try read_value_at(self, arg1);
                put_value_into_register(&self.registers, register, value);
            },
            OpCode.PUSH => {
                const value = try read_value_at(self, arg0);
                try self.stack.append(value);
            },
            OpCode.POP => {
                const register = try self.read_register_id(try self.getMemoryCell(arg0));
                const optional_value = self.stack.popOrNull();
                if (optional_value) |value| {
                    put_value_into_register(&self.registers, register, value);
                } else {
                    return error.StackExhausted;
                }
            },
            OpCode.EQ => {
                const register = try self.read_register_id(try self.getMemoryCell(arg0));
                const a = try read_value_at(self, arg1);
                const b = try read_value_at(self, arg2);
                put_value_into_register(&self.registers, register, if (a == b) 1 else 0);
            },
            OpCode.GT => {
                const register = try self.read_register_id(try self.getMemoryCell(arg0));
                const a = try read_value_at(self, arg1);
                const b = try read_value_at(self, arg2);
                put_value_into_register(&self.registers, register, if (a > b) 1 else 0);
            },
            OpCode.JUMP => {
                jump_to = try read_value_at(self, arg0);
            },
            OpCode.JT => {
                const value = try read_value_at(self, arg0);
                if (value > 0) {
                    jump_to = try read_value_at(self, arg1);
                }
            },
            OpCode.JF => {
                const value = try read_value_at(self, arg0);
                if (value == 0) {
                    jump_to = try read_value_at(self, arg1);
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
                const register = try self.read_register_id(try self.getMemoryCell(arg0));
                const a = try read_value_at(self, arg1);
                put_value_into_register(&self.registers, register, ~a);
            },
            // rmem: 15 a b
            //   read memory at address <b> and write it to <a>
            OpCode.READ_MEM => {
                const register = try self.read_register_id(try self.getMemoryCell(arg0));
                const memory_address = try read_value_at(self, arg1);
                const value = try read_memory(&self.memory, memory_address);

                try std.testing.expect(value < NUMBER_CAP);

                put_value_into_register(&self.registers, register, @intCast(value));
            },
            // wmem: 16 a b
            //   write the value from <b> into memory at address <a>
            OpCode.WRITE_MEM => {
                const memory_address = try read_value_at(self, arg0);
                const b = try read_value_at(self, arg1);

                try write_memory(&self.memory, memory_address, b);
            },
            // call: 17 a
            //   write the address of the next instruction to the stack and jump to <a>
            OpCode.CALL => {
                const a = try read_value_at(self, arg0);
                try self.stack.append(arg1);
                jump_to = a;
            },
            // ret: 18
            //   remove the top element from the stack and jump to it; empty stack = halt
            OpCode.RET => {
                const optional_value = self.stack.popOrNull();
                if (optional_value) |value| {
                    jump_to = value;
                } else {
                    return;
                }
            },
            // out: 19 a
            //   write the character represented by ascii code <a> to the terminal
            OpCode.OUT => {
                const output_char: u8 = @truncate(try read_value_at(self, arg0));
                std.debug.print("{c}", .{output_char});
            },
            // in: 20 a
            //   read a character from the terminal and write its ascii code to <a>; it can be assumed that once input starts, it will continue until a newline is encountered; this means that you can safely read whole lines from the keyboard and trust that they will be fully read
            OpCode.IN => {
                const register = try self.read_register_id(try self.getMemoryCell(arg0));

                var value: u8 = undefined;

                if (self.input_buffer_rest == null) {
                    if (input_line < input_lines.len) {
                        self.input_buffer_rest = input_lines[input_line];
                        input_line += 1;

                        std.debug.print("> {s}", .{self.input_buffer_rest.?});
                    } else {
                        std.debug.print("> ", .{});
                        const std_in_reader = std.io.getStdIn().reader();
                        const line = try std_in_reader.readUntilDelimiterOrEof(&self.input_buffer, '\n');

                        if (line) |actual_line| {
                            // std.debug.print("{any}", .{actual_line});
                            try std.testing.expect(actual_line.len > 0);
                            self.input_buffer_rest = actual_line;
                        } else {
                            return error.NoInput;
                        }
                    }

                    if (std.mem.eql(u8, self.input_buffer_rest.?, ".debug")) {
                        // var lines: usize = 10;
                        // if (input_buffer_rest.?.len > 7) {
                        //     lines = std.fmt.parseInt(usize, input_buffer_rest.?[7..], 10) catch 10;
                        // }

                        self.is_debug_mode = true;
                        self.input_buffer_rest = null;

                        return error.RepeatOp;
                    }
                }

                if (self.input_buffer_rest) |*input| {
                    if (input.len == 0) {
                        value = '\n';
                        self.input_buffer_rest = null;
                    } else {
                        value = input.*[0];
                        try std.testing.expect(value < 256);
                        input.* = input.*[1..];
                    }
                } else {
                    return error.NoInput;
                }

                put_value_into_register(&self.registers, register, value);
            },
            // noop: 21
            //   no operation
            OpCode.NOOP => {
                // noop;
            },
        }

        self.previous_op = current_op;

        if (jump_to) |new_pc| {
            self.pc = new_pc;
        } else {
            self.pc += 1 + args_length;
        }
    }

    pub fn as_register(self: *Vm, value: MemoryValue) !?RegisterId {
        if (is_register(value)) {
            const register_id: RegisterId = @truncate(value - REGISTER_START);

            if (register_id == 7 and !self.is_debug_mode) {
                self.is_debug_mode = true;
                return error.RepeatOp;
            }

            return register_id;
        }
        return null;
    }

    pub fn read_register_id(self: *Vm, value: MemoryValue) !RegisterId {
        if (try self.as_register(value)) |register_id| {
            return register_id;
        }

        return error.NotRegister;
    }

    pub fn read_value_at(self: *Vm, pc: MemoryAddress) !WordType {
        return self.read_value(try self.getMemoryCell(pc));
    }

    pub fn read_value(self: *Vm, value: MemoryValue) !WordType {
        if (as_value(value)) |val| {
            return val;
        }

        if (try self.as_register(value)) |register_id| {
            return self.read_value(self.registers[register_id]);
        }

        return error.InvalidRef;
    }
};

pub fn as_value(value: MemoryValue) ?WordType {
    if (value >= NUMBER_CAP) {
        return null;
    }
    return @intCast(value);
}

fn put_value_into_register(registers: *Registers, register: RegisterId, value: WordType) void {
    registers.*[register] = value;
}

fn read_memory(memory: *Memory, cell: MemoryAddress) !MemoryValue {
    if (cell >= memory.len) {
        return error.InvalidMemoryAddress;
    }
    return memory[cell];
}

fn write_memory(memory: *Memory, memory_address: MemoryAddress, value: WordType) !void {
    if (memory_address >= memory.len) {
        return error.InvalidMemoryAddress;
    }
    memory[memory_address] = value;
}

pub fn is_register(value: MemoryValue) bool {
    return value >= REGISTER_START and value < REGISTER_START + REGISTERS_COUNT;
}
