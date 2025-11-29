
const std = @import("std");


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const res = try get(allocator, "https://example.com");
    defer allocator.free(res);
    std.debug.print("{s}\n", .{res});
}

fn get(allocator: std.mem.Allocator, a: []const u8) ![]const u8 {
    const uri = try std.Uri.parse(a);
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const server_header_buffer: []u8 = try allocator.alloc(u8, 1024 * 8);
    defer allocator.free(server_header_buffer);

    var req = try client.open(.GET, uri, .{
        .server_header_buffer = server_header_buffer,
    });
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    const body = try req.reader().readAllAlloc(allocator, 300000 * 8);
    return body;
}

