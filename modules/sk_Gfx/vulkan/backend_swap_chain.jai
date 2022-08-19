#scope_module

Backend_Swap_Chain :: struct {
}

backend_init_swap_chain :: (using swap_chain:*Swap_Chain) -> bool {    
    return true;
}

backend_resize_back_buffers :: (using swap_chain:*Swap_Chain, width:u32, height:u32) {

}

backend_deinit_swapchain :: (using swap_chain:*Swap_Chain) {

}