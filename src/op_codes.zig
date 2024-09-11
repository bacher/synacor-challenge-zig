const std = @import("std");

pub const OpCode = enum(u16) {
    HALT = 0,
    SET = 1,
    PUSH = 2,
    POP = 3,
    EQ = 4,
    GT = 5,
    JUMP = 6,
    JT = 7,
    JF = 8,
    ADD = 9,
    MULT = 10,
    MOD = 11,
    AND = 12,
    OR = 13,
    NOT = 14,
    READ_MEM = 15,
    WRITE_MEM = 16,
    CALL = 17,
    RET = 18,
    OUT = 19,
    IN = 20,
    NOOP = 21,

    pub fn parse(value: u16) !OpCode {
        if (value > @intFromEnum(OpCode.NOOP)) {
            std.debug.print("Invalid opcode = {d}\n", .{value});
            return error.INVALID_OPCODE;
        }

        return @enumFromInt(value);
    }
};

pub fn getOpCodeArgsLength(opCode: OpCode) u8 {
    return switch (opCode) {
        OpCode.HALT => 0,
        OpCode.SET => 2,
        OpCode.PUSH => 1,
        OpCode.POP => 1,
        OpCode.EQ => 3,
        OpCode.GT => 3,
        OpCode.JUMP => 1,
        OpCode.JT => 2,
        OpCode.JF => 2,
        OpCode.ADD => 3,
        OpCode.MULT => 3,
        OpCode.MOD => 3,
        OpCode.AND => 3,
        OpCode.OR => 3,
        OpCode.NOT => 2,
        OpCode.READ_MEM => 2,
        OpCode.WRITE_MEM => 2,
        OpCode.CALL => 1,
        OpCode.RET => 0,
        OpCode.OUT => 1,
        OpCode.IN => 1,
        OpCode.NOOP => 0,
    };
}
