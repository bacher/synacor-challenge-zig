const std = @import("std");

const CHALLENGE_BIN_SIZE = 60100;
const wordType = u16;

pub fn main() !void {
    const file = try std.fs.cwd().openFile("./challenge/challenge.bin", .{});

    const stat = try file.stat();
    const binarySize = stat.size;

    std.debug.print("stat.size: {}\n", .{binarySize});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

    const buf103 = try allocator.alloc(u8, 103);
    defer {
        allocator.free(buf103);
    }

    std.debug.print("buf103        addr: {d}\n", .{@intFromPtr(&buf103)});
    std.debug.print("buf103[0]     addr: {d}\n", .{@intFromPtr(&buf103[0])});

    const buffer_aligned1: []align(4096) u8 = @alignCast(buf103);
    std.debug.print("buf103_a      type: {}\n", .{@TypeOf(buffer_aligned1)});
    std.debug.print("buf103_a      addr: {d}\n", .{@intFromPtr(&buffer_aligned1)});
    std.debug.print("buf103_a[0]   addr: {d}\n", .{@intFromPtr(&buffer_aligned1[0])});

    const buf102 = buf103[1..];

    std.debug.print("buf102        addr: {d}\n", .{@intFromPtr(&buf102)});
    std.debug.print("buf102[0]     addr: {d}\n", .{@intFromPtr(&buf102[0])});

    // const buffer_aligned2: []align(256) u8 = @alignCast(buf102);
    // std.debug.print("buf102_a      type: {}\n", .{@TypeOf(buffer_aligned2)});
    // std.debug.print("buf102_a      addr: {d}\n", .{@intFromPtr(&buffer_aligned2)});
    // std.debug.print("buf102_a[0]   addr: {d}\n", .{@intFromPtr(&buffer_aligned2[0])});

    const buffer = try allocator.alloc(u8, binarySize);
    // const buffer = try allocator.alignedAlloc(u8, 2, binarySize);
    defer {
        allocator.free(buffer);
    }

    // var buffer: []wordType = undefined;
    // const u8buffer: *[CHALLENGE_BIN_SIZE]u8 = @ptrCast(&buffer);

    // Buffer should be asserted with align by @alignCast or initially
    // created with proper alignment by calling alignedAlloc().
    const buffer_aligned: []align(2048) u8 = @alignCast(buffer);
    const buffer_u16: [*]u16 = @ptrCast(buffer_aligned);

    // Using regular @ptrCast, but alignedAlloc() is required.
    // const buffer_u16: [*]u16 = @ptrCast(buffer);

    // Casting of pointers also works, but it produces slice with
    // invalid .len field.
    // const buffer_u16: *[*]u16 = @ptrCast(&buffer);

    std.debug.print("buffer8       addr: {d}\n", .{@intFromPtr(&buffer)});
    std.debug.print("buffer8[0]    addr: {d}\n", .{@intFromPtr(&buffer[0])});
    std.debug.print("buffer8(a)    addr: {d}\n", .{@intFromPtr(&buffer_aligned)});
    std.debug.print("buffer8(a)[0] addr: {d}\n", .{@intFromPtr(&buffer_aligned[0])});
    std.debug.print("buffer16      addr: {d}\n", .{@intFromPtr(buffer_u16)});
    std.debug.print("buffer16[0]   addr: {d}\n", .{@intFromPtr(&buffer_u16[0])});

    std.debug.print("buffer_u8  {}  .len = {}\n", .{ @TypeOf(buffer), buffer.len });
    std.debug.print("buffer_u16 {}\n", .{@TypeOf(buffer_u16)});

    const bytes_read = file.readAll(buffer) catch |err| {
        std.debug.print("can't read the file: {!}", .{err});
        return;
    };

    std.debug.print("bytes_read: {}\n", .{bytes_read});

    // const bufferu16: [*]u16 = @ptrCast(buffer);
    std.debug.print("buffer[0]  : {d}\n", .{buffer_u16[0]});
    std.debug.print("buffer[0-3]  : {any}\n", .{buffer_u16[0..4]});
    std.debug.print("buffer[4-7]  : {any}\n", .{buffer_u16[4..8]});
    std.debug.print("buffer[8-11] : {any}\n", .{buffer_u16[8..12]});
    std.debug.print("buffer[12-15]: {any}\n", .{buffer_u16[12..16]});
    // std.debug.print("buffer[0]  : {d}\n", .{buffer_u16.*[0]});
    // std.debug.print("buffer[0-3]  : {any}\n", .{buffer_u16.*[0..4]});

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
