const std = @import("std");
const expect = std.testing.expect;
const test_allocator = std.testing.allocator;
const eql = std.mem.eql;

const Place = struct { lat: f32, long: f32 };

test "json stringify" {
    const x = Place{
        .lat = 51.997664,
        .long = -0.740687,
    };

    var buf: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    var string = std.ArrayList(u8).init(fba.allocator());
    try std.json.stringify(x, .{}, string.writer());

    try expect(eql(u8, string.items,
        \\{"lat":5.199766540527344e1,"long":-7.406870126724243e-1}
    ));
}

test "json parse with strings" {
    const User = struct { name: []u8, age: u16 };

    const parsed = std.json.parseFromSlice(User, test_allocator,
        \\{ "name": "Joe", "not_age": 25 }
    , .{}) catch null;

    defer {
        if (parsed) |value| {
            value.deinit();
        }
    }

    const user: User = if (parsed) |value|
        value.value
    else
        User{ .name = @constCast("unknown"), .age = 0 };

    try expect(eql(u8, user.name, "unknown"));
    try expect(user.age == 0);
}
