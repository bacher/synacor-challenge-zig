const std = @import("std");

const InnerState = struct {
    buffer: []u8,
    binary: [*]u16,
    binary_size: u64,
    allocator: std.mem.Allocator,
};

// ![]align(2) u8

pub const ChallengeData = struct {
    buffer: [*]u16,
    size: u64,
};

pub const ChallengeLoader = struct {
    _inner_state: ?InnerState = null,

    pub fn init(self: *ChallengeLoader, allocator: std.mem.Allocator) !void {
        var is_success = false;

        const file = try std.fs.cwd().openFile("./challenge/challenge.bin", .{});

        const stat = try file.stat();
        const binary_size = stat.size;

        const buffer = try allocator.alignedAlloc(u8, 2, binary_size);
        defer {
            if (!is_success) {
                allocator.free(buffer);
            }
        }

        const bytes_read = file.readAll(buffer) catch |err| {
            std.debug.print("can't read the file: {!}", .{err});
            return err;
        };

        try std.testing.expect(bytes_read == binary_size);

        self._inner_state = .{
            .allocator = allocator,
            .buffer = buffer,
            .binary = @ptrCast(buffer),
            .binary_size = binary_size,
        };

        is_success = true;
    }

    pub fn deinit(self: *ChallengeLoader) void {
        if (self._inner_state) |state| {
            state.allocator.free(state.buffer);
        }
    }

    pub fn getBinary(self: *ChallengeLoader) !ChallengeData {
        if (self._inner_state) |state| {
            return .{
                .buffer = state.binary,
                .size = state.binary_size,
            };
        }
        return error.NoInstanciated;
    }
};
