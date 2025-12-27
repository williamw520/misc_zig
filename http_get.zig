
const std = @import("std");


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var client = std.http.Client{ .allocator = alloc };
    defer client.deinit();

    var response = std.Io.Writer.Allocating.init(alloc);
    defer response.deinit();

    const result1 = try client.fetch(.{
        .method = .GET,
        .location = .{ .uri = try std.Uri.parse("https://example.com") },
        .response_writer = &response.writer,
    });
    std.debug.print("\nHTTP Status: {}\n{s}\n", .{result1.status, response.written()});
    response.clearRetainingCapacity();

    const result2 = try client.fetch(.{
        .method = .GET,
        .location = .{ .uri = try std.Uri.parse("https://httpbin.org/get?abc=1&xyz=2") },
        .response_writer = &response.writer,
    });
    std.debug.print("\nHTTP Status: {}\n{s}\n", .{result2.status, response.written()});

    // const response1 = try httpGet(alloc, "https://example.com");
    // defer alloc.free(response1);
    // std.debug.print("{s}\n", .{response1});
}

fn httpGet(alloc: std.mem.Allocator, url: []const u8) ![]const u8 {
    var client = std.http.Client{ .allocator = alloc };
    defer client.deinit();

    var body_writer = std.Io.Writer.Allocating.init(alloc);
    _ = try client.fetch(.{
        .method = .GET,
        .location = .{ .uri = try std.Uri.parse(url) },
        .response_writer = &body_writer.writer,
    });
    return body_writer.toOwnedSlice();
}


