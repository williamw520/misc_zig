
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;


/// A succinct data structure to store sparse values of a 4096 array(u64).
pub const Succinct4096 = struct {
    bitmap: [64]u64         = .{0} ** 64,   // each block has 64 bits, fitted in u64. 4096 bits.
    block_sum: [64]u16      = .{0} ** 64,   // stores the sum of bits of the prefix blocks.
    values: ArrayList(u64)  = .empty,       // the actual values, indexed by the rank(i).

    pub fn deinit(self: *@This(), alloc: Allocator) void {
        self.values.deinit(alloc);
    }

    pub fn clear(self: *@This()) void {
        self.bitmap = .{0} ** 64;
        self.block_sum = .{0} ** 64;
        self.values.clearRetainingCapacity();
    }

    /// Get the value at the i-th position.
    /// Complexity: O(1).
    pub fn get(self: *const @This(), i: usize) ?u64 {
        const idx: u12      = @intCast(i);
        const block_id      = idx >> 6;     // shift off 64 bits to the block id.
        const offset: u6    = @intCast(idx & 0b00111111);
        const bit_mask: u64 = @as(u64, 1) << offset;

        if ((self.bitmap[block_id] & bit_mask) == 0)
            return null;                    // value not exist at the i-th position.

        return self.values.items[self.rank(idx)];
    }

    /// Set the value at the i-th position.
    /// Complexity: O(1) on existing values. O(k) on new values, 1 < k < 4096.
    /// Use batchInit() to add values instead of adding one by one.
    pub fn set(self: *@This(), alloc: Allocator, idx: usize, v: u64) !void {
        const i: u12        = @intCast(idx);
        const block_id      = i >> 6;
        const offset: u6    = @intCast(i & 0b00111111);
        const bit_mask: u64 = @as(u64, 1) << offset;
        const r             = self.rank(i); // rank of existing or insertion point.

        if ((self.bitmap[block_id] & bit_mask) != 0) {
            self.values.items[r] = v;       // update existing value is O(1).
            return;
        }

        try self.values.insert(alloc, r,v); // insertion has complexity O(r).
        self.bitmap[block_id] |= bit_mask;  // mark its position in bitmap.
        self.udpatePrefixSums(block_id);
    }

    /// Initialize the data structure with an ordered positions and corresponding values.
    /// Complexity: O(1) since O(4096) = O(1)
    pub fn batchInit(self: *@This(), alloc: Allocator,
                     ordered_positions: []const usize, values: []const u64) !void {
        self.clear();
        for (ordered_positions, values) |i, v| {
            const block_id      = i >> 6;
            const offset: u6    = @intCast(i & 0b00111111);
            const bit_mask: u64 = @as(u64, 1) << offset;
            self.bitmap[block_id] |= bit_mask;
            try self.values.append(alloc, v);
        }
        self.recomputePrefixSums();
    }

    /// Compute the rank of the i-th position. Complexity: O(1).
    inline fn rank(self: *const @This(), i: u12) usize {
        const block_id      = i >> 6;
        const offset: u6    = @intCast(i & 0b00111111);
        const block_mask    = (@as(u64, 1) << offset) - 1;
        const block_bits    = self.bitmap[block_id] & block_mask;
        const block_nbits   = @popCount(block_bits);
        return self.block_sum[block_id] + block_nbits;
    }

    fn udpatePrefixSums(self: *@This(), block_id: usize) void {
        for (block_id + 1 .. 64) |k| {
            self.block_sum[k] += 1; // each subsequent block gains one bit.
        }
    }

    fn recomputePrefixSums(self: *@This()) void {
        var sum: u16 = 0;
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

    try std.testing.expect(s1.values.items.len == 0);
    for (0..64)|i| try std.testing.expect(s1.get(i) == null);

    try s1.set(alloc, 0, 0);
    try std.testing.expect(s1.values.items.len == count + 1);   count += 1;
    try std.testing.expect(s1.get(0) == 0);
    for (1..64)|i| try std.testing.expect(s1.get(i) == null);

    try s1.set(alloc, 0, 10000);    // test update
    try std.testing.expect(s1.values.items.len == count);
    try std.testing.expect(s1.get(0) == 10000);
    for (1..64)|i| try std.testing.expect(s1.get(i) == null);

    try s1.set(alloc, 0, 0);

    try s1.set(alloc, 1, 1);
    try std.testing.expect(s1.values.items.len == count + 1);   count += 1;
    try std.testing.expect(s1.get(1) == 1);
    for (2..64)|i| try std.testing.expect(s1.get(i) == null);

    try s1.set(alloc, 63, 63);      // test first block boundary
    try std.testing.expect(s1.values.items.len == count + 1);   count += 1;
    try std.testing.expect(s1.get(63) == 63);

    try s1.set(alloc, 64, 64);      // test first block boundary
    try std.testing.expect(s1.values.items.len == count + 1);   count += 1;
    try std.testing.expect(s1.get(64) == 64);

    try s1.set(alloc, 20, 20);      // out of order insert.
    try std.testing.expect(s1.values.items.len == count + 1);   count += 1;
    try std.testing.expect(s1.get(20) == 20);

    try s1.set(alloc, 65, 65);
    try std.testing.expect(s1.values.items.len == count + 1);   count += 1;
    try std.testing.expect(s1.get(65) == 65);

    try s1.set(alloc, 4094, 4094);  // test last block boundary
    try std.testing.expect(s1.values.items.len == count + 1);   count += 1;
    try std.testing.expect(s1.get(4094) == 4094);

    try s1.set(alloc, 4095, 4095);  // test last item boundary
    try std.testing.expect(s1.values.items.len == count + 1);   count += 1;
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

