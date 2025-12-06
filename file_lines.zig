const std = @import("std");


// Read a file into lines.
pub const FileLines = struct {
    alloc:      std.mem.Allocator,
    file_data:  []const u8,                 // data of the entire file.
    slices:     std.ArrayList([]const u8),  // slices into the file data.

    pub fn read(alloc: std.mem.Allocator, dir: std.fs.Dir, filename: []const u8) !FileLines {
        const data = try std.fs.Dir.readFileAlloc(dir, filename, alloc, .unlimited);
        var slices: std.ArrayList([]const u8) = .empty;
        var itr = std.mem.splitScalar(u8, data, '\n');
        while (itr.next()) |line| {
            try slices.append(alloc, std.mem.trim(u8, line, "\r"));
        }

        return .{
            .alloc = alloc,
            .file_data = data,
            .slices = slices,
        };
    }

    pub fn deinit(self: *FileLines) void {
        self.alloc.free(self.file_data);
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



