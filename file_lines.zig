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

    /// Trim any leading and trailing empty lines.
    fn trimmed(self: *const FileLines) [][]const u8 {
        const raw_lines = self.lines();    
        var s: usize = 0;               // start index
        var e: usize = raw_lines.len;   // end index
        while (s < raw_lines.len and raw_lines[s].len == 0) : (s += 1) {}
        while (e > 0 and raw_lines[e - 1].len == 0) : (e -= 1) {}
        return raw_lines[s..e];
    }

    fn dump(self: *const FileLines) void {
        for (self.trimmed()) |line| {
            std.debug.print("{s}\n", .{line});
        }
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

    std.debug.print("--------\n", .{});
    // Access the lines.
    for (fl.trimmed())|line| {
        std.debug.print("line = '{s}'\n", .{line});
    }
    
}



