
const std = @import("std");

const Arithmetic = enum { plus, minus, star, slash };
const Literal = enum { string, number, keyword };

fn iterateEnum(comptime T: type) void {
    inline for (@typeInfo(T).@"enum".fields, 0..) |f, i| {
        std.debug.print("{}: {s}={any}\n", .{i, f.name, f.value});
    }
}

fn combineEnums(comptime U: type, comptime V: type) type {
    const u_fields = @typeInfo(U).@"enum".fields;
    const v_fields = @typeInfo(V).@"enum".fields;
    const new_len  = u_fields.len + v_fields.len;
    var new_fields: [new_len]std.builtin.Type.EnumField = undefined;
    var last_value: comptime_int = 0;
    const offset: comptime_int = u_fields.len;
    for (u_fields, 0..) |f, i| {
        new_fields[i] = f;
        last_value = f.value;
    }
    for (v_fields, 0..) |f, i| {
        new_fields[offset + i] = f;
        new_fields[offset + i].value = last_value + f.value;
    }

    return @Type(.{
        .@"enum" = .{
            .tag_type = u32,    // underlying integer type
            .fields = &new_fields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
}

test {
    std.debug.print("{any}\n", .{Arithmetic.plus});
    iterateEnum(Arithmetic);

    const Token = combineEnums(Arithmetic, Literal);
    const token1 = Token.plus;
    std.debug.print("Token: {any}\n", .{token1});

    iterateEnum(Token);
}

test "sample" {
    const Token = combineEnums(Arithmetic, Literal);    // new type
    const token1 = Token.plus;
    const token2 = Token.number;
    std.debug.print("token1: {any}\n", .{token1});
    std.debug.print("token2: {any}\n", .{token2});

    inline for (@typeInfo(Token).@"enum".fields, 0..) |f, i| {
        std.debug.print("{}: {s}={any}\n", .{i, f.name, f.value});
    }
}


