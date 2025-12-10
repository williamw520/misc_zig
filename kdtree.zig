
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;


/// L - location item type
/// K - dimensions
/// C - point coordinate type
pub fn KdTree(comptime L: type, comptime K: usize, comptime C: type) type {

    const Neighbor = struct {
        item:       *L,             // the nearest item to target.
        distance:   C,              // direct distance from the target item to item.
    };

    return struct {
        const Tree = @This();
        const KNNQueue = std.PriorityQueue(Neighbor, void, farthestCompare);
        const Node = struct {
            item:   *L,
            depth:  usize,
            left:   ?*Node = null,  // left child node
            right:  ?*Node = null,  // right child node
        };

        arena_ptr:  *ArenaAllocator,
        alloc:      Allocator,
        items:      []L,
        root:       ?*Node = null,

        pub fn init(backing_alloc: Allocator, items: []L) !Tree {
            const arena_ptr = try backing_alloc.create(ArenaAllocator);
            arena_ptr.* = ArenaAllocator.init(backing_alloc);
            const alloc = arena_ptr.allocator();
            var ptrs: []*L = try alloc.alloc(*L, items.len);
            for (items, 0..) |*loc, i| ptrs[i] = loc;
            defer alloc.free(ptrs); // free working array when done; the tree is in arena.
            return .{
                .arena_ptr = arena_ptr,
                .alloc = alloc,
                .items = items,
                .root = try build(alloc, ptrs, 0),
            };
        }

        pub fn deinit(self: *Tree) void {
            const backing_alloc = self.arena_ptr.child_allocator;
            self.arena_ptr.deinit();
            backing_alloc.destroy(self.arena_ptr);
        }

        fn build(alloc: Allocator, ptrs: []*L, depth: usize) !?*Node {
            if (ptrs.len == 0) return null;

            const axis: usize = depth % K;
            std.sort.insertion(*L, ptrs, axis, struct {
                    fn lessThan(ctx_axis: usize, a: *const L, b: *const L) bool {
                        return a.valueOn(ctx_axis) < b.valueOn(ctx_axis);
                    }
                }.lessThan,
            );

            const mid = (ptrs.len - 1) / 2;
            var mid_node = try alloc.create(Node);
            mid_node.* = .{ .item = ptrs[mid], .depth = depth };
            mid_node.left  = try build(alloc, ptrs[0..mid],    depth + 1);
            mid_node.right = try build(alloc, ptrs[mid + 1..], depth + 1);
            return mid_node;
        }

        fn difference_sq(a: C, b: C) C {
            const a_2 = a * a;  // Ensure no underflow; (a-b)^2 = a^2 − 2ab + b^2
            const b_2 = b * b;
            const ab2 = 2 * a * b;
            return a_2 + b_2 - ab2;
        }

        fn distance_sq(a: *const L, b: *const L) C {
            var sum_of_diff_sq: C = 0;
            inline for (0..K) |axis| {
                sum_of_diff_sq += difference_sq(a.valueOn(axis), b.valueOn(axis));
            }
            return sum_of_diff_sq;
        }
        
        pub fn nearestNeighbor(self: *const Tree, target: *const L) ?Neighbor {
            if (self.root) |root| {
                var result = Neighbor {
                    .item = root.item,
                    .distance = distance_sq(root.item, target),
                };
                nnSearch(root, target, &result);
                return result;
            }
            return null;
        }

        fn nnSearch(current: ?*Node, target: *const L, result: *Neighbor) void {
            const node = current orelse return;
            const direct_distance = distance_sq(node.item, target);
            if (direct_distance < result.distance) {
                result.item = node.item;                    // Update the closer item.
                result.distance = direct_distance;
            }

            // Determine which side to search next.
            const axis: usize   = node.depth % K;
            const plane_value   = node.item.valueOn(axis);  // pivot plane's value along the axis
            const target_value  = target.valueOn(axis);     // target's value along the axis
            const target_axial  = difference_sq(target_value, plane_value);
            const left_of_plane = target_value < plane_value;
            const next_child    = if (left_of_plane) node.left else node.right;
            const other_side    = if (left_of_plane) node.right else node.left;

            nnSearch(next_child, target, result);           // go down the sub-tree.

            // Distance between target and the item is the radius of a sphere centering target.
            // See if the sphere encompass the axial distance between target and the pivot plane.
            const radius = result.distance;
            if (radius > target_axial) {
                // The hyperplane is closer to the target point than to the current best point.
                // Check for a possible closer neighbor on the other side of the plane.
                nnSearch(other_side, target, result);
            }
        }

        fn farthestCompare(_: void, a: Neighbor, b: Neighbor) std.math.Order {
            // Less means higher priority in PQueue. Highest priority is the farthest away.
            if (a.distance > b.distance) return .lt;
            if (a.distance < b.distance) return .gt;
            return .eq;
        }

        pub fn kNearestNeighbors(self: *const Tree, target: *const L, k: usize) !ArrayList(Neighbor) {
            var pqueue = KNNQueue.init(self.alloc, {});
            if (self.root) |root| {
                try knnSearch(root, target, k, 0, &pqueue);
            }
            var results: ArrayList(Neighbor) = .empty;
            while (pqueue.removeOrNull()) |neighbor| {
                try results.append(self.alloc, neighbor);
            }
            std.mem.reverse(Neighbor, results.items);
            return results;
        }

        fn knnSearch(current: ?*Node, target: *const L, k: usize, depth: usize, pq: *KNNQueue) !void {
            const node = current orelse return;
            const direct_distance = distance_sq(node.item, target);
            if (pq.count() < k) {
                try pq.add(Neighbor{ .item = node.item, .distance = direct_distance });
            } else {
                // PQueue is full. Replace the farthest neighbor.
                const farthest_neighbor = pq.peek().?;
                if (direct_distance < farthest_neighbor.distance) {
                    _ = pq.remove();
                    try pq.add(Neighbor{ .item = node.item, .distance = direct_distance });
                }
            }
            
            // Determine which side to search next.
            const axis: usize   = node.depth % K;
            const plane_value   = node.item.valueOn(axis);  // node's value along the axis
            const target_value  = target.valueOn(axis);     // target's value along the axis
            const target_axial  = difference_sq(target_value, plane_value);
            const left_of_plane = target_value < plane_value;
            const next_child    = if (left_of_plane) node.left else node.right;
            const other_side    = if (left_of_plane) node.right else node.left;

            try knnSearch(next_child, target, k, depth+1, pq);

            var do_other_side   = true;
            if (pq.count() == k) {
                // Distance between target and the farthest item is the radius of a sphere centering target.
                // See if the sphere encompass the axial distance between target and the pivot plane.
                const farthest_neighbor = pq.peek().?;      // the first/highest priority item.
                const radius = farthest_neighbor.distance;
                if (radius <= target_axial) {
                    do_other_side = false;
                }
            }
            if (do_other_side) {
                try knnSearch(other_side, target, k, depth+1, pq);
            }
        }
    };
}


test {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const Item = struct {
        pt: [3]u32,

        pub fn valueOn(self: *const @This(), axis: usize) u32 {
            return self.pt[axis];
        }
    };

    var items = [_]Item {
        .{ .pt = .{1, 2, 3} },
        .{ .pt = .{5, 4, 5} },
        .{ .pt = .{4, 7, 8} },
    };
    const Tree3 = KdTree(Item, 3, u32);
    var t1 = try Tree3.init(alloc, &items);
    defer t1.deinit();

    std.debug.print("---- nn\n", .{});
    std.debug.print("{any}\n", .{ t1.nearestNeighbor(&Item{ .pt = .{0, 0, 0} }) });
    std.debug.print("{any}\n", .{ t1.nearestNeighbor(&Item{ .pt = .{1, 2, 3} }) });
    std.debug.print("{any}\n", .{ t1.nearestNeighbor(&Item{ .pt = .{1, 2, 0} }) });
    std.debug.print("{any}\n", .{ t1.nearestNeighbor(&Item{ .pt = .{5, 5, 5} }) });
    std.debug.print("{any}\n", .{ t1.nearestNeighbor(&Item{ .pt = .{5, 5, 0} }) });
    std.debug.print("{any}\n", .{ t1.nearestNeighbor(&Item{ .pt = .{9, 9, 9} }) });

    std.debug.print("---- knn\n", .{});
    std.debug.print("{any}\n", .{ (try t1.kNearestNeighbors(&Item{ .pt = .{0, 0, 0} }, 2)).items });

}

