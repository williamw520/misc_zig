const std = @import("std");
const Allocator = std.mem.Allocator;


// Read a file into lines.
pub const FileLines = struct {
    alloc:      Allocator,
    file_data:  []const u8,                 // data of the entire file.
    slices:     std.ArrayList([]const u8),  // slices into the file data.

    pub fn read(alloc: Allocator, dir: std.fs.Dir, filename: []const u8) !FileLines {
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


// Part 1 
const Op = enum { plus, multiply };

fn toOp(str: []const u8) Op {
    if (str[0] == '+') return Op.plus;
    if (str[0] == '*') return Op.multiply;
    unreachable;
}

fn toNum(str: []const u8) usize {
    return std.fmt.parseInt(usize, str, 10) catch unreachable;
}

fn split(alloc: Allocator, line: []const u8, T: type, to_fn: anytype) ![]T {
    var slices: std.ArrayList(T) = .empty;
    var itr = std.mem.tokenizeScalar(u8, line, ' ');
    while (itr.next()) |term| try slices.append(alloc, to_fn(term));
    return try slices.toOwnedSlice(alloc);
}

// Part 2
const ColInfo = struct {
    start: usize = 0,
    width: usize = 0,
};

fn findColumnWidths(alloc: Allocator, operator_row: []const u8) !std.ArrayList(ColInfo) {
    var widths: std.ArrayList(ColInfo) = .empty;
    var start: usize = 0;
    var width: usize = 0;
    var itr = std.mem.splitScalar(u8, operator_row, ' ');
    while (itr.next()) |term| {
        if (term.len == 0) {
            width += 1;
            continue;
        }
        if (width == 0)
            continue;           // handle first column

        try widths.append(alloc, .{ .start = start, .width = width+1 });

        // next column
        start += width + 1 + 1; // +1 for the op itself, +1 for last space.
        width = 0;
    }
    try widths.append(alloc, .{ .start = start, .width = width+1 });
    return widths;
}

fn transformOperands(alloc: Allocator, cols: std.ArrayList(ColInfo),
                     operand_lines: [][]const u8) !std.ArrayList(std.ArrayList(usize)) {
    var column_operands: std.ArrayList(std.ArrayList(usize)) = .empty;
    for (cols.items) |col| {
        var operands: std.ArrayList(usize) = .empty;
        for (0..col.width) |i| {
            var num: usize = 0;
            for (operand_lines) |line| {
                const ch = line[col.start+i];
                if (ch == ' ') continue;
                const digit: usize = @intCast(ch - '0');
                num = num * 10 + digit;
            }
            try operands.append(alloc, num);
        }
        try column_operands.append(alloc, operands);
    }
    return column_operands;
}


pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const alloc = arena.allocator();

    var argv = try std.process.argsWithAllocator(alloc);
    _ = argv.next();
    const fname = if (argv.next()) |a| std.mem.sliceTo(a, 0) else "input6.txt";

    // Read in all lines from the file.
    var fl = try FileLines.read(alloc, std.fs.cwd(), fname);

    // Trim any trailing blank lines.
    var nrows = fl.lines().len;
    while (nrows > 0 and fl.lines()[nrows - 1].len == 0) { nrows -= 1; }
    std.debug.assert(nrows > 1);

    // Parse operators
    const operator_row_idx = nrows - 1;
    const operator_row = fl.lines()[operator_row_idx];
    const operators = try split(alloc, operator_row, Op, toOp);

    // ---- Part 1 ----

    // Parse operands
    var operand_rows: std.ArrayList([]usize) = .empty;
    const operand_lines = fl.lines()[0..operator_row_idx];
    for (operand_lines) |row| {
        try operand_rows.append(alloc, try split(alloc, row, usize, toNum));
    }

    // Go over the columns. For each column, go over the rows.
    var total1: usize = 0;
    for (operators, 0..) |op, col| {
        switch (op) {
            .plus => {
                var sum: usize = 0;
                for (operand_rows.items) |row| sum += row[col];
                total1 += sum;
            },
            .multiply => {
                var product: usize = 1;
                for (operand_rows.items) |row| product *= row[col];
                total1 += product;
            },
        }
    }

    std.debug.print("total1: {}\n", .{total1});

    // ---- Part 2 ----
    const col_infos = try findColumnWidths(alloc, operator_row);
    std.debug.assert(col_infos.items.len == operators.len);

    const column_operands = try transformOperands(alloc, col_infos, operand_lines);

    // Go over the columns. For each column, go over its numbers.
    var total2: usize = 0;
    for (operators, column_operands.items) |op, operands| {
        switch (op) {
            .plus => {
                var sum: usize = 0;
                for (operands.items) |num| sum += num;
                total2 += sum;
            },
            .multiply => {
                var product: usize = 1;
                for (operands.items) |num| product *= num;
                total2 += product;
            },
        }
    }
    
    std.debug.print("total2: {}\n", .{total2});
}

