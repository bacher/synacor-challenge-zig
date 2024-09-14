const std = @import("std");
const opCodes = @import("./op_codes.zig");
const ChallengeLoaderModule = @import("./challenge_loader.zig");
const input_lines = @import("./input.zig").input_lines;
const print_listing = @import("./debug.zig").print_listing;
const print_registers = @import("./debug.zig").print_registers;

var input_line: usize = 0;

pub const OpCode = opCodes.OpCode;
const ChallengeLoader = ChallengeLoaderModule.ChallengeLoader;

pub const Word = u15;
pub const MemoryAddress = enum(u15) { _ };
pub const MemoryValue = u16;
pub const RegisterId = enum(u3) { _ };

const reg_7: RegisterId = @enumFromInt(7);

pub const NUMBER_CAP = std.math.pow(u16, 2, @bitSizeOf(Word));
pub const REGISTER_START = NUMBER_CAP;
pub const REGISTERS_COUNT = 8;
pub const MEMORY_SIZE = std.math.pow(u16, 2, @bitSizeOf(MemoryAddress));

const Registers = [REGISTERS_COUNT]Word;
const Memory = [MEMORY_SIZE]MemoryValue;

const DebugStepResult = enum {
    RESTART_STEP,
    CONTINUE,
    HALT,
};

pub const Vm = struct {
    allocator: std.mem.Allocator,
    // registers: [8]u16,
    // registers: [8]u16 = undefined,
    registers: Registers = .{0} ** REGISTERS_COUNT,
    stack: std.ArrayList(Word),
    memory: Memory = std.mem.zeroes([MEMORY_SIZE]MemoryValue),
    pc: MemoryAddress = @enumFromInt(0),
    previous_op: MemoryAddress = @enumFromInt(0),

    input_buffer: [100]u8 = undefined,
    input_buffer_rest: ?[]const u8 = null,

    is_debug_mode: bool = false,
    breakpoints: std.ArrayList(MemoryAddress),
    skip_debug_listening_one_time: bool = false,
    need_to_reset_debug_one_time: bool = false,

    pub fn initVm(allocator: std.mem.Allocator, binary_data: []MemoryValue) !Vm {
        var memory = std.mem.zeroes([MEMORY_SIZE]MemoryValue);

        try std.testing.expect(memory.len >= binary_data.len);

        @memcpy(memory[0..binary_data.len], binary_data);

        return .{
            .allocator = allocator,
            // .registers = [_]u16{0} ** 8,
            .stack = std.ArrayList(Word).init(allocator),
            .memory = memory,

            .breakpoints = std.ArrayList(MemoryAddress).init(allocator),
        };
    }

    pub fn deinit(self: *Vm) void {
        self.stack.deinit();
        self.breakpoints.deinit();
    }

    fn add(a: Word, b: Word) Word {
        return a +% b;
    }

    fn mult(a: Word, b: Word) Word {
        return a *% b;
    }

    fn mod(a: Word, b: Word) Word {
        return a % b;
    }

    fn andFn(a: Word, b: Word) Word {
        return a & b;
    }

    fn orFn(a: Word, b: Word) Word {
        return a | b;
    }

    pub fn readMemory(self: *Vm, memory_address: MemoryAddress) MemoryValue {
        return self.memory[@intFromEnum(memory_address)];
    }

    fn operand3(self: *Vm, comptime func: (fn (a: Word, b: Word) Word)) !void {
        const register = try self.readRegisterId(self.readMemory(try self.shiftAddress(self.pc, 1)));
        const a = try self.readValueAt(try self.shiftAddress(self.pc, 2));
        const b = try self.readValueAt(try self.shiftAddress(self.pc, 3));

        const value = func(a, b);

        putValueIntoRegister(&self.registers, register, value);
    }

    pub fn shiftAddress(_: *Vm, memory_address: MemoryAddress, shift: usize) !MemoryAddress {
        const address = @intFromEnum(memory_address) + shift;

        if (address >= MEMORY_SIZE) {
            return error.InvalidMemoryAddress;
        }

        return @enumFromInt(address);
    }

    pub fn run(self: *Vm) !void {
        var debug_input_buffer: [100]u8 = undefined;

        while (true) {
            const debug_result = try self.debugStep(&debug_input_buffer);

            switch (debug_result) {
                DebugStepResult.RESTART_STEP => {
                    continue;
                },
                DebugStepResult.CONTINUE => {
                    // do nothing
                },
                DebugStepResult.HALT => {
                    break;
                },
            }

            self.executeOp() catch |err| {
                if (err != error.RepeatOp) {
                    return err;
                }
            };

            if (self.need_to_reset_debug_one_time) {
                self.is_debug_mode = false;
                self.need_to_reset_debug_one_time = false;
            }
        }
    }

    fn debugStep(self: *Vm, debug_input_buffer: []u8) !DebugStepResult {
        if (!self.is_debug_mode) {
            for (self.breakpoints.items) |item| {
                if (item == self.pc) {
                    self.is_debug_mode = true;
                    break;
                }
            }
        }

        if (self.is_debug_mode) {
            if (self.skip_debug_listening_one_time) {
                self.skip_debug_listening_one_time = false;
            } else {
                std.debug.print("=====\n", .{});
                print_registers(self);
                std.debug.print("-----\n", .{});
                try print_listing(self, 5);
            }

            std.debug.print("[debug]> ", .{});
            const std_in_reader = std.io.getStdIn().reader();
            const line = try std_in_reader.readUntilDelimiterOrEof(debug_input_buffer, '\n');

            if (line) |actual_line| {
                const is_it_continue = std.mem.eql(u8, actual_line, "c") or
                    std.mem.eql(u8, actual_line, "continue");

                if (is_it_continue) {
                    self.need_to_reset_debug_one_time = true;
                }

                if (!std.mem.eql(u8, actual_line, "") and !is_it_continue) {
                    if (std.mem.indexOf(u8, actual_line, "exit") == 0) {
                        return DebugStepResult.HALT;
                    } else if (std.mem.indexOf(u8, actual_line, "set ") == 0) {
                        const rest = actual_line[4..];

                        var arguments = std.mem.tokenize(u8, rest, " ");

                        const register_id_string = arguments.next();
                        const value_string = arguments.next();

                        if (register_id_string == null or value_string == null) {
                            std.debug.print("[debug] invalid arguments\n", .{});
                            self.skip_debug_listening_one_time = true;
                            return DebugStepResult.RESTART_STEP;
                        }

                        const register_id = std.fmt.parseInt(usize, register_id_string.?, 10) catch {
                            std.debug.print("[debug] invalid arguments\n", .{});
                            self.skip_debug_listening_one_time = true;
                            return DebugStepResult.RESTART_STEP;
                        };

                        const value = std.fmt.parseInt(usize, value_string.?, 10) catch {
                            std.debug.print("[debug] invalid arguments\n", .{});
                            self.skip_debug_listening_one_time = true;
                            return DebugStepResult.RESTART_STEP;
                        };

                        if (register_id >= REGISTERS_COUNT) {
                            std.debug.print("[debug] invalid arguments\n", .{});
                            self.skip_debug_listening_one_time = true;
                            return DebugStepResult.RESTART_STEP;
                        }

                        if (value >= NUMBER_CAP) {
                            std.debug.print("[debug] invalid arguments\n", .{});
                            self.skip_debug_listening_one_time = true;
                            return DebugStepResult.RESTART_STEP;
                        }

                        putValueIntoRegister(&self.registers, @enumFromInt(register_id), @truncate(value));
                        return DebugStepResult.RESTART_STEP;
                    } else if (std.mem.indexOf(u8, actual_line, "breakpoint ") == 0 or
                        std.mem.indexOf(u8, actual_line, "b ") == 0)
                    {
                        var arguments = std.mem.tokenize(u8, actual_line, " ");

                        _ = arguments.next();
                        const address_string = arguments.next();

                        if (address_string == null) {
                            std.debug.print("[debug] invalid arguments\n", .{});
                            self.skip_debug_listening_one_time = true;
                            return DebugStepResult.RESTART_STEP;
                        }

                        const op_address = std.fmt.parseInt(usize, address_string.?, 10) catch {
                            std.debug.print("[debug] invalid arguments\n", .{});
                            self.skip_debug_listening_one_time = true;
                            return DebugStepResult.RESTART_STEP;
                        };

                        if (op_address >= self.memory.len) {
                            std.debug.print("[debug] invalid arguments\n", .{});
                            self.skip_debug_listening_one_time = true;
                            return DebugStepResult.RESTART_STEP;
                        }

                        try self.breakpoints.append(@enumFromInt(op_address));
                    } else {
                        std.debug.print("[debug] unknown command \"{s}\"\n", .{actual_line});
                        self.skip_debug_listening_one_time = true;
                    }
                    return DebugStepResult.RESTART_STEP;
                }
            }
        }

        return DebugStepResult.CONTINUE;
    }

    fn executeOp(self: *Vm) !void {
        // const d = "hello";
        // var e: []u8 = @constCast(d);
        //
        // var n: u32 = 3;
        // n += 1;
        //
        // e[n - 4] = 'A';
        // e[n - 1] = 'P';
        // try std.testing.expect(e[n - 1] == 'l');
        //
        // std.debug.print("e = {s}\n", .{e});

        const current_op = self.pc;
        const op = self.readMemory(current_op);

        const op_code = try OpCode.parse(op);
        const args_length = opCodes.getOpCodeArgsLength(op_code);
        var jump_to: ?MemoryAddress = null;

        // TODO: Unsafe
        const arg0: MemoryAddress = @enumFromInt(@intFromEnum(self.pc) + 1);
        const arg1: MemoryAddress = @enumFromInt(@intFromEnum(self.pc) + 2);
        const arg2: MemoryAddress = @enumFromInt(@intFromEnum(self.pc) + 3);

        switch (op_code) {
            OpCode.HALT => {
                return;
            },
            OpCode.SET => {
                const register = try self.readRegisterId(self.readMemory(arg0));
                const value = try readValueAt(self, arg1);
                putValueIntoRegister(&self.registers, register, value);
            },
            OpCode.PUSH => {
                const value = try readValueAt(self, arg0);
                try self.stack.append(value);
            },
            OpCode.POP => {
                const register = try self.readRegisterId(self.readMemory(arg0));
                const optional_value = self.stack.popOrNull();
                if (optional_value) |value| {
                    putValueIntoRegister(&self.registers, register, value);
                } else {
                    return error.StackExhausted;
                }
            },
            OpCode.EQ => {
                const register = try self.readRegisterId(self.readMemory(arg0));
                const a = try self.readValueAt(arg1);
                const b = try self.readValueAt(arg2);
                putValueIntoRegister(&self.registers, register, if (a == b) 1 else 0);
            },
            OpCode.GT => {
                const register = try self.readRegisterId(self.readMemory(arg0));
                const a = try self.readValueAt(arg1);
                const b = try self.readValueAt(arg2);
                putValueIntoRegister(&self.registers, register, if (a > b) 1 else 0);
            },
            OpCode.JUMP => {
                jump_to = self.memoryAddressFromValue(try readValueAt(self, arg0));
            },
            OpCode.JT => {
                const value = try readValueAt(self, arg0);
                if (value > 0) {
                    jump_to = self.memoryAddressFromValue(try readValueAt(self, arg1));
                }
            },
            OpCode.JF => {
                const value = try readValueAt(self, arg0);
                if (value == 0) {
                    jump_to = self.memoryAddressFromValue(try readValueAt(self, arg1));
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
                const register = try self.readRegisterId(self.readMemory(arg0));
                const a = try readValueAt(self, arg1);
                putValueIntoRegister(&self.registers, register, ~a);
            },
            // rmem: 15 a b
            //   read memory at address <b> and write it to <a>
            OpCode.READ_MEM => {
                const register = try self.readRegisterId(self.readMemory(arg0));
                const memory_address = self.memoryAddressFromValue(try readValueAt(self, arg1));
                const value = self.readMemory(memory_address);

                try std.testing.expect(value < NUMBER_CAP);

                putValueIntoRegister(&self.registers, register, @intCast(value));
            },
            // wmem: 16 a b
            //   write the value from <b> into memory at address <a>
            OpCode.WRITE_MEM => {
                const memory_address = self.memoryAddressFromValue(try readValueAt(self, arg0));
                const b = try readValueAt(self, arg1);

                self.writeMemory(memory_address, b);
            },
            // call: 17 a
            //   write the address of the next instruction to the stack and jump to <a>
            OpCode.CALL => {
                const a = try readValueAt(self, arg0);
                try self.stack.append(@intFromEnum(arg1));
                jump_to = self.memoryAddressFromValue(a);
            },
            // ret: 18
            //   remove the top element from the stack and jump to it; empty stack = halt
            OpCode.RET => {
                const optional_value = self.stack.popOrNull();
                if (optional_value) |value| {
                    jump_to = @enumFromInt(value);
                } else {
                    return;
                }
            },
            // out: 19 a
            //   write the character represented by ascii code <a> to the terminal
            OpCode.OUT => {
                const output_char: u8 = @truncate(try readValueAt(self, arg0));
                std.debug.print("{c}", .{output_char});
            },
            // in: 20 a
            //   read a character from the terminal and write its ascii code to <a>; it can be assumed that once input starts, it will continue until a newline is encountered; this means that you can safely read whole lines from the keyboard and trust that they will be fully read
            OpCode.IN => {
                const register = try self.readRegisterId(self.readMemory(arg0));

                var value: u8 = undefined;

                if (self.input_buffer_rest == null) {
                    if (input_line < input_lines.len) {
                        self.input_buffer_rest = input_lines[input_line];
                        input_line += 1;

                        std.debug.print("> {s}", .{self.input_buffer_rest.?});
                    } else {
                        std.debug.print("> ", .{});
                        const std_in_reader = std.io.getStdIn().reader();

                        while (try std_in_reader.readUntilDelimiterOrEof(&self.input_buffer, '\n')) |line| {
                            if (line.len > 0) {
                                self.input_buffer_rest = line;
                                break;
                            }
                            std.debug.print("> ", .{});
                        }
                    }

                    if (std.mem.eql(u8, self.input_buffer_rest.?, ".debug")) {
                        self.is_debug_mode = true;
                        self.input_buffer_rest = null;
                        return;
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

                putValueIntoRegister(&self.registers, register, value);
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
            self.pc = try self.shiftAddress(self.pc, 1 + args_length);
        }
    }

    pub fn memoryAddressFromValue(_: *Vm, value: Word) MemoryAddress {
        comptime try std.testing.expect(@bitSizeOf(Word) == @bitSizeOf(MemoryAddress));
        return @enumFromInt(value);
    }

    pub fn as_register(self: *Vm, value: MemoryValue) !?RegisterId {
        if (is_register(value)) {
            const register_id: RegisterId = @enumFromInt(value - REGISTER_START);

            if (register_id == reg_7 and !self.is_debug_mode) {
                self.is_debug_mode = true;
                return error.RepeatOp;
            }

            return register_id;
        }
        return null;
    }

    pub fn readRegisterId(self: *Vm, value: MemoryValue) !RegisterId {
        if (try self.as_register(value)) |register_id| {
            return register_id;
        }

        return error.NotRegister;
    }

    pub fn readValueAt(self: *Vm, pc: MemoryAddress) !Word {
        return self.readValue(self.readMemory(pc));
    }

    pub fn readValue(self: *Vm, value: MemoryValue) !Word {
        if (as_value(value)) |val| {
            return val;
        }

        if (try self.as_register(value)) |register_id| {
            return self.registers[@intFromEnum(register_id)];
        }

        return error.InvalidRef;
    }

    pub fn writeMemory(self: *Vm, memory_address: MemoryAddress, value: Word) void {
        self.memory[@intFromEnum(memory_address)] = value;
    }
};

pub fn as_value(value: MemoryValue) ?Word {
    if (value >= NUMBER_CAP) {
        return null;
    }
    return @intCast(value);
}

fn putValueIntoRegister(registers: *Registers, register_id: RegisterId, value: Word) void {
    registers.*[@intFromEnum(register_id)] = value;
}

pub fn is_register(value: MemoryValue) bool {
    return value >= REGISTER_START and value < REGISTER_START + REGISTERS_COUNT;
}
