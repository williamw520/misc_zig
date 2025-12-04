const std = @import("std");

// Read a file fully into a buffer.
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
    const file_size = (try file.stat()).size;
    const data = try alloc.alloc(u8, file_size);
    defer alloc.free(data);
    var file_reader = file.reader(data);
    try file_reader.interface.fill(file_size);

    std.debug.print("{s}\n", .{data});
}


