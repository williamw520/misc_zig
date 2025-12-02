
// Run with -O ReleaseFast when running the benchmarks.
//
//  zig test -O ReleaseFast simd_max_index.zig
//

const std = @import("std");

/// N - array length. 
/// T - array element type.
/// N * sizeof(T) should be a multiple of the SIMD register byte size.
/// array - the array data.
/// start, end - range of elements to search, inclusive.
pub fn maxIndex(comptime N: usize, comptime T: type, comptime MIN: T,
                array: *const [N]T, start: usize, end: usize) usize {
    const VecT: type        = @Vector(N, T);
    const v_lowest: VecT    = @splat(MIN);                  // for padding
    const IndexI: type      = std.simd.VectorIndex(VecT);   // index type
    const VecI: type        = @Vector(N, IndexI);
    const vi_iota: VecI     = std.simd.iota(IndexI, N);
    const vi_hi_idx: VecI   = @splat(~@as(IndexI, 0));      // highest index

    const v_array: VecT     = array.*;
    const vi_start: VecI    = @splat(@intCast(start));
    const vi_end: VecI      = @splat(@intCast(end));
    const vb_clamp_mask     = (vi_iota >= vi_start) & (vi_iota <= vi_end);
    const v_clamped: VecT   = @select(T, vb_clamp_mask, v_array, v_lowest);
    const max_value: T      = @reduce(.Max, v_clamped);
    const v_max_value: VecT = @splat(max_value);
    const vb_max_mask       = v_clamped == v_max_value;     // mark the max items
    const vi_indices: VecI  = @select(IndexI, vb_max_mask, vi_iota, vi_hi_idx);
    const max_idx: IndexI   = @reduce(.Min, vi_indices);

    // std.debug.print("v_array: {any}\n", .{v_array});
    // std.debug.print("v_clamped: {any}\n", .{v_clamped});
    // std.debug.print("max_value: {any}\n", .{max_value});
    // std.debug.print("vi_indices: {any}\n", .{vi_indices});
    // std.debug.print("max_idx: {any}\n", .{max_idx});
    return max_idx;
}

pub fn maxIndex_reg(comptime N: usize, comptime T: type,
                    array: *const [N]T, start: usize, end: usize) usize {
    var max_value = array[start];
    var max_index: usize = start;
    var i = start + 1;

    while (i <= end) {
        if (array[i] > max_value) {
            max_value = array[i];
            max_index = i;
        }
        i += 1;
    }
    std.mem.doNotOptimizeAway(max_value);
    return max_index;
}


export fn test1() usize {
    const N = 16;
    const T = i32;
    const arr1: [N]T = .{ 9, 2, -17, -7123, 1, 2, 50, -24 } ** 1 ++ .{ -9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999 };
    return maxIndex(N, T, -9999, &arr1, 3, 14);
}

export fn test2() usize {
    const N = 16;
    const T = i32;
    const arr1: [N]T = .{ 9, 2, -17, -7123, 1, 2, 50, -24 } ** 1 ++ .{ 99, 99, 99, 99, 99, 99, 99, 99 };
    return maxIndex(N, T, -9999, &arr1, 3, 8);
}

export fn test3() usize {
    const N = 256;
    const T = i32;
    const arr1: [N]T = .{ 9.0, 2.0, 17.0, 11.0, 1.0, 2.0, 50.0, 24.0 } ** 31 ++ .{ 0, 0, 0, 0, 0, 0, 0, 0 };
    return maxIndex(N, T, 0, &arr1, 3, 249);
}

export fn test4() usize {
    const N = 32;
    const T = f16;
    const arr1: [N]T = .{ 9, 2, 17, 11, 1, 2, 50, 24 } ** 3 ++ .{ 99, 101, 17, 11, 1, 2, 101, 99 };
    return maxIndex(N, T, 0, &arr1, 3, 29);
}



test {
    const N = 64;
    const T = i8;
    const arr1: [N]T = .{ -9, -2, -17, -11, -1, -2, -50, -24 } ** 7 ++ .{ -127, -127, -127, -127, -127, -127, -127, -127 };

    std.debug.print("arr1: {any}\n", .{arr1});
    std.debug.print("1. max_idx: {} between {} and {}\n", .{maxIndex(N, T, -127, &arr1, 3, 8), 3, 8});
    std.debug.print("2. max_idx: {} between {} and {}\n", .{maxIndex(N, T, -127, &arr1, 5, 19), 5, 19});
}

test {
    const N = 32;
    const T = i32;
    const arr1: [N]T = .{ 9, 2, -17, -7123, 1, 2, 50, -24 } ** 3 ++ .{ -9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999 };
    std.debug.print("arr1: {any}\n", .{arr1});
    std.debug.print("1. max_idx: {} between {} and {}\n", .{maxIndex(N, T, -9999, &arr1, 3, 8), 3, 8});
    std.debug.print("2. max_idx: {} between {} and {}\n", .{maxIndex(N, T, -9999, &arr1, 7, 31), 7, 31});
}

test {
    const N = 32;
    const T = u16;
    const arr1: [N]T = .{ 9, 2, 17, 11, 1, 2, 50, 24 } ** 3 ++ .{ 99, 101, 17, 11, 1, 2, 101, 99 };

    std.debug.print("arr1: {any}\n", .{arr1});
    std.debug.print("1. max_idx: {} between {} and {}\n", .{maxIndex(N, T, 0, &arr1, 3, 29), 3, 29});
    std.debug.print("2. max_idx: {} between {} and {}\n", .{maxIndex(N, T, 0, &arr1, 5, 24), 5, 24});
}

test {
    const N = 256;
    const T = u32;
    const arr1: [N]T = .{ 9, 2, 17, 11, 1, 2, 50, 24 } ** 31 ++ .{ 99, 101, 17, 11, 1, 2, 101, 99 };

    std.debug.print("arr1: {any}\n", .{arr1});
    std.debug.print("1. max_idx: {} between {} and {}\n", .{maxIndex(N, T, 0, &arr1, 3, 29), 3, 29});
    std.debug.print("2. max_idx: {} between {} and {}\n", .{maxIndex(N, T, 0, &arr1, 5, 250), 5, 250});

    try std.testing.expectEqual(maxIndex(N, T, 0, &arr1, 3, 29), maxIndex_reg(N, T, &arr1, 3, 29));
    try std.testing.expectEqual(maxIndex(N, T, 0, &arr1, 5, 250), maxIndex_reg(N, T, &arr1, 5, 250));
}

test {
    const N = 64;
    const T = i8;
    const arr1: [N]T = .{ -9, -2, -17, -11, -1, -2, -50, -24 } ** 7 ++ .{ 1, 2, 3, 4, 5, 6, 7, 8 };

    std.debug.print("arr1: {any}\n", .{arr1});
    std.debug.print("1. max_idx: {} between {} and {}\n", .{maxIndex(N, T, -127, &arr1, 0, 0), 0, 0});
    std.debug.print("2. max_idx: {} between {} and {}\n", .{maxIndex(N, T, -127, &arr1, 5, 63), 5, 63});
    std.debug.print("3. max_idx: {} between {} and {}\n", .{maxIndex(N, T, -127, &arr1, 63, 63), 63, 63});

    try std.testing.expectEqual(maxIndex(N, T, -127, &arr1, 0, 0), maxIndex_reg(N, T, &arr1, 0, 0));
    try std.testing.expectEqual(maxIndex(N, T, -127, &arr1, 5, 63), maxIndex_reg(N, T, &arr1, 5, 63));
    try std.testing.expectEqual(maxIndex(N, T, -127, &arr1, 63, 63), maxIndex_reg(N, T, &arr1, 63, 63));
}


pub fn randomNumbers(comptime T: type, numbers: []T, seed: u64) void {
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    for (numbers) |*num| {
        if (@typeInfo(T) == .int) {
            num.* = rand.int(T);
        } else if (@typeInfo(T) == .float) {
            num.* = rand.float(T);
        } else {
            @compileError("Unsupported type: " ++ @typeName(T));
        }
    }
}

test {
    const alloc = std.testing.allocator;

    const slice1 = try alloc.alloc(u8, 64);
    defer alloc.free(slice1);
    randomNumbers(u8, slice1, 0);
    // std.debug.print("rand slice1: {any}\n", .{slice1});
    
    const slice2 = try alloc.alloc(f32, 64);
    defer alloc.free(slice2);
    randomNumbers(f32, slice2, 0);
    // std.debug.print("rand slice2: {any}\n", .{slice2});
}

// N - number of nodes, B - dependency branching factor, M - max_range flag, R - repeats
fn benchmark(comptime N: usize, comptime T: type, comptime MIN: T, repeat: usize, seed: u64, comptime stepping: bool) !f128 {
    const alloc = std.testing.allocator;
    const ptr = try alloc.alloc(T, N);
    defer alloc.free(ptr);
    const array: *[N]T = @as(*[N]T, @ptrCast(ptr.ptr));
    randomNumbers(T, array, seed);

    const start_ns1 = std.time.nanoTimestamp();
    for (0..repeat) |_| {
        for (array, 0..) |_, i| {
            const start = if (stepping) i else 0;
            const max_idx = maxIndex(N, T, MIN, array, start, N-1);
            std.mem.doNotOptimizeAway(max_idx);
        }
    }
    const elapsed_ns1 = std.time.nanoTimestamp() - start_ns1;

    const start_ns2 = std.time.nanoTimestamp();
    for (0..repeat) |_| {
        for (array, 0..) |_, i| {
            const start = if (stepping) i else 0;
            const max_idx = maxIndex_reg(N, T, array, start, N-1);
            std.mem.doNotOptimizeAway(max_idx);
        }
    }
    const elapsed_ns2 = std.time.nanoTimestamp() - start_ns2;

    const ratio: f128 = @as(f128, @floatFromInt(elapsed_ns2)) / @as(f128, @floatFromInt(elapsed_ns1));
    return ratio;
}

test {
    std.debug.print("step, [64]u8,    simd / regular = {:.3}x\n", .{try benchmark(64, u8, 0, 10000, 0, true)});
    std.debug.print("step, [32]u16,   simd / regular = {:.3}x\n", .{try benchmark(32, u16, 0, 10000, 0, true)});
    std.debug.print("step, [16]u32,   simd / regular = {:.3}x\n", .{try benchmark(16, u32, 0, 10000, 0, true)});

    std.debug.print("full, [64]u8,    simd / regular = {:.3}x\n", .{try benchmark(64, u8, 0, 10000, 0, false)});
    std.debug.print("full, [32]u16,   simd / regular = {:.3}x\n", .{try benchmark(32, u16, 0, 10000, 0, false)});
    std.debug.print("full, [16]u32,   simd / regular = {:.3}x\n\n", .{try benchmark(16, u32, 0, 10000, 0, false)});

    std.debug.print("step, [256]u8,   simd / regular = {:.3}x\n", .{try benchmark(256, u8, 0, 10000, 0, true)});
    std.debug.print("step, [128]u16,  simd / regular = {:.3}x\n", .{try benchmark(128, u16, 0, 10000, 0, true)});
    std.debug.print("step, [64 ]u32,  simd / regular = {:.3}x\n", .{try benchmark(64, u32, 0, 10000, 0, true)});

    std.debug.print("full, [256]u8,   simd / regular = {:.3}x\n", .{try benchmark(256, u8, 0, 10000, 0, false)});
    std.debug.print("full, [128]u16,  simd / regular = {:.3}x\n", .{try benchmark(128, u16, 0, 10000, 0, false)});
    std.debug.print("full, [64 ]u32,  simd / regular = {:.3}x\n\n", .{try benchmark(64, u32, 0, 10000, 0, false)});

    std.debug.print("step, [512]u8,   simd / regular = {:.3}x\n", .{try benchmark(512, u8, 0, 10000, 0, true)});
    std.debug.print("step, [256]u16,  simd / regular = {:.3}x\n", .{try benchmark(256, u16, 0, 10000, 0, true)});
    std.debug.print("step, [128]u32,  simd / regular = {:.3}x\n", .{try benchmark(128, u32, 0, 10000, 0, true)});

    std.debug.print("full, [512]u8,   simd / regular = {:.3}x\n", .{try benchmark(512, u8, 0, 10000, 0, false)});
    std.debug.print("full, [256]u16,  simd / regular = {:.3}x\n", .{try benchmark(256, u16, 0, 10000, 0, false)});
    std.debug.print("full, [128]u32,  simd / regular = {:.3}x\n\n", .{try benchmark(128, u32, 0, 10000, 0, false)});

}

