const std = @import("std");


// Read a file into lines.
pub const FileLines = struct {
    alloc:      std.mem.Allocator,
    file_data:  std.Io.Writer.Allocating,       // data of the entire file.
    slices:     std.ArrayList([]const u8),      // slices into the file data.

    pub fn read(alloc: std.mem.Allocator, dir: std.fs.Dir, filename: []const u8) !FileLines {
        var file = try dir.openFile(filename, .{});
        defer file.close();

        const buf = try alloc.alloc(u8, 4096);  // use heap; avoid impacting the stack.
        defer alloc.free(buf);
        var f_reader = file.reader(buf);
        var file_data = std.Io.Writer.Allocating.init(alloc);
        _ = try f_reader.interface.streamRemaining(&file_data.writer);

        var line_slices: std.ArrayList([]const u8) = .empty;
        var itr = std.mem.splitScalar(u8, file_data.written(), '\n');
        while (itr.next()) |line| {
            try line_slices.append(alloc, std.mem.trim(u8, line, "\r"));
        }

        return .{
            .alloc = alloc,
            .file_data = file_data,
            .slices = line_slices,
        };
    }

    pub fn deinit(self: *FileLines) void {
        self.file_data.deinit();
        self.slices.deinit(self.alloc);
    }

    pub fn lines(self: *const FileLines) [][]const u8 {
        return self.slices.items;
    }
};

// Read a file into FileLines.
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Process command-line arguments for filename.
    var argv = try std.process.argsWithAllocator(alloc);
    defer argv.deinit();
    _ = argv.next();
    const filename = if (argv.next()) |a| std.mem.sliceTo(a, 0) else "test.txt";

    // Read the file into lines.
    var fl = try FileLines.read(alloc, std.fs.cwd(), filename);
    defer fl.deinit();

    // Access the lines.
    for (fl.lines())|line| {
        std.debug.print("line = '{s}'\n", .{line});
    }
}



