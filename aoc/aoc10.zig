const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;


const Machine = struct {
    n_lights:   usize,
    indicator:  u16,
    btn_bits:   ArrayList(u16),
};

fn parseByBrackets(str: []const u8, left: u8, right: u8) ?[]const u8 {
    const start = std.mem.indexOfScalar(u8, str, left) orelse return null;
    const end   = std.mem.indexOfScalar(u8, str, right) orelse return null;
    if (end <= start) return null;
    return str[start + 1 .. end];
}

fn parseTermsByBrackets(alloc: Allocator, str: []const u8, left: u8, right: u8) !ArrayList([]const u8) {
    var result: ArrayList([]const u8) = .empty;
    var i: usize = 0;

    while (i < str.len) {
        const start = std.mem.indexOfScalarPos(u8, str, i, left) orelse break;
        const end   = std.mem.indexOfScalarPos(u8, str, start, right) orelse break;
        try result.append(alloc, str[start+1..end]);
        i = end + 1;
        // std.debug.print("{s} : ", .{str[start+1..end]});
    }
    // std.debug.print("\n", .{});
    return result;
}

fn toButtonBits(btn_str: []const u8) u16 {
    var itr = std.mem.splitScalar(u8, btn_str, ',');
    var bits: u16 = 0;
    while (itr.next()) |pos_str| {
        const pos = std.fmt.parseInt(u16, std.mem.trim(u8, pos_str, " "), 10) catch unreachable;
        bits |= @as(u16, 1) << @intCast(pos);
    }
    return bits;
}

fn toIndicatorBits(idr_str: []const u8) u16 {
    var bits: u16 = 0;
    for (idr_str, 0..)|ch, pos| {
        if (ch == '#')
            bits |= @as(u16, 1) << @intCast(pos);
    }
    return bits;
}

// [###.] (1,3) (0,1,2) {4,13,4,9}
fn parseLine(alloc: Allocator, line: []const u8) !Machine {
    const indicator = parseByBrackets(line, '[', ']') orelse unreachable;
    const idr_bits = toIndicatorBits(indicator);
    // std.debug.print("{s}\n", .{indicator});
    // std.debug.print("{b:010}\n", .{idr_bits});
    
    const joltage = parseByBrackets(line, '{', '}') orelse unreachable;
    _=joltage;
    // std.debug.print("{s}\n", .{joltage});
    
    const buttons = try parseTermsByBrackets(alloc, line, '(', ')');
    // std.debug.print("{any}\n", .{buttons});
    var btn_bits: ArrayList(u16) = .empty;
    for (buttons.items) |btn_str| {
        const bits = toButtonBits(btn_str);
        try btn_bits.append(alloc, bits);
        // std.debug.print("{b:010} : ", .{bits});
    }
    // std.debug.print("\n", .{});

    return .{
        .n_lights = indicator.len,
        .indicator = idr_bits,
        .btn_bits = btn_bits,
    };
}


pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const alloc = arena.allocator();

    var argv = try std.process.argsWithAllocator(alloc);
    _ = argv.next();
    const fname = if (argv.next()) |a| std.mem.sliceTo(a, 0) else "input10.txt";

    // Read in all lines from the file.
    var fl = try FileLines.read(alloc, std.fs.cwd(), fname);
    // std.debug.print("{any}\n", .{fl.trimmed()});

    var machines: ArrayList(Machine) = .empty;
    for (fl.trimmed()) |line| {
        try machines.append(alloc, try parseLine(alloc, line));
    }
    // std.debug.print("{any}\n", .{machines});

    // Part 1
    
    var min_count_sum: usize = 0;
    for (machines.items) |m| {
        // Each button is represented by one bit for participating one round of pushing.
        // One bit mask represents all buttons (bits) participating one round of pushing.
        const btn_count = m.btn_bits.items.len;
        const rounds: usize = @as(usize, 1) << @intCast(btn_count);
        // std.debug.print("btn_count: {}, rounds: {}\n", .{btn_count, rounds});

        // Run through all the bit combinations of the needed bits for the bit mask.
        var min_count: usize = rounds;
        var i: usize = 0;
        while (i < rounds) : (i += 1) {
            var mask: usize = i;
            var count: usize = 0;
            var light: u16 = 0;
            var found: bool = false;
            // std.debug.print("\nmask: {b:010}, idr: {b:010}\n", .{mask, m.indicator});
            while (mask != 0) : (mask &= mask - 1) {
                const bit_pos = @ctz(mask);
                const btn_bits = m.btn_bits.items[bit_pos];
                light ^= btn_bits;
                // std.debug.print("pos: {}, btn: {b:010}, light: {b:010};  ", .{bit_pos, btn_bits, light});
                count += 1;
                found = light == m.indicator;
                if (found) break;
            }
            if (found and count > 0)
                min_count = @min(min_count, count);
            // if (found)
            //     std.debug.print("found: {}, count: {}, min: {}\n", .{found, count, min_count});
        }
        // std.debug.print("\n", .{});
        min_count_sum += min_count;
    }

    std.debug.print("Part 1: min_count_sum: {}\n", .{min_count_sum});
}


// Read a file into lines.
pub const FileLines = struct {
    alloc:      std.mem.Allocator,
    file_data:  []const u8,                 // data of the entire file.
    slices:     ArrayList([]const u8),      // slices into the file data.

    fn read(alloc: std.mem.Allocator, dir: std.fs.Dir, filename: []const u8) !FileLines {
        const data = try std.fs.Dir.readFileAlloc(dir, filename, alloc, .unlimited);
        var slices: ArrayList([]const u8) = .empty;
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

    fn deinit(self: *FileLines) void {
        self.alloc.free(self.file_data);
        self.slices.deinit(self.alloc);
    }

    fn lines(self: *const FileLines) [][]const u8 {
        return self.slices.items;
    }

    /// Trim any leading and trailing empty lines.
    fn trimmed(self: *const FileLines) [][]const u8 {
        const raw_lines = self.lines();
        var start: usize = 0;
        while (start < raw_lines.len) : (start += 1) {
            if (raw_lines[start].len > 0) break;
        }
        var end: usize = raw_lines.len;
        while (end > 0) : (end -= 1) {
            if (raw_lines[end - 1].len > 0) break;
        }
        return raw_lines[start..end];
    }

    fn dump(self: *const FileLines) void {
        for (self.trimmed()) |l| {
            std.debug.print("{s}\n", .{l});
        }
    }
    
};


