const std = @import("std");

const Token = struct {
    tag: enum(u8) {
        plus,
        minus,
        float_lit,
        int_lit,
    },
    data: u32,
};

test "list" {
    // const tokens: std.MultiArrayList(Token) = .{};
    // const extra: std.ArrayList(u32) = .{};
    //
    // tokens.append(gpa: Allocator, elem: T)
}