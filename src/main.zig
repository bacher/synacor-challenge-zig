const std = @import("std");
const opCodes = @import("./op_codes.zig");
const challengeLoaderModule = @import("./challenge_loader.zig");
const vmModule = @import("./vm.zig");

const ChallengeLoader = challengeLoaderModule.ChallengeLoader;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

    var loader: ChallengeLoader = .{};
    try loader.init(allocator);
    defer loader.deinit();

    var vm = vmModule.Vm.initVm(allocator, try loader.getBinary());
    defer vm.deinit();

    try vm.run();

    // try vmModule.run(allocator, try loader.getBinary());
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
