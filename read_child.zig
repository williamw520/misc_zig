
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    // The program to spawn as child process and its arguments.
    const argv: [2][]const u8 = .{ "/usr/bin/echo", "foo bar" };

    var child = std.process.Child.init(&argv, alloc);
    child.stdin_behavior  = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;
    try child.spawn();

    // try read_child_stdout_150(child.stdout.?);  // no problem in 0.15.0
    try read_child_stdout_151(child.stdout.?);  // problem in 0.15.1
    _ = try child.wait();
}

fn read_child_stdout_150(child_stdout_file: std.fs.File) !void {
    const reader = child_stdout_file.reader();
    var chunk: [1024]u8 = undefined;
    while (true) {
        const len = try reader.read(&chunk);
        if (len == 0) break;
        std.debug.print("Chunk: {s}\n", .{chunk[0..len]});
    }
}

fn read_child_stdout_151(child_stdout_file: std.fs.File) !void {
    var reader_buf: [1024]u8 = undefined;
    // Both .reader() and .readerStreaming() cause the same problem.
    var f_reader = child_stdout_file.reader(&reader_buf);
    // var f_reader = child_stdout_f.readerStreaming(&reader_buf);
    var reader = &f_reader.interface;
    var chunk: [1024]u8 = undefined;
    while (true) {
        const len = try reader.readSliceShort(&chunk);
        if (len == 0) break;
        std.debug.print("Chunk: {s}\n", .{chunk[0..len]});
    }
}


