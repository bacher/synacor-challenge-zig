const std = @import("std");
const opCodes = @import("./op_codes.zig");
const ChallengeLoaderModule = @import("./challenge_loader.zig");
const vm = @import("./vm.zig");

const ChallengeLoader = ChallengeLoaderModule.ChallengeLoader;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

    var loader: ChallengeLoader = .{};
    try loader.init(allocator);
    defer loader.deinit();

    try vm.run(allocator, try loader.getBinary());
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
