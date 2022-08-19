#scope_module

Backend_Native_Window      :: *void;
Backend_State              :: struct {}
Backend_Adapter_Info       :: struct {}
Backend_Debug_Message_Type :: struct {}

dummy_adapters_info: [1] Adapter_Info;

backend_get_available_adapters_info :: () -> [] Adapter_Info {
    dummy_adapters_info[0].adapter_index = 0;
    return dummy_adapters_info;
}

backend_init :: () -> bool {
    dummy_adapters_info[0].adapter_index = 0;
    return true;
}

backend_deinit :: () {

}

backend_execute :: () {
    pullGs();
    for encoder: gs.enc_storage {
        using encoder;
        if current_state == .INVALID break;   // this the last used one
        Basic.assert(current_state == .EXECUTABLE); // make sure it closed
        current_state = .INVALID;
    }
    // swap buffers
    for gs.swc_storage {
        if !it.swap_required continue;
        using it;
        active_buffer_index  = (active_buffer_index+1) % SWC_BUFFER_COUNT;;
        swap_required        = false;
    }
    // new frame ----------------------------------------------------
    gs.frame_counter += 1;
    // move to next frame
    gs.active_frame = (gs.active_frame+1) % FRAME_COUNT;
    // wait for the active frame on the host (the new acquired frame).
    if gs.frame_counter >= FRAME_COUNT {
        // wait ...
    }
}

backend_wait_idle :: () {

}

backend_report_backend_debug_msgs :: (loc: Source_Code_Location = #caller_location) #expand {

}

#load "backend_swap_chain.jai";
#load "backend_pipeline.jai";
#load "backend_encoder.jai";
#load "backend_resources.jai";