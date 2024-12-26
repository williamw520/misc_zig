
// Run by: zig run identifier.zig

const std = @import("std");
const print = std.debug.print;

const Vec32 = @Vector(32, u8);      // Assume SIMD-256 support with 32 byte vector.
const Arr32 = *const [32]u8;        // Cast ptr to [32] array before cast to Vec32.

fn nextBitmask32(base_ptr: [*]const u8, offset: usize) u32 {
    const a32_chars = @as(Arr32, @ptrCast(base_ptr + offset)).*;
    const v32_chars = @as(Vec32, a32_chars);

    const bit_A_Z   = @as(u32, @bitCast(v32_chars >= @as(Vec32, @splat('A')))) &
                      @as(u32, @bitCast(v32_chars <= @as(Vec32, @splat('Z'))));
    const bit_a_z   = @as(u32, @bitCast(v32_chars >= @as(Vec32, @splat('a')))) &
                      @as(u32, @bitCast(v32_chars <= @as(Vec32, @splat('z'))));
    const bit_u:u32 =          @bitCast(v32_chars == @as(Vec32, @splat('_')));
    const bit_azu   = bit_A_Z | bit_a_z | bit_u;

    // Digit should be in a separate function since leading char has different rules for digit.
    const bit_0_9   = @as(u32, @bitCast(v32_chars >= @as(Vec32, @splat('0')))) &
                      @as(u32, @bitCast(v32_chars <= @as(Vec32, @splat('9'))));

    print("bit_A_Z  {b:0>32}\n", .{ bit_A_Z });
    print("bit_a_z  {b:0>32}\n", .{ bit_a_z });
    print("alphas   {b:0>32}\n", .{ bit_azu });
    print("digits   {b:0>32}\n", .{ bit_0_9 });

    return bit_azu | bit_0_9;
}

pub fn main() !void {
    const text = "..ABcd..xy_z.._1209.. ```~~()...|....(_Efg123)....~~.##$%........|.......";
    print("text: {s}\n\n", .{ text });

    const bytes = @as([] const u8, text);
    const size = bytes.len/32 * 32;     // handling remainder text is left as an exercise
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

