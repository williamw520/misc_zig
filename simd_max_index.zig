
const std = @import("std");

pub fn maxIndex(comptime N: usize, comptime T: type, comptime MIN: T,
                array: [N]T, start: usize, end: usize) usize {
    const VecT              = @Vector(N, T);
    const v_lowest: VecT    = @splat(MIN);
    const IndexI            = std.simd.VectorIndex(VecT);   // index type
    const VecI              = @Vector(N, IndexI);
    const vi_iota: VecI     = std.simd.iota(IndexI, N);
    const vi_hi_idx: VecI   = @splat(~@as(IndexI, 0));      // highest index

    const v_array: VecT     = array;
    const vi_start: VecI    = @splat(@intCast(start));
    const vi_end: VecI      = @splat(@intCast(end));
    const vb_clamped_mask   = (vi_iota >= vi_start) & (vi_iota < vi_end);
    const v_clamped: VecT   = @select(T, vb_clamped_mask, v_array, v_lowest);
    const max_value: T      = @reduce(.Max, v_clamped);
    const v_max_value: VecT = @splat(max_value);
    const vb_max_mask       = v_clamped == v_max_value;
    const vi_indices: VecI  = @select(IndexI, vb_max_mask, vi_iota, vi_hi_idx);
    const max_idx: IndexI   = @reduce(.Min, vi_indices);

    // std.debug.print("v_array: {any}\n", .{v_array});
    // std.debug.print("v_clamped: {any}\n", .{v_clamped});
    // std.debug.print("max_value: {any}\n", .{max_value});
    // std.debug.print("vi_indices: {any}\n", .{vi_indices});
    // std.debug.print("max_idx: {any}\n", .{max_idx});
    return max_idx;
}

export fn test1() usize {
    const N = 16;
    const T = i32;
    const arr1: [N]T = .{ 9, 2, -17, -7123, 1, 2, 50, -24 } ** 1 ++ .{ -9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999 };
    return maxIndex(N, T, -9999, arr1, 3, 14);
}

export fn test2() usize {
    const N = 16;
    const T = i32;
    const arr1: [N]T = .{ 9, 2, -17, -7123, 1, 2, 50, -24 } ** 1 ++ .{ 99, 99, 99, 99, 99, 99, 99, 99 };
    return maxIndex(N, T, -9999, arr1, 3, 8);
}

export fn test3() usize {
    const N = 256;
    const T = i32;
    const arr1: [N]T = .{ 9.0, 2.0, 17.0, 11.0, 1.0, 2.0, 50.0, 24.0 } ** 31 ++ .{ 0, 0, 0, 0, 0, 0, 0, 0 };
    return maxIndex(N, T, 0, arr1, 3, 249);
}

export fn test4() usize {
    const N = 32;
    const T = f16;
    const arr1: [N]T = .{ 9, 2, 17, 11, 1, 2, 50, 24 } ** 3 ++ .{ 99, 101, 17, 11, 1, 2, 101, 99 };
    return maxIndex(N, T, 0, arr1, 3, 29);
}



test {
    const N = 64;
    const T = i8;
    const arr1: [N]T = .{ -9, -2, -17, -11, -1, -2, -50, -24 } ** 7 ++ .{ -127, -127, -127, -127, -127, -127, -127, -127 };

    std.debug.print("arr1: {any}\n", .{arr1});
    std.debug.print("1. max_idx: {} between {} and {}\n", .{maxIndex(N, T, -127, arr1, 3, 8), 3, 8});
    std.debug.print("2. max_idx: {} between {} and {}\n", .{maxIndex(N, T, -127, arr1, 5, 19), 5, 19});
}

test {
    const N = 32;
    const T = i32;
    const arr1: [N]T = .{ 9, 2, -17, -7123, 1, 2, 50, -24 } ** 3 ++ .{ -9999, -9999, -9999, -9999, -9999, -9999, -9999, -9999 };
    std.debug.print("arr1: {any}\n", .{arr1});
    std.debug.print("1. max_idx: {} between {} and {}\n", .{maxIndex(N, T, -9999, arr1, 3, 8), 3, 8});
    std.debug.print("2. max_idx: {} between {} and {}\n", .{maxIndex(N, T, -9999, arr1, 7, 31), 7, 31});
}

test {
    const N = 32;
    const T = u16;
    const arr1: [N]T = .{ 9, 2, 17, 11, 1, 2, 50, 24 } ** 3 ++ .{ 99, 101, 17, 11, 1, 2, 101, 99 };

    std.debug.print("arr1: {any}\n", .{arr1});
    std.debug.print("1. max_idx: {} between {} to {}\n", .{maxIndex(N, T, 0, arr1, 3, 29), 3, 29});
    std.debug.print("2. max_idx: {} between {} to {}\n", .{maxIndex(N, T, 0, arr1, 5, 24), 5, 24});
}

test {
    const N = 256;
    const T = u32;
    const arr1: [N]T = .{ 9, 2, 17, 11, 1, 2, 50, 24 } ** 31 ++ .{ 99, 101, 17, 11, 1, 2, 101, 99 };

    std.debug.print("arr1: {any}\n", .{arr1});
    std.debug.print("1. max_idx: {} between {} to {}\n", .{maxIndex(N, T, 0, arr1, 3, 29), 3, 29});
    std.debug.print("2. max_idx: {} between {} to {}\n", .{maxIndex(N, T, 0, arr1, 5, 250), 5, 250});
}

