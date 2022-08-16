Data_Storage :: struct (Item:Type, max_count_per_block:u16= 32, max_block_count:u16= 32) {
    count    : s64;
    count_high_water_mark: s64;
    allocator: Allocator;

    // Data Slot
    Slot :: struct {
        item   : Item;
        using locator: Locator;
    }

    // Data Block
    Block :: struct {
        count   : s64;
        index   : u16;
        slots   : [max_count_per_block] Slot = ---;
        occupied: [max_count_per_block] bool;
    }

    all_data_blocks   : [..] *Block;
    unfull_data_blocks: [..] *Block;
}

Locator :: struct {
    slot_index : u16; // 2 bytes
    block_index: u16; // 2 bytes
    #place slot_index; packed_locator: u32 = ---;
}

INVALID_LOCATOR_PACKED :u32: 0xffff_ffff;
INVALID_LOCATOR        :: Locator.{0xffff,0xffff};

// store given item in the storage
put :: (using storage:*Data_Storage, item:storage.Item) -> *storage.Item, locator:Locator {
    ptr, locator := get(storage, initialized=false);
    if !ptr return null, locator;
    << ptr = item;
    return ptr, locator;
}

// find and occupy empty item slot
get :: (using storage:*Data_Storage, $initialized:= true) -> *storage.Item, locator:Locator {
    // if first call set the allocator
    // given allocator -> context.allocator -> context.default_allocator
    if !all_data_blocks.count && !allocator.proc {
        remember_allocators(storage);
    }
    // if full add new block
    if !unfull_data_blocks.count {
        if all_data_blocks.count + 1 > max_block_count return null, INVALID_LOCATOR;
        block := New(Block, allocator=allocator);
        block.index = cast,trunc(u16) all_data_blocks.count;
        array_add(*all_data_blocks, block);
        array_add(*unfull_data_blocks, block);
    }
    // find empty slot
    block := unfull_data_blocks[0];
    slot_index := -1;
    if !block.occupied[block.count] then slot_index = block.count;
    if slot_index == -1 {
        for i: 0..max_count_per_block-1 {
            if !block.occupied[i] {
                slot_index = i;
                break;
            }
        }
    }
    // occupy the empty slot
    slot             := *block.slots[slot_index];
    slot.slot_index          = cast,trunc(u16) slot_index;
    slot.block_index = block.index;
    block.occupied[slot_index] = true;

    item         := cast(*Item) slot;
    block.count  += 1;
    count        += 1;
    if count > count_high_water_mark then count_high_water_mark = count;
    if block.count == max_count_per_block array_unordered_remove_by_value(*unfull_data_blocks, block);

    #if initialized {
        ini :: initializer_of(Item);
        #if ini ini(item);
        else memset(item, size_of(Item), 0);
    }

    return item, slot.locator;    
}

find :: (using storage:*Data_Storage, locator:Locator) -> *storage.Item {
    assert(locator.packed_locator != INVALID_LOCATOR_PACKED && locator.block_index < all_data_blocks.count && locator.slot_index < max_count_per_block);
    return *all_data_blocks[locator.block_index].slots[slot_index];
}

// discard/unoccupy item slot (the pointer will still valid pointing into what ever the slot has) 
discard :: (using storage:*Data_Storage, item:*storage.Item) {
    slot := cast(*Slot) item;
    inline discard(storage, slot.locator);
}

discard :: (using storage:*Data_Storage, locator:Locator) {
    assert(locator.packed_locator != INVALID_LOCATOR_PACKED && locator.block_index < all_data_blocks.count && locator.slot_index < max_count_per_block);
    block    := all_data_blocks[locator.block_index];
    was_full := block.count == max_count_per_block;
    block.occupied[locator.slot_index] = false;
    if was_full then array_add(*unfull_data_blocks, block);
}

// get data block index and slot index
// @REMOVE THIS
locate :: (using storage:Data_Storage, item:*storage.Item) -> block_index:u32, slot_index:u32 {
    slot := cast(*Slot) item;
    assert(slot.packed_locator != INVALID_LOCATOR_PACKED && slot.block_index < all_data_blocks.count && slot.slot_index < max_count_per_block);
    return slot.block_index, slot.slot_index;
}

// reset the storage (but keep memory)
reset :: (using storage:*Data_Storage) {
    if count == 0 return;
    unfull_data_blocks.count = 0;
    for block: all_data_blocks {
        block.count = 0;
        memset(block.occupied.data, 0, block.occupied.count * size_of(bool));
        array_add(*unfull_data_blocks, block);
    }
    count = 0;
}

// free storage data blocks (note: the allocater will not reset to deafult)
release :: inline (using storage:*Data_Storage) {
    for all_data_blocks free(it, allocator);
    array_reset(*all_data_blocks);
    array_reset(*unfull_data_blocks);
    count                 = 0;
    count_high_water_mark = 0; 
}

for_expansion :: (using storage:*$T/Data_Storage, body:Code, flags:For_Flags) #expand {
    #assert(!(flags & .REVERSE)); // We don't handle the reverse flag.
    #assert(!(flags & .POINTER)); // We always do pointer. (no need to use *)
    `it_index := -1;
    `it: *Item;
    for block, block_index: all_data_blocks {
        for *slot, slot_index: block.slots {
            if it_index+1 == storage.count break block; // if all items found no need to continue.
            if !block.occupied[slot_index] continue;
            it_index += 1;
            it       = *slot.item;
            #insert (break=break block, remove={#assert(false);}) body;
        }
    }
}

#scope_file
#import "Basic";