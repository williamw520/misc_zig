const std = @import("std");

// Read a file fully into a buffer with terminating '\0'.
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
    const file_size = try file.getEndPos();
    const read_buf = try alloc.allocWithOptions(u8, file_size, null, 0);    // alloc with '\0' byte.
    defer alloc.free(read_buf);
    var file_reader = file.reader(read_buf);
    try file_reader.interface.fill(file_size);
    const data = read_buf[0..file_size:0];
    std.debug.print("{any}\n", .{read_buf});
    std.debug.print("{s}\n", .{data});
}



