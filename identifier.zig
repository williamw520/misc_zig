
// Run by: zig run identifier.zig

const std = @import("std");
const print = std.debug.print;

const Vec32 = @Vector(32, u8);      // Assume SIMD-256 support with 32 byte vector.
const Arr32 = *const [32]u8;        // Cast ptr to [32] array before cast to Vec32.

fn nextBitmask32(raw_ptr: [*]const u8) u32 {
    const arr32     = @as(Arr32, @ptrCast(raw_ptr));
    const vec32     = @as(Vec32, arr32.*);

    const bit_A_Z   = @as(u32, @bitCast(vec32 >= @as(Vec32, @splat('A')))) &
                      @as(u32, @bitCast(vec32 <= @as(Vec32, @splat('Z'))));
    const bit_a_z   = @as(u32, @bitCast(vec32 >= @as(Vec32, @splat('a')))) &
                      @as(u32, @bitCast(vec32 <= @as(Vec32, @splat('z'))));
    const bit_u:u32 =          @bitCast(vec32 == @as(Vec32, @splat('_')));
    const bit_azu   = bit_A_Z | bit_a_z | bit_u;

    // Digit should be in a separate function since leading char has different rules for digit.
    const bit_0_9   = @as(u32, @bitCast(vec32 >= @as(Vec32, @splat('0')))) &
                      @as(u32, @bitCast(vec32 <= @as(Vec32, @splat('9'))));

    print("bit_A_Z  {b:0>32}\n", .{ bit_A_Z });
    print("bit_a_z  {b:0>32}\n", .{ bit_a_z });
    print("bit_u    {b:0>32}\n", .{ bit_u });
    print("alphas   {b:0>32}\n", .{ bit_azu });
    print("digits   {b:0>32}\n", .{ bit_0_9 });

    return bit_azu | bit_0_9;
}

// Removing the intermediate variables produces less asm instructions.
// Shouldn't the compiler (LLVM?) optimize away the intermediate variables?
// Anyway this is the improved version.
fn nextBitmask32b(raw_ptr: [*]const u8) u32 {
    const arr32 = @as(Arr32, @ptrCast(raw_ptr));
    const vec32 = @as(Vec32, arr32.*);
    return
        (@as(u32, @bitCast(vec32 >= @as(Vec32, @splat('A')))) &
         @as(u32, @bitCast(vec32 <= @as(Vec32, @splat('Z'))))) |
        (@as(u32, @bitCast(vec32 >= @as(Vec32, @splat('a')))) &
         @as(u32, @bitCast(vec32 <= @as(Vec32, @splat('z'))))) |
        (@as(u32, @bitCast(vec32 == @as(Vec32, @splat('_'))))) |
        (@as(u32, @bitCast(vec32 >= @as(Vec32, @splat('0')))) &
         @as(u32, @bitCast(vec32 <= @as(Vec32, @splat('9')))));
}

pub fn main() !void {
    const text = "..ABcd..xy_z.._1209.. ```~~()...|....(_Efg123)....~~.##$%........|.......";
    print("text: {s}\n\n", .{ text });

    const bytes = @as([] const u8, text);
    const size = bytes.len/32 * 32;     // handling remainder text is left as an exercise
    var offset: usize = 0;
    while (offset < size) : (offset += 32) {
        var mask = nextBitmask32(bytes.ptr + offset);
        //var mask = nextBitmask32b(bytes.ptr + offset);
        print("  mask:  {b:0>32}\n", .{ mask });

        // Dump the identifiers found.
        var pos = offset;
        while (mask != 0) {             // ensure the mask has some bits.
            const start = @ctz(mask);   // the start position of current ident.
            mask >>= @intCast(start);   // shift the mask down to the start pos.
            const end = @ctz(~mask);    // the end position of current ident.
            mask >>= @intCast(end);     // shift the mask down to the end pos.
            const ident = bytes[pos+start .. pos+start+end];
            print("  ident: {s}", .{ ident });
            pos = pos + start + end;
        }
        print("\n\n", .{});
    }

}

