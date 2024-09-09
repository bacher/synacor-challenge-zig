const std = @import("std");

fn nextLine(reader: anytype, buffer: []u8) !?[]const u8 {
    return (try reader.readUntilDelimiterOrEof(
        buffer,
        '\n',
    )) orelse return null;
}

test "read until next line" {
    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn();

    try stdout.writeAll(
        \\ Enter your name:
    );

    var buffer: [10]u8 = undefined;
    const input = (try nextLine(stdin.reader(), &buffer)).?;
    try stdout.writer().print(
        "Your name is: \"{s}\"\n",
        .{input},
    );
}
