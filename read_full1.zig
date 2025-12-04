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

    const data = try std.fs.Dir.readFileAlloc(std.fs.cwd(), filename, alloc, .unlimited);
    defer alloc.free(data);

    std.debug.print("{s}\n", .{data});
}


