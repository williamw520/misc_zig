
// Run by: zig run identifier.zig

const std = @import("std");
const print = std.debug.print;

const Vec32 = @Vector(32, u8);      // Assume SIMD-256 support with 32 byte vector.
const Arr32 = *const [32]u8;        // Cast ptr to [32] array before cast to Vec32.
const v32_0: Vec32 = @splat('0');   // Fill SIMD vecs with the limit chars.
const v32_9: Vec32 = @splat('9');
const v32_A: Vec32 = @splat('A');
const v32_Z: Vec32 = @splat('Z');
const v32_a: Vec32 = @splat('a');
const v32_z: Vec32 = @splat('z');
const v32_us: Vec32 = @splat('_');

fn nextBitmask32(base_ptr: [*]const u8, offset: usize) u32 {
    const a32_chars = @as(Arr32, @ptrCast(base_ptr + offset)).*;
    const v32_chars = @as(Vec32, a32_chars);
    const bit_ge_A: u32 = @bitCast(v32_chars >= v32_A);
    const bit_le_Z: u32 = @bitCast(v32_chars <= v32_Z);
    const bit_ge_a: u32 = @bitCast(v32_chars >= v32_a);
    const bit_le_z: u32 = @bitCast(v32_chars <= v32_z);
    const bit_us:   u32 = @bitCast(v32_chars == v32_us);
    const bit_A_Z:  u32 = bit_ge_A & bit_le_Z;
    const bit_a_z:  u32 = bit_ge_a & bit_le_z;
    const alphas:   u32 = bit_A_Z | bit_a_z | bit_us;

    // Digit should be in a separate function since leading char has different rules for digit.
    const bit_ge_0: u32 = @bitCast(v32_chars >= v32_0);
    const bit_le_9: u32 = @bitCast(v32_chars <= v32_9);
    const digits:   u32 = bit_ge_0 & bit_le_9;

    print("bit_ge_A {b:0>32}\n", .{ bit_ge_A });
    print("bit_le_Z {b:0>32}\n", .{ bit_le_Z });
    print("bit_ge_a {b:0>32}\n", .{ bit_ge_a });
    print("bit_le_z {b:0>32}\n", .{ bit_le_z });
    print("bit_A_Z  {b:0>32}\n", .{ bit_A_Z });
    print("bit_a_z  {b:0>32}\n", .{ bit_a_z });
    print("alphas   {b:0>32}\n", .{ alphas });
    print("bit_ge_0 {b:0>32}\n", .{ bit_ge_0 });
    print("bit_le_9 {b:0>32}\n", .{ bit_le_9 });
    print("digits   {b:0>32}\n", .{ digits });

    const bitmask:  u32 = alphas | digits;
    return bitmask;
}

pub fn main() !void {
    const text = "..ABcd..xy_z.._1209.. ```~~()...|....(_ef123)....~~.##$%........|.......";
    print("text: {s}\n\n", .{ text });

    const bytes = @as([] const u8, text);
    const size = bytes.len/32 * 32; // handling remainder text is left as an exercise
    var offset: usize = 0;
    while (offset < size) : (offset += 32) {
        var mask = nextBitmask32(bytes.ptr, offset);
        print("  mask:  {b:0>32}\n", .{ mask });

        // Dump the identifiers found.
        var pos = offset;
        while (mask != 0) {             // ensure mask having some 1-bits.
            const start = @ctz(mask);   // start position of next ident.
            mask = mask >> @as(u5, @intCast(start));
            const end = @ctz(~mask);    // end position of next ident.
            mask = mask >> @as(u5, @intCast(end));
            const ident = bytes[pos+start .. pos+start+end];
            pos = pos + start + end;
            print("  ident: {s}", .{ ident });
        }
        print("\n\n", .{});
    }

}

