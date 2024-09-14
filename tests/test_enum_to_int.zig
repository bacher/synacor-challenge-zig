const std = @import("std");

const A = enum(u3) {
    white,
    black,
    red,
};

test "enum" {
    var c: A = A.black;
    const a: u1 = @intFromEnum(c);

    std.debug.print("", .{&c});

    try std.testing.expect(a == 1);
}
