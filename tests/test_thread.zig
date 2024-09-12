const std = @import("std");
const expect = std.testing.expect;

fn ticker(step: u8) void {
    while (true) {
        std.time.sleep(1 * std.time.ns_per_s);
        tick += @as(isize, step);

        if (tick == 2) {
            return;
        }
    }
}

var tick: isize = 0;

test "threading" {
    const thread = try @call(.auto, std.Thread.spawn, .{ .{}, ticker, .{1} });
    try expect(tick == 0);
    thread.join();
    // std.time.sleep(3 * std.time.ns_per_s / 2);
    try expect(tick == 2);
}
