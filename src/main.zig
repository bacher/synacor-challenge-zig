const std = @import("std");
const opCodes = @import("./op_codes.zig");
const challengeLoaderModule = @import("./challenge_loader.zig");
const vmModule = @import("./vm.zig");

const ChallengeLoader = challengeLoaderModule.ChallengeLoader;
// const InnerState = challengeLoaderModule.InnerState;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

    const a = ChallengeLoader{
        // ._inner_state = InnerState{
        //     .binary = @constCast(&[_]u16{0}**10),
        //     .allocator = allocator,
        // },
        ._inner_state = .{
            .binary = @constCast(&[_]u16{0} ** 10),
            .allocator = allocator,
        },
    };
    _ = a;

    var loader = try ChallengeLoader.init(allocator);
    defer loader.deinit();

    var vm = vmModule.Vm.initVm(allocator, loader.getBinary());
    defer vm.deinit();

    std.debug.print("vm address:        {*}\n", .{&vm});
    std.debug.print("memory address:    {*}\n", .{&vm.memory});
    std.debug.print("memory[0] address: {*}\n", .{&vm.memory[0]});
    std.debug.print("memory[0] value:   {d}\n", .{vm.memory[0]});
    std.debug.print("memory[1] value:   {d}\n", .{vm.memory[1]});
    std.debug.print("memory[2] value:   {d}\n", .{vm.memory[2]});

    try vm.run();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
