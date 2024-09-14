const std = @import("std");
const Vm = @import("./vm.zig").Vm;
const MemoryAddress = @import("./vm.zig").MemoryAddress;
const MemoryValue = @import("./vm.zig").MemoryValue;
const RegisterId = @import("./vm.zig").RegisterId;
const NUMBER_CAP = @import("./vm.zig").NUMBER_CAP;
const REGISTER_START = @import("./vm.zig").REGISTER_START;
const REGISTERS_COUNT = @import("./vm.zig").REGISTERS_COUNT;
const is_register = @import("./vm.zig").is_register;
const op_codes = @import("./op_codes.zig");
const OpCode = op_codes.OpCode;

pub fn print_listing(vm: *Vm, lines: usize) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    _ = try print_op_line(allocator, vm, vm.previous_op, null);

    var pc = vm.pc;

    for (0..lines) |i| {
        const arguments_count = try print_op_line(allocator, vm, pc, i);

        if (arguments_count) |len| {
            pc += 1 + len;
        }
    }
}

fn print_op_line(allocator: std.mem.Allocator, vm: *Vm, pc: MemoryAddress, i: ?usize) !?MemoryAddress {
    const op = vm.memory[pc];
    const op_code = OpCode.parse(op) catch return null;

    if (i != null and i == 0) {
        std.debug.print("{d:5}: =>   ", .{pc});
    } else if (for (vm.breakpoints.items) |breakpoint| {
        if (breakpoint == pc) {
            break true;
        }
    } else false) {
        std.debug.print("{d:5}: [B]  ", .{pc});
    } else {
        std.debug.print("{d:5}:      ", .{pc});
    }

    switch (op_code) {
        OpCode.EQ => try print_op3(vm, pc, "EQ  ", allocator),
        OpCode.GT => try print_op3(vm, pc, "GT  ", allocator),
        OpCode.ADD => try print_op3(vm, pc, "ADD ", allocator),
        OpCode.MULT => try print_op3(vm, pc, "MULT", allocator),
        OpCode.MOD => try print_op3(vm, pc, "MOD ", allocator),
        OpCode.AND => try print_op3(vm, pc, "AND ", allocator),
        OpCode.OR => try print_op3(vm, pc, "OR  ", allocator),

        OpCode.SET => try print_op2(vm, pc, "SET ", allocator),
        OpCode.JT => try print_op2(vm, pc, "JT  ", allocator),
        OpCode.JF => try print_op2(vm, pc, "JF  ", allocator),
        OpCode.NOT => try print_op2(vm, pc, "NOT ", allocator),
        OpCode.READ_MEM => try print_op2(vm, pc, "READ", allocator),
        OpCode.WRITE_MEM => try print_op2(vm, pc, "WRIT", allocator),

        OpCode.PUSH => try print_op1(vm, pc, "PUSH", allocator),
        OpCode.POP => try print_op1(vm, pc, "POP ", allocator),
        OpCode.JUMP => try print_op1(vm, pc, "JUMP", allocator),
        OpCode.CALL => try print_op1(vm, pc, "CALL", allocator),
        OpCode.OUT => try print_op1(vm, pc, "OUT ", allocator),
        OpCode.IN => try print_op1(vm, pc, "IN  ", allocator),

        OpCode.HALT => print_op0("HALT"),
        OpCode.RET => print_op0("RET "),
        OpCode.NOOP => print_op0("NOOP"),
    }

    return op_codes.getOpCodeArgsLength(op_code);
}

fn print_op0(op: []const u8) void {
    std.debug.print("{s}\n", .{
        op,
    });
}

fn print_op1(vm: *Vm, pc: MemoryAddress, op: []const u8, allocator: std.mem.Allocator) !void {
    std.debug.print("{s} {s}\n", .{
        op,
        try format_memory(allocator, vm.memory[pc + 1]),
    });
}

fn print_op2(vm: *Vm, pc: MemoryAddress, op: []const u8, allocator: std.mem.Allocator) !void {
    std.debug.print("{s} {s} {s}\n", .{
        op,
        try format_memory(allocator, vm.memory[pc + 1]),
        try format_memory(allocator, vm.memory[pc + 2]),
    });
}

fn print_op3(vm: *Vm, pc: MemoryAddress, op: []const u8, allocator: std.mem.Allocator) !void {
    std.debug.print("{s} {s} {s} {s}\n", .{
        op,
        try format_memory(allocator, vm.memory[pc + 1]),
        try format_memory(allocator, vm.memory[pc + 2]),
        try format_memory(allocator, vm.memory[pc + 3]),
    });
}

fn format_memory(allocator: std.mem.Allocator, value: MemoryValue) ![]const u8 {
    if (value < NUMBER_CAP) {
        const string = try std.fmt.allocPrint(
            allocator,
            "{d:5}",
            .{value},
        );

        return string;
    }

    const registerId: i8 = try read_register_id(value);

    const string = try std.fmt.allocPrint(
        allocator,
        "  <{d}>",
        .{registerId},
    );

    return string;
}

pub fn print_registers(vm: *Vm) void {
    std.debug.print("REG (0-3): {d:5}  {d:5}  {d:5}  {d:5} \nREG (4-7): {d:5}  {d:5}  {d:5}  {d:5}\n", .{
        vm.registers[0],
        vm.registers[1],
        vm.registers[2],
        vm.registers[3],
        vm.registers[4],
        vm.registers[5],
        vm.registers[6],
        vm.registers[7],
    });
}

fn read_register_id(value: MemoryValue) !RegisterId {
    if (!is_register(value)) {
        return error.NotRegister;
    }

    return @truncate(value - REGISTER_START);
}
