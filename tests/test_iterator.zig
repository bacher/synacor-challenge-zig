const std = @import("std");
const expect = std.testing.expect;
const eql = std.mem.eql;

test "split iterator" {
    const text = "robust, optimal, reusable, maintainable";
    var iter = std.mem.split(u8, text, ", ");
    try expect(eql(u8, iter.next().?, "robust"));
    try expect(eql(u8, iter.next().?, "optimal"));
    try expect(eql(u8, iter.next().?, "reusable"));
    try expect(eql(u8, iter.next().?, "maintainable"));
    try expect(iter.next() == null);

    iter.reset();

    while (iter.next()) |value| {
        std.debug.print("value = {s}\n", .{value});
    }
}