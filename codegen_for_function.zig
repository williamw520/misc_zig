
const User = struct {
    name:   []const u8,
    age:    u32,

    comptime {
        generateGetters(@This());
    }
};

fn generateGetters(comptime S: type) void {
    const info = @typeInfo(S).Struct;

    inline for (info.fields) |field| {
        // THIS DOESN'T WORK.
        // Generate getter
        const getter_name = "get_" ++ field.name;
        fn @field(S, getter_name)(self: *const S) field.type {
            return @field(self, field_name);
        }
    }
}

