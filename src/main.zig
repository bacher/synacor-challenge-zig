const std = @import("std");

const CHALLENGE_BIN_SIZE = 60100;
const wordType = u16;

pub fn main() !void {
    const file = std.fs.cwd().openFile("./challenge/challenge.bin", .{}) catch {
        return error.LOL;
    };

    const stat = try file.stat();
    const binarySize = stat.size;

    std.debug.print("stat.size: {}\n", .{binarySize});

    var buffer: [CHALLENGE_BIN_SIZE / @sizeOf(wordType)]wordType = undefined;
    const u8buffer: *[CHALLENGE_BIN_SIZE]u8 = @ptrCast(&buffer);
    const bytes_read = file.readAll(u8buffer) catch |err| {
        std.debug.print("can't read the file: {!}", .{err});
        return;
    };

    std.debug.print("bytes_read: {}\n", .{bytes_read});
    std.debug.print("@sizeOf(u16): {}\n", .{@sizeOf(u16)});

    std.debug.print("buffer[0]: {}\n", .{buffer[0]});
    std.debug.print("buffer[1]: {}\n", .{buffer[1]});
    std.debug.print("buffer[2]: {}\n", .{buffer[2]});
    std.debug.print("buffer[3]: {}\n", .{buffer[3]});

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();
    //
    // try stdout.print("Run `zig build test` to run the tests.\n", .{});
    //
    // try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
