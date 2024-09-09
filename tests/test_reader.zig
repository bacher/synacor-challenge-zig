const std = @import("std");

test "test Reader" {
    const nums = [_]u32{ 0xDEAD, 0xBEEF, 0xF000, 0xB335 };
    const nums_mem = std.mem.sliceAsBytes(&nums);

    var stream = std.io.fixedBufferStream(nums_mem);
    const stream_reader = stream.reader();

    var buffered_reader = std.io.bufferedReader(stream_reader);
    var numbers = std.ArrayList(u32).init(std.testing.allocator);
    defer numbers.deinit();
    var parsed_number_buffer: [4]u8 = undefined;

    while (true) {
        const bytes_read = try buffered_reader.read(&parsed_number_buffer);
        if (bytes_read == 0) {
            break;
        }

        try std.testing.expect(bytes_read == 4);

        const parsed_num = std.mem.readPackedIntNative(u32, &parsed_number_buffer, 0);
        try numbers.append(parsed_num);
    }

    std.debug.print("items = {any}\n", .{numbers.items});
}
