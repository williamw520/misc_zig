const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;


const Machine = struct {
    n_lights:   usize,
    indicator:  u16,
    btn_bits:   ArrayList(u16),
    joltages:   ArrayList(usize),
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
    }
    return result;
}

fn parseNumbersByDelimiter(alloc: Allocator, str: []const u8, delimiter: u8) !ArrayList(usize) {
    var result: ArrayList(usize) = .empty;
    var itr = std.mem.splitScalar(u8, str, delimiter);
    while (itr.next()) |term| {
        const num = try std.fmt.parseInt(u16, std.mem.trim(u8, term, " "), 10);
        try result.append(alloc, num);
    }
    return result;
}

fn toIndicatorBits(idr_str: []const u8) u16 {
    var bits: u16 = 0;
    for (idr_str, 0..)|ch, pos| {
        if (ch == '#')
            bits |= @as(u16, 1) << @intCast(pos);
    }
    return bits;
}

fn toButtonBits(alloc: Allocator, btn_str: []const u8) !u16 {
    var bits: u16 = 0;
    const btn_positions = try parseNumbersByDelimiter(alloc, btn_str, ',');
    for (btn_positions.items) |pos|
        bits |= @as(u16, 1) << @intCast(pos);
    return bits;
}

// [###.] (1,3) (0,1,2) {4,13,4,9}
fn parseLine(alloc: Allocator, line: []const u8) !Machine {
    const indicator = parseByBrackets(line, '[', ']') orelse unreachable;
    const jolt_str  = parseByBrackets(line, '{', '}') orelse unreachable;
    const joltages  = try parseNumbersByDelimiter(alloc, jolt_str, ',');
    const buttons   = try parseTermsByBrackets(alloc, line, '(', ')');
    var btn_bits    = try ArrayList(u16).initCapacity(alloc, 10);
    for (buttons.items) |btn_str| {
        try btn_bits.append(alloc, try toButtonBits(alloc, btn_str));
    }
    return .{
        .n_lights = indicator.len,
        .indicator = toIndicatorBits(indicator),
        .btn_bits = btn_bits,
        .joltages = joltages,
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

    var machines: ArrayList(Machine) = .empty;
    for ((try FileLines.read(alloc, std.fs.cwd(), fname)).trimmed()) |line| {
        try machines.append(alloc, try parseLine(alloc, line));
    }

    // Part 1
    
    var min_count_sum: usize = 0;
    for (machines.items) |machine| {
        // Each button is represented by one bit for participating in one round of pressing.
        // A bit mask represents all buttons (bits) participating in one round of pressing.
        // Run through all the bit combinations of the button bits on the bit mask.
        // The number of buttons in the data is no more than 10; can fit in a 64-bit bit mask.
        const btn_count = machine.btn_bits.items.len;
        const rounds: usize = @as(usize, 1) << @intCast(btn_count);
        var min_count = rounds;         // track the lowest attempts for target matched in each round.
        for (0..rounds) |i| {
            var count:  usize = 0;
            var lights: u16 = 0;        // state of indicator light bits, started as all off.
            var mask:   usize = i;      // bits of the buttons; each bit position is a button index.
            var found:  bool = false;
            while (!found and mask != 0) : (mask &= mask - 1) {
                const bit_pos = @ctz(mask);
                const btn_bits = machine.btn_bits.items[bit_pos];
                lights ^= btn_bits;     // apply the bits of one button to the light bits.
                count += 1;             // record one button pressed.
                found = lights == machine.indicator;
                // std.debug.print("pos: {}, btn: {b:010}, light: {b:010};  ", .{bit_pos, btn_bits, light});
            }
            if (found) {
                min_count = @min(min_count, count);
                // std.debug.print("found: {}, count: {}, min: {}\n", .{found, count, min_count});
            }
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
        var s: usize = 0;               // start index
        var e: usize = raw_lines.len;   // end index
        while (s < raw_lines.len and raw_lines[s].len == 0) : (s += 1) {}
        while (e > 0 and raw_lines[e - 1].len == 0) : (e -= 1) {}
        return raw_lines[s..e];
    }

    fn dump(self: *const FileLines) void {
        for (self.trimmed()) |l| {
            std.debug.print("{s}\n", .{l});
        }
    }
    
};


