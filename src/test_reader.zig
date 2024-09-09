const std = @import("std");

test "test Reader" {
    const nums = [_]u32{ 0xDEAD, 0xBEEF, 0xF000, 0xB335 };
    const nums_mem = std.mem.sliceAsBytes(&nums);

    std.debug.print("{*}\n", .{&nums});
    std.debug.print("{*}\n", .{nums_mem});
    std.debug.print("{d}\n", .{nums.len});
    std.debug.print("{d}\n", .{nums_mem.len});
    std.debug.print("{}\n", .{@TypeOf(nums)});
    std.debug.print("{}\n", .{@TypeOf(nums_mem)});
}