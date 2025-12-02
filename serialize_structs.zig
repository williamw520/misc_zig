const std = @import("std");
const Allocator = std.mem.Allocator;

const OpCode = enum { p1, p2 };

const PayloadType1 = struct {
    op: OpCode = .p1,
    f1: u16,
    f2: u32,

    pub const @"$FieldInfo" = .{
        .order = &[_][]const u8 { "f1", "f2" },
    };

    pub fn serialize(self: *const @This(), writer: *std.Io.Writer) !void {
        try writer.print("{} (f1={}, f2={})", .{self.op, self.f1, self.f2});
    }

    pub fn deserialize(self: *@This(), alloc: Allocator, reader: *std.Io.Reader) !void {
        _=self; _=alloc; _=reader;
    }
};

const PayloadType2 = struct {
    op: OpCode = .p2,
    f1: f32,
    f2: []const u8,

    pub fn serialize(self: *const @This(), writer: *std.Io.Writer) !void {
        try writer.print("{} (f1={}, f2={s})", .{self.op, self.f1, self.f2});
    }

    pub fn deserialize(self: *@This(), alloc: Allocator, reader: *std.Io.Reader) !void {
        _=self; _=alloc; _=reader;
    }
};


// Access to the common fields or functions of the payloads.
fn serialize(payload: anytype, writer: *std.Io.Writer) !void {
    try payload.serialize(writer);
}

fn deserialize(payload: anytype, alloc: Allocator, reader: *std.Io.Reader) !void {
    try payload.deserialize(alloc, reader);
}

fn getOpCode(payload: anytype) OpCode {
    return payload.op;
}

fn fieldInfo_order(comptime t_struct: type) ?[]const []const u8 {
    return if (@hasDecl(t_struct, "$FieldInfo"))
        return @field(t_struct.@"$FieldInfo", "order")
    else 
        null;
}


test {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    {
        const p1 = PayloadType1 { .f1 = 1, .f2 = 2 };
        std.debug.print("opcode: {}\n", .{getOpCode(p1)});
        var out_buf = std.Io.Writer.Allocating.init(alloc);
        defer out_buf.deinit();
        try serialize(p1, &out_buf.writer);
        std.debug.print("{s}\n", .{out_buf.written()});

        var in_buf = std.Io.Reader.fixed(out_buf.written());
        var p1a: PayloadType1 = undefined;
        try deserialize(&p1a, alloc, &in_buf);
    }

    {
        const p2 = PayloadType2 { .f1 = 1, .f2 = "abc" };
        std.debug.print("opcode: {}\n", .{getOpCode(p2)});
        var out_buf = std.Io.Writer.Allocating.init(alloc);
        defer out_buf.deinit();
        try serialize(p2, &out_buf.writer);
        std.debug.print("{s}\n", .{out_buf.written()});

        var in_buf = std.Io.Reader.fixed(out_buf.written());
        var p2a: PayloadType2 = undefined;
        try deserialize(&p2a, alloc, &in_buf);
    }

    {
        const order = fieldInfo_order(PayloadType1);
        if (order)|field_names| {
            for (field_names)|name| {
                std.debug.print("{s} ", .{name});
            }
        }
    }
}

