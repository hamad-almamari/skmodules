// ------------------------------------------
// swap chain
Swap_Chain_Desc :: struct {
    native_window: Native_Window;
    width, height: u32;
    format       : Texture_Format;
    sample_count : u16 = 1;
	clear_color  : [4] float = .[0, 0, 0, 1];
}

Swap_Chain :: struct {
    #as using base: Base;
    base.kind = .SWAPCHAIN;
    desc             : Swap_Chain_Desc;
    locator          := DataStorage.INVALID_LOCATOR;
    swap_required    : bool;
    active_buffer_index: u16;
    back_buffers     : [SWC_BUFFER_COUNT] *Texture; // NOTE THAT: these Textures do not stored in the resourse storage
    back_buffers_data: [SWC_BUFFER_COUNT] Texture;
    
    using bk: Backend_Swap_Chain;
}

create_swap_chain :: (desc:Swap_Chain_Desc) -> *Swap_Chain {
    #if DEBUG {
        if !desc.native_window || !desc.width || !desc.height {
            report_debug_msg(.ERROR, "swap chain native_window is null or width/height = 0.");
            return null;
        }
        valid_sample_count := desc.sample_count == 1 || desc.sample_count == 2 || desc.sample_count == 4 || desc.sample_count == 8;
        if !valid_sample_count {
            report_debug_msg(.ERROR, "swap chain sample count must be 1, 2, 4 or 8.");
            return null;
        }
        if desc.format == .UNKNOWN {
            report_debug_msg(.ERROR, "swap chain format must be specified.");
            return null;
        }
    }

    sc, slocator := DataStorage.get(*gs.swc_storage, initialized=true);
    if sc == null {
        report_debug_msg(.ERROR, "failed, swap chain storage is full: %.", gs.swc_storage.count);
        return null;
    }

    sc.desc    = desc;
    sc.locator = slocator;
    
    if !backend_init_swap_chain(sc) {
        report_debug_msg(.ERROR, "initialization of swap chain failed.");
        release_swap_chain_imm(sc);
        return null;
    }

    return sc;
}

resize_back_buffers :: backend_resize_back_buffers; 

release_swap_chain_imm :: (using swap_chain:*Swap_Chain) {
    // release the swapchain immediately
    backend_deinit_swapchain(swap_chain);
    << swap_chain = .{};
    DataStorage.discard(*gs.swc_storage, swap_chain);
}

// Extra

release_swap_chain_wafc :: inline (swap_chain:*Swap_Chain) {
    // release the swapchain after active/current frame is completed
    Basic.array_add(*gs.release_lists[gs.active_frame], swap_chain);
}

get_active_back_buffer :: inline (using swap_chain:*Swap_Chain) -> *Texture {
    return back_buffers[active_buffer_index];
}