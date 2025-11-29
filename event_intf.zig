const std = @import("std");
const Allocator = std.mem.Allocator;


pub const Event = struct {
    event_impl: *anyopaque,     // (1) the implementation event obj ptr.
    vtable:     *const VTable,  // (2) vtable pointer

    const VTable = struct {     // (3) interface function pointers
        type_name:  []const u8,
        deinit:     *const fn(event_impl: *anyopaque, alloc: Allocator) void,
        do_stuff:   *const fn(event_impl: *anyopaque) void,
    };

    // (4) Public interface API
    pub fn type_name(self: *const Event) []const u8 {
        std.atomic.Value
        return self.vtable.type_name;
    }

    pub fn deinit(self: *Event, alloc: Allocator) void {
        self.vtable.deinit(self.event_impl, alloc);
    }

    pub fn do_stuff(self: *Event) void {
        self.vtable.do_stuff(self.event_impl);
    }

    // (5) Turn an event implementation object into the Event interface.
    pub fn implBy(event: anytype) Event {
        const ET = @TypeOf(event);

        // (6) Bridging the interface methods back to the implementation.
        const delegate = struct {
            fn deinit(event_impl: *anyopaque, alloc: Allocator) void {
                tptr(ET, event_impl).deinit(alloc);
            }
            fn do_stuff(event_impl: *anyopaque) void {
                tptr(ET, event_impl).do_stuff();
            }
        };

        return .{
            .event_impl = event,
            .vtable = &VTable { // (7) const VTable value as a comptime value.
                .type_name = typeName(ET),
                .deinit = delegate.deinit,
                .do_stuff = delegate.do_stuff,
            }
        };
    }

    // (8) Get the actual implementation event.
    // T should be a pointer type since 'event_impl' is a pointer.
    pub fn as(self: *Event, T: type) T {
        return tptr(T, self.event_impl);
    }

    pub inline fn typeName(T: type) []const u8 {
        const info = @typeInfo(T);
        return if (info == .pointer) @typeName(info.pointer.child) else @typeName(T);
    }
    
    inline fn tptr(T: type, opaque_ptr: *anyopaque) T {
        return @as(T, @ptrCast(@alignCast(opaque_ptr)));
    }
};

pub const Registry = struct {
    const EList = std.ArrayList(Event);
    map: std.StringHashMap(EList),

    fn add(self: *Registry, alloc: Allocator, event: anytype) !void {
        const ei = Event.implBy(event); // turn it into an event interface obj.
        const list = self.map.getPtr(ei.type_name());
        if (list)|l| {
            try l.append(alloc, ei);
        } else {
            var l: EList = .empty;
            try l.append(alloc, ei);
            try self.map.put(ei.type_name(), l);
        }
    }

    fn events(self: *Registry, ET: type) ?*EList {
        return self.map.getPtr(Event.typeName(ET));
    }

};

// custom events
pub const EventFoo = struct {
    x: usize,
    y: usize,

    pub fn deinit(self: *EventFoo, alloc: Allocator) void {
        _=self; _=alloc;    // do whatever event specific cleanup.
        std.debug.print("deinit EventFoo\n", .{});
    }

    pub fn do_stuff(self: *EventFoo) void {
        std.debug.print("do_stuff EventFoo x:{}, y:{}\n", .{self.x, self.y});
    }
};

pub const EventBar = struct {
    abc: usize,

    pub fn deinit(self: *EventBar, alloc: Allocator) void {
        _=self; _=alloc;    // do whatever event specific cleanup.
        std.debug.print("deinit EventBar\n", .{});
    }

    pub fn do_stuff(self: *EventBar) void {
        std.debug.print("do_stuff EventBar abc:{}\n", .{self.abc});
    }
};


test {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    
    std.debug.print("\n=== Event implementation test ===\n", .{});

    var foo1 = EventFoo { .x = 1, .y = 10 };
    const e_foo1 = Event.implBy(&foo1);

    var bar1 = EventBar { .abc = 100 };
    var bar2 = EventBar { .abc = 200 };

    var events = [_] Event {e_foo1, Event.implBy(&bar1), Event.implBy(&bar2)};
    for (events[0..], 0..) |*e, i| {
        std.debug.print("{} - type: {s}\n", .{i, e.type_name()});
        e.do_stuff();
    }

    std.debug.print("\n=== Event registry test ===\n", .{});

    var registry = Registry {
        .map = std.StringHashMap(Registry.EList).init(alloc),
    };
    try registry.add(alloc, &foo1);
    try registry.add(alloc, &bar1);
    try registry.add(alloc, &bar2);

    if (registry.events(EventFoo))|list| {
        for (list.items, 0..)|*e, i| {
            std.debug.print("{} - type: {s}\n", .{i, e.type_name()});
            e.do_stuff();
            const actual = e.as(*EventFoo);
            std.debug.print("{} - actual EventFoo.x: {}\n", .{i, actual.x});
        }
    }

    std.debug.print("\n", .{});
    if (registry.events(EventBar))|list| {
        for (list.items, 0..)|*e, i| {
            std.debug.print("{} - type: {s}\n", .{i, e.type_name()});
            e.do_stuff();
            std.debug.print("{} - actual EventBar.abc: {}\n", .{i, e.as(*EventBar).abc});
        }
    }

    std.debug.print("\n=== Nested iterations for cleanup ===\n", .{});

    var it = registry.map.iterator();
    while (it.next()) |kv| {
        for (kv.value_ptr.items, 0..)|*e, i| {
            std.debug.print("{} - calling {s}.deinit()\n", .{i, e.type_name()});
            e.deinit(alloc);
        }
        kv.value_ptr.deinit(alloc);
    }
    registry.map.deinit();
}



// Interface for simple event, no interface methods.
pub const SEvent = struct {
    event_impl: *anyopaque,
    t_name: []const u8,

    pub fn type_name(self: *const SEvent) []const u8 {
        return self.t_name;
    }

    pub fn implBy(event: anytype) SEvent {
        return .{
            .event_impl = event,
            .t_name = typeName(@TypeOf(event)),
        };
    }

    pub fn as(self: *SEvent, T: type) T {
        return @as(T, @ptrCast(@alignCast(self.event_impl)));
    }

    pub inline fn typeName(T: type) []const u8 {
        const info = @typeInfo(T);
        return if (info == .pointer) @typeName(info.pointer.child) else @typeName(T);
    }
};

pub const SRegistry = struct {
    const EList = std.ArrayList(SEvent);

    map: std.StringHashMap(EList),

    fn init(alloc: Allocator) SRegistry {
        return .{
            .map = std.StringHashMap(EList).init(alloc),
        };
    }

    fn deinit(self: *SRegistry, alloc: Allocator) void {
        var it = self.map.iterator();
        while (it.next()) |kv| {
            kv.value_ptr.deinit(alloc);
        }
        self.map.deinit();
    }

    fn add(self: *SRegistry, alloc: Allocator, event: anytype) !void {
        const ei = SEvent.implBy(event); // turn it into an event interface obj.
        const list = self.map.getPtr(ei.type_name());
        if (list)|l| {
            try l.append(alloc, ei);
        } else {
            var l: EList = .empty;
            try l.append(alloc, ei);
            try self.map.put(ei.type_name(), l);
        }
    }

    fn events(self: *SRegistry, ET: type) ?*EList {
        return self.map.getPtr(SEvent.typeName(ET));
    }
};


// Custom event types.
pub const EA = struct {};
pub const EB = struct { id: usize };
pub const EC = enum { red, green, blue };
pub const ED = usize;


test "SEvent and SRegistry" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    std.debug.print("\n=== SEvent implementation test ===\n", .{});

    var ea1 = EA{};
    var ea2 = EA{};
    var eb1 = EB{ .id = 1 };
    var eb2 = EB{ .id = 2 };
    var ec1 = EC.red;
    var ec2 = EC.green;
    var ec3 = EC.green;
    var ec4 = EC.blue;
    var ed1: ED = 10;
    var ed2: ED = 20;
    var ed3: ED = 30;

    var events = [_] SEvent {
        SEvent.implBy(&ea1), SEvent.implBy(&ea2),
        SEvent.implBy(&eb1), SEvent.implBy(&eb2),
        SEvent.implBy(&ec1), SEvent.implBy(&ec2),
        SEvent.implBy(&ed1), SEvent.implBy(&ed2),
    };
    for (events[0..], 0..) |*e, i| {
        std.debug.print("{} - type: {s}\n", .{i, e.type_name()});
    }

    std.debug.print("\n=== SimpleRegistry registry test ===\n", .{});

    var registry = SRegistry.init(alloc);
    defer registry.deinit(alloc);
    try registry.add(alloc, &ea1);
    try registry.add(alloc, &ea2);
    try registry.add(alloc, &eb1);
    try registry.add(alloc, &eb2);
    try registry.add(alloc, &ec1);
    try registry.add(alloc, &ec2);
    try registry.add(alloc, &ec3);
    try registry.add(alloc, &ec4);
    try registry.add(alloc, &ed1);
    try registry.add(alloc, &ed2);
    try registry.add(alloc, &ed3);

    if (registry.events(EA))|list| {
        for (list.items, 0..)|*e, i| {
            const actual = e.as(*EA);
            std.debug.print("{} - type: {s}, actual: {}\n", .{i, e.type_name(), actual});
        }
    }

    if (registry.events(EB))|list| {
        for (list.items, 0..)|*e, i| {
            const actual = e.as(*EB);
            std.debug.print("{} - type: {s}, actual: {}\n", .{i, e.type_name(), actual});
        }
    }
    
    if (registry.events(EC))|list| {
        for (list.items, 0..)|*e, i| {
            const actual = e.as(*EC);
            std.debug.print("{} - type: {s}, actual: {}\n", .{i, e.type_name(), actual});
        }
    }

    if (registry.events(ED))|list| {
        for (list.items, 0..)|*e, i| {
            const actual = e.as(*ED);
            std.debug.print("{} - type: {s}, actual: {}\n", .{i, e.type_name(), actual.*});
        }
    }

}

