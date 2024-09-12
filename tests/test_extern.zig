const std = @import("std");
const expect = @import("std").testing.expect;

const Data = extern struct { a: i32, b: u8, c: f32, d: bool, e: bool, f: bool };

test "hmm" {
    const x = Data{
        .a = 10005,
        .b = 42,
        .c = -10.5,
        .d = false,
        .e = true,
        .f = true,
    };

    std.debug.print("Data size: {}\n", .{@sizeOf(Data)});

    const z = @as([*]const u8, @ptrCast(&x));

    try expect(@as(*const i32, @ptrCast(@alignCast(z))).* == 10005);
    try expect(@as(*const u8, @ptrCast(@alignCast(z + 4))).* == 42);
    try expect(@as(*const f32, @ptrCast(@alignCast(z + 8))).* == -10.5);
    try expect(@as(*const bool, @ptrCast(@alignCast(z + 12))).* == false);
    try expect(@as(*const bool, @ptrCast(@alignCast(z + 13))).* == true);
    try expect(@as(*const bool, @ptrCast(@alignCast(z + 14))).* == true);
}

test "mem.span" {
    const a = "hello";

    const b: [*:0]const u8 = a.ptr;

    const c = std.mem.span(b);

    const d = b[0..10];

    std.debug.print("a     = {*}\n", .{a});
    std.debug.print("a.ptr = {*}\n", .{a.ptr});
    std.debug.print("a.len = {d}\n", .{a.len});

    std.debug.print("b     = {*}\n", .{b});

    std.debug.print("c     = {*}\n", .{c});
    std.debug.print("c.ptr = {*}\n", .{c.ptr});
    std.debug.print("c.len = {d}\n", .{c.len});

    std.debug.print("d     = {*}\n", .{d});
    std.debug.print("d.ptr = {*}\n", .{d.ptr});
    std.debug.print("d.len = {d}\n", .{d.len});
}