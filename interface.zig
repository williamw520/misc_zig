
const std = @import("std");
const Allocator = std.mem.Allocator;


fn TPtr(T: type, opaque_ptr: *anyopaque) T {
    return @as(T, @ptrCast(@alignCast(opaque_ptr)));
}

fn CTPtr(T: type, opaque_ptr: *const anyopaque) T {
    return @as(T, @constCast(@ptrCast(@alignCast(opaque_ptr))));
}

const ICount = struct {
    inc: *const fn(self: *@This(), amount: i64) void,
    get: *const fn(self: *@This()) i64,
};


// Interface
const Countable = struct {
    impl:       *anyopaque,
    i_inc:      *const fn(impl: *anyopaque, amount: i64) void,
    i_get:      *const fn(impl: *const anyopaque) i64,

    // The interface methods. Implementation must have these methods.
    pub fn inc(self: *@This(), amount: i64) void {
        self.i_inc(self.impl, amount);
    }

    pub fn get(self: @This()) i64 {
        return self.i_get(self.impl);
    }

    // Make an interface object based on the implementation.
    pub fn implBy(impl_obj: anytype) @This() {
        const IT = @TypeOf(impl_obj);

        const Delegate = struct {
            fn inc(impl: *anyopaque, amount: i64) void {
                TPtr(IT, impl).inc(amount);
            }

            fn get(impl: *const anyopaque) i64 {
                return CTPtr(IT, impl).get();
            }
        };

        return .{
            .impl = impl_obj,
            .i_inc = Delegate.inc,
            .i_get = Delegate.get,
        };
    }

    // Default interface methods
    pub fn doubleInc(self: *@This(), amount: i64) void {
        self.inc(amount);
        self.inc(amount);
    }

    pub fn square(self: @This()) i64 {
        return self.get() * self.get();
    }

};

// Interface
const CCountable = struct {
    impl:       *const anyopaque,
    i_get:      *const fn(impl: *const anyopaque) i64,

    // The interface methods. Implementation must have these methods.
    pub fn get(self: @This()) i64 {
        return self.i_get(self.impl);
    }

    // Make an interface object based on the implementation.
    pub fn implBy(impl_obj: anytype) @This() {
        const IT = @TypeOf(impl_obj);

        const Delegate = struct {
            fn get(impl: *const anyopaque) i64 {
                return CTPtr(IT, impl).get();
            }
        };

        return .{
            .impl = impl_obj,
            .i_get = Delegate.get,
        };
    }

    pub fn square(self: @This()) i64 {
        return self.get() * self.get();
    }

};

pub const Count = struct {
    sum:    i64 = 0,

    pub fn inc(self: *@This(), amount: i64) void {
        self.sum += amount;
    }

    pub fn get(self: @This()) i64 {
        return self.sum;
    }
};

test "Implementation of an interface" {
    {
        var c1 = Count{};
        var ct1 = Countable.implBy(&c1);
        _ = ct1.inc(1);
        _ = ct1.inc(1);
        _ = ct1.doubleInc(1);
        std.debug.print("sum: {}, sum: {}, sq: {}\n", .{c1.get(), ct1.get(), ct1.square()});
    }
}

test "Const implementation of an interface" {
    {
        const c1 = Count { .sum = 5 };
        var ct1 = CCountable.implBy(&c1);
        std.debug.print("sq: {}\n", .{ct1.square()});
    }
}


