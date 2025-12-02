
// Get the error set in a function's return type.

const std = @import("std");
const Type = std.builtin.Type;

const Cancelable = error{Canceled};
const Errorable1 = error {Error1};
const Errorable2 = error {Error2};

const Errors = Cancelable || Errorable1 || Errorable2;

fn fnInfo(comptime func: anytype) Type.Fn {
    return switch (@typeInfo(@TypeOf(func))) {
        .@"fn"  => |info_fn| info_fn,
        else    => @compileError("func must be a function"),
    };
}

fn returnType(comptime T: ?type) void {
    const t = if (T)|t| t else return;
    const type_info: Type = @typeInfo(t);
    switch (type_info) {
        .error_union => |eu| {
            @compileLog("-payload-", eu.payload);
            @compileLog("error_set", eu.error_set);
            const errors = @typeInfo(eu.error_set).error_set.?;
            @compileLog("errors   ", errors);
        },
        else => {
            @compileLog("other    ", t);
        }
    }
}

fn fn1(b: bool) Errorable1!usize {
    return if (b) 1 else Errorable1.Error1;
}

fn fn2(b: bool) !usize {
    return if (b) fn1(b) else Errorable2.Error2;
}

fn fn_can(b: bool) !usize {
    return if (b) fn2(b) else Cancelable.Canceled;
}

pub fn main() !void {
    returnType(fnInfo(fn1).return_type);
    returnType(fnInfo(fn2).return_type);
    returnType(fnInfo(fn_can).return_type);

    const errors = @typeInfo(Errors).error_set.?;
    @compileLog("Errors   ", errors);
}


