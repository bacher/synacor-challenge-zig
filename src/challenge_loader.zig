const std = @import("std");

const InnerState = struct {
    binary: []u16,
    allocator: std.mem.Allocator,
};

pub const ChallengeLoader = struct {
    _inner_state: ?InnerState = null,

    pub fn init(allocator: std.mem.Allocator) !ChallengeLoader {
        var is_success = false;

        const file = try std.fs.cwd().openFile("./challenge/challenge.bin", .{});

        const stat = try file.stat();
        const binary_size = stat.size;

        if (binary_size % 2 != 0) {
            return error.InvalidChallengeFile;
        }

        const buffer = try allocator.alloc(u16, binary_size / 2);
        defer {
            if (!is_success) {
                allocator.free(buffer);
            }
        }

        const buffer_u8 = std.mem.sliceAsBytes(buffer);

        const bytes_read = file.readAll(buffer_u8) catch |err| {
            std.debug.print("can't read the file: {!}", .{err});
            return err;
        };

        try std.testing.expect(bytes_read == binary_size);

        is_success = true;

        return .{ ._inner_state = .{
            .allocator = allocator,
            .binary = buffer,
        } };
    }

    pub fn deinit(self: *ChallengeLoader) void {
        if (self._inner_state) |state| {
            state.allocator.free(state.binary);
        }
    }

    pub fn getBinary(self: *ChallengeLoader) ![]u16 {
        if (self._inner_state) |state| {
            return state.binary;
        }
        return error.NoInstanciated;
    }
};
