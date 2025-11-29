const AtomicOrder = @import("std").builtin.AtomicOrder;

// A direct memory mapped into the virtual address of every proces.
const MEM_ADDR: u64 = 0x00000000_00001234;
const void_ptr: *u8 = @ptrFromInt(MEM_ADDR);
const mem_ptr: *u32 = @ptrCast(@alignCast(void_ptr));


export fn get() u32 {
    return @atomicLoad(u32, mem_ptr, AtomicOrder.seq_cst);
}

export fn set() void {
    @atomicStore(u32, mem_ptr, 1, AtomicOrder.seq_cst);
}

export fn clear() void {
    @atomicStore(u32, mem_ptr, 0, AtomicOrder.seq_cst);
}

