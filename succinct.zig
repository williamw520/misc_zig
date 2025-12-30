
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;



/// A succinct data structure to store a sparse array of 4096 u64-elements.
pub const Succinct4096 = struct {
    const NB = 64;                          // number of blocks

    bitmap: [NB]u64         = .{0} ** NB,   // each block has 64 bits, total 4096 bits.
    block_sum: [NB]u12      = .{0} ** NB,   // stores the sum of bits of the prefix blocks.
    dense: ArrayList(u64)   = .empty,       // the actual values, indexed by rank(i).

    pub fn deinit(self: *@This(), alloc: Allocator) void {
        self.dense.deinit(alloc);
    }

    pub fn clear(self: *@This()) void {
        @memset(&self.bitmap, 0);
        @memset(&self.block_sum, 0);
        self.dense.clearRetainingCapacity();
    }

    /// Get the value at the i-th position.
    /// Complexity: O(1).
    pub fn get(self: *const @This(), i: usize) ?u64 {
        if (i >= 4096) unreachable;

        const pos: u12      = @intCast(i);
        const block_id      = pos >> 6;     // shift off 64 bits to the block id.
        const bit_idx: u6   = @intCast(pos & 0b00111111);
        const bit_mask: u64 = @as(u64, 1) << bit_idx;

        if ((self.bitmap[block_id] & bit_mask) == 0)
            return null;                    // value not exist at the i-th position.

        return self.dense.items[self.rank(pos)];
    }

    /// Set the value at the i-th position.
    /// Complexity: O(1) on existing values. O(k) on new values, 1 < k < 4096.
    /// Use batchInit() to add values instead of adding one by one.
    pub fn set(self: *@This(), alloc: Allocator, i: usize, v: u64) !void {
        if (i >= 4096) unreachable;

        const pos: u12      = @intCast(i);
        const block_id      = pos >> 6;
        const bit_idx: u6   = @intCast(pos & 0b00111111);
        const bit_mask: u64 = @as(u64, 1) << bit_idx;
        const r             = self.rank(pos);

        if ((self.bitmap[block_id] & bit_mask) != 0) {
            self.dense.items[r] = v;        // updating existing value is O(1).
            return;
        }

        try self.dense.insert(alloc, r, v); // insertion has complexity O(len - r).
        self.bitmap[block_id] |= bit_mask;  // mark its position in bitmap.
        self.updatePrefixSums(block_id);    // only update prefix sums on new insert.
    }

    /// Initialize the data structure with an ordered positions and corresponding values.
    /// `ordered_positions` must be ordered, unique, and within [0-4095].
    /// Complexity: O(1) since O(4096) = O(1)
    pub fn batchInit(self: *@This(), alloc: Allocator,
                     ordered_positions: []const usize, values: []const u64) !void {
        // Validate monotonic increasing positions.
        var prev_pos: usize = 0;
        for (ordered_positions) |i| {
            std.debug.assert(i < 4096);
            std.debug.assert(i > prev_pos);
            prev_pos = i;
        }        
        self.clear();
        for (ordered_positions, values) |i, v| {
            const block_id      = i >> 6;
            const bit_idx: u6   = @intCast(i & 0b00111111);
            const bit_mask: u64 = @as(u64, 1) << bit_idx;
            self.bitmap[block_id] |= bit_mask;
            try self.dense.append(alloc, v);
        }
        self.recomputePrefixSums();
    }

    /// Compute the rank of the i-th position. Complexity: O(1).
    /// Rank is the number of set bits in [0, i).
    inline fn rank(self: *const @This(), i: u12) usize {
        const block_id      = i >> 6;
        const bit_idx: u6   = @intCast(i & 0b00111111);
        const block_mask    = (@as(u64, 1) << bit_idx) - 1;
        const block_bits    = self.bitmap[block_id] & block_mask;
        const block_nbits   = @popCount(block_bits);
        return self.block_sum[block_id] + block_nbits;
    }

    fn updatePrefixSums(self: *@This(), block_id: usize) void {
        for (block_id + 1 .. NB) |k| {
            self.block_sum[k] += 1; // each subsequent block gains one count.
        }
    }

    fn recomputePrefixSums(self: *@This()) void {
        var sum: u12 = 0;
        for (self.bitmap, 0..) |block_bits, block_id| {
            self.block_sum[block_id] = sum;
            sum += @popCount(block_bits);
        }
    }

};


test {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    var count: usize = 0;

    var s1 = Succinct4096{};
    defer s1.deinit(alloc);

    try std.testing.expect(s1.dense.items.len == 0);
    for (0..4096)|i| try std.testing.expect(s1.get(i) == null);

    try s1.set(alloc, 0, 0);
    try std.testing.expect(s1.dense.items.len == count + 1);   count += 1;
    try std.testing.expect(s1.get(0) == 0);
    for (1..4096)|i| try std.testing.expect(s1.get(i) == null);

    try s1.set(alloc, 0, 10000);    // test update
    try std.testing.expect(s1.dense.items.len == count);
    try std.testing.expect(s1.get(0) == 10000);
    for (1..4096)|i| try std.testing.expect(s1.get(i) == null);

    try s1.set(alloc, 0, 0);

    try s1.set(alloc, 1, 1);
    try std.testing.expect(s1.dense.items.len == count + 1);   count += 1;
    try std.testing.expect(s1.get(1) == 1);
    for (2..4096)|i| try std.testing.expect(s1.get(i) == null);

    try s1.set(alloc, 63, 63);      // test first block boundary
    try std.testing.expect(s1.dense.items.len == count + 1);   count += 1;
    try std.testing.expect(s1.get(63) == 63);

    try s1.set(alloc, 64, 64);      // test first block boundary
    try std.testing.expect(s1.dense.items.len == count + 1);   count += 1;
    try std.testing.expect(s1.get(64) == 64);

    try s1.set(alloc, 20, 20);      // out of order insert.
    try std.testing.expect(s1.dense.items.len == count + 1);   count += 1;
    try std.testing.expect(s1.get(20) == 20);

    try s1.set(alloc, 65, 65);
    try std.testing.expect(s1.dense.items.len == count + 1);   count += 1;
    try std.testing.expect(s1.get(65) == 65);

    try s1.set(alloc, 4094, 4094);  // test last block boundary
    try std.testing.expect(s1.dense.items.len == count + 1);   count += 1;
    try std.testing.expect(s1.get(4094) == 4094);

    try s1.set(alloc, 4095, 4095);  // test last item boundary
    try std.testing.expect(s1.dense.items.len == count + 1);   count += 1;
    try std.testing.expect(s1.get(4095) == 4095);

    for (0..4096) |i| {
        if (s1.get(i)) |value| {
            // std.debug.print("i:{} value:{}\n", .{i, value});
            try std.testing.expect(value == i);
        }
    }

    for (0..4096) |i| {
        try s1.set(alloc, i, i*2);
    }
    for (0..4096) |i| {
        if (s1.get(i)) |value| {
            try std.testing.expect(value == i*2);
        } else {
            try std.testing.expect(false);
        }
    }

    s1.clear();
    for (0..4096) |i| {
        try std.testing.expect(s1.get(i) == null);
    }

    for (0..4096) |k| {
        const i = 4095 - k;
        try s1.set(alloc, i, i*3);
    }
    for (0..4096) |i| {
        if (s1.get(i)) |value| {
            try std.testing.expect(value == i*3);
        } else {
            try std.testing.expect(false);
        }
    }

    const positions: []const usize = &[_]usize { 1, 3, 16, 17, 63, 64, 65, 127, 128, 129, 4094, 4095};
    const values: []const usize    = &[_]usize { 1, 3, 16, 17, 63, 64, 65, 127, 128, 129, 4094, 4095};

    try s1.batchInit(alloc, positions, values);
    for (0..4096) |i| {
        if (s1.get(i)) |value| {
            try std.testing.expect(value == i);
        }
    }
    for (positions, values) |i, v| {
        try std.testing.expect(s1.get(i) == v);
    }

}

