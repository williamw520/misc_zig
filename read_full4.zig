const std = @import("std");

// Read a stream fully into a buffer without knowing the data size.
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var argv = try std.process.argsWithAllocator(alloc);
    defer argv.deinit();
    _ = argv.next();
    const filename = if (argv.next()) |a| std.mem.sliceTo(a, 0) else "test.txt";

    var file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();

    var read_buf: [4096]u8 = undefined;
    var f_reader = file.reader(&read_buf);

    var buf = std.Io.Writer.Allocating.init(alloc);
    defer buf.deinit();
    const bytes_read = try f_reader.interface.streamRemaining(&buf.writer);

    std.debug.print("bytes: {}\n", .{bytes_read});
    std.debug.print("{s}\n", .{buf.written()});
}


