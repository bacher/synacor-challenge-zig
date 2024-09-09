const std = @import("std");
const expect = std.testing.expect;
const test_allocator = std.testing.allocator;

test "fetchPut" {
    var map = std.AutoHashMap(u8, f32).init(
        test_allocator,
    );
    defer map.deinit();

    try map.put(255, 10);
    const old = try map.fetchPut(255, 100);

    try expect(old.?.value == 10);
    try expect(map.get(255).? == 100);
}

test "AutoArrayHashMap" {
    var map = std.AutoArrayHashMap(u8, i32).init(
        test_allocator,
    );
    defer map.deinit();

    try map.put(255, 10);
    try map.put(255, 11);
    const values = map.get(255);

    std.debug.print("{any}\n", .{values});

}