
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
        .method = .POST,
        .payload = "abc",
        .location = .{ .uri = try std.Uri.parse("https://httpbin.org/post") },
        .response_writer = &response.writer,
    });
    std.debug.print("\nHTTP Status: {}\n{s}\n", .{result1.status, response.written()});
    response.clearRetainingCapacity();
    
    const result2 = try client.fetch(.{
        .method = .POST,
        .headers = .{
            .user_agent = .{ .override = "Back to Basics Blog" },
            .authorization = .{ .override = "Session key 123" },
        },
        .extra_headers = &[_]std.http.Header{
            .{ .name = "Accept", .value = "application/json" }
        },
        .payload = "{ \"abc\": 123, \"xyz\": 456 }",
        .location = .{ .uri = try std.Uri.parse("https://httpbin.org/post") },
        .response_writer = &response.writer,
    });
    std.debug.print("\nHTTP Status: {}\n{s}\n", .{result2.status, response.written()});
    response.clearRetainingCapacity();

    // const response_body = try httpPost(alloc, "https://httpbin.org/post", "abc");
    // defer alloc.free(response_body);
    // std.debug.print("{s}\n", .{response_body});
}

fn httpPost(alloc: std.mem.Allocator, url: []const u8, payload: []const u8) ![]const u8 {
    var client = std.http.Client{ .allocator = alloc };
    defer client.deinit();

    var response = std.Io.Writer.Allocating.init(alloc);
    const result = try client.fetch(.{
        .method = .POST,
        .payload = payload,
        .location = .{ .uri = try std.Uri.parse(url) },
        .response_writer = &response.writer,
    });
    std.debug.print("HTTP Status: {}\n", .{result.status});

    return response.toOwnedSlice();
}

