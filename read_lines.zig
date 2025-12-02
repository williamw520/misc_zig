const std = @import("std");

// Read a file line by line.
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Process command-line arguments for filename and delimiter.
    var argv = try std.process.argsWithAllocator(alloc);
    defer argv.deinit();
    _ = argv.next();
    const filename  = if (argv.next()) |a| std.mem.sliceTo(a, 0) else "test.txt";
    const delimiter = if (argv.next()) |a| std.mem.sliceTo(a, 0) else "\n";

    // Open the file for reading and create a buffered File.Reader.
    // The buffer size is intentionally small to show handling delimiters spanning buffer boundaries.
    // In production, use a more sensible buffer size (e.g., 4KB or 8KB).
    var file = try std.fs.cwd().openFile(filename, .{ .mode = .read_only });
    defer file.close();
    var read_buf: [2]u8 = undefined;
    var file_reader: std.fs.File.Reader = file.reader(&read_buf);

    // Obtain a pointer to the std.Io.Reader interface. This allows us to use generic IO operations.
    const reader = &file_reader.interface;

    // An accumulating writer to store segments read from the file.
    var line = std.Io.Writer.Allocating.init(alloc);
    defer line.deinit();

    // Main loop to read data segment by segment.
    while (true) {
        _ = reader.streamDelimiter(&line.writer, delimiter[0]) catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        _ = reader.toss(1);     // skip the delimiter byte.
        std.debug.print("{s}\n", .{ line.written() });
        line.clearRetainingCapacity();
    }

    // Handle any remaining data after the last delimiter.
    if (line.written().len > 0) {
        std.debug.print("{s}\n", .{ line.written() });
    }
}



