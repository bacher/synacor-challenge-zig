const std = @import("std");
const expect = std.testing.expect;

test "array vs slice" {
    const array = [_]u8{ 'h', 'e', 'l', 'l', 'o' };

    std.debug.print("array      {*}\n", .{&array});
    std.debug.print("array[0]   {*}\n", .{&array[0]});
    std.debug.print("array.len  {d}\n", .{array.len});

    const slice = array[0..3];
    try expect(@TypeOf(slice) == *const [3]u8);
    std.debug.print("slice      {*}\n", .{&slice});
    std.debug.print("slice[0]   {*}\n", .{&slice[0]});
    std.debug.print("slice.len  {d}\n", .{slice.len});

    const slice2: []const u8 = &array;
    std.debug.print("slice2     {*}\n", .{&slice2});
    std.debug.print("slice2[0]  {*}\n", .{&slice2[0]});
    std.debug.print("slice2.len {d}\n", .{slice2.len});

    printArray(slice);
}

fn printArray(list: []const u8) void {
    std.debug.print("c[0]: {c}\n", .{list[0]});
}
