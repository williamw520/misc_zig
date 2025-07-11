
const std = @import("std");

/// Generate a Factory struct with a constructor 'of' function for the struct S.
/// The constructor takes in a tuple for input and returns an instance of S.
fn makeFactory(comptime S: type) type {
    const info = @typeInfo(S);
    if (info != .@"struct") @compileError("S must be a struct");

    return struct {
        // parameter tuple; fields must match the order of the struct's fields.
        pub fn of(comptime args: anytype) S {
            // allocate a new S instance on stack.
            var s: S = undefined;
            // fill in the fields of s.
            inline for (info.@"struct".fields, 0..) |field, idx| {
                @field(s, field.name) = args[idx];
            }
            return s;
        }

    };
}

/// Find the index to a field of the struct S.
inline fn fieldIndex(comptime S: type, comptime field_name: []const u8) usize {
    const s_info = @typeInfo(S).@"struct";
    inline for (s_info.fields, 0..) |field, idx| {
        if (std.mem.eql(u8, field.name, field_name))
            return idx;
    }
    @compileError("Field not found in the struct: " ++ field_name);
}

test {

    const User = struct {
        name: []const u8,
        age: u32,
        active: bool,
    };
    
    const UserFactory = makeFactory(User);

    const user = UserFactory.of(.{
        "Jack", // name
        42,     // age
        true,   // active
    });

    std.debug.print("User: {s}, age: {}, active: {}\n", .{
        user.name, user.age, user.active,
    });

}


