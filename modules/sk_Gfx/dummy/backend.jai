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
    // MOVE this outside the backend
    // end resource staging encoder
    end_commands(gs.staging_encoder);
    for encoder: gs.enc_storage {
        using encoder;
        // break if the encoder not used this frame or not inited
        if current_state == .INITIAL || current_state == .INVALID break;   // this the last used one
        Basic.assert(current_state == .EXECUTABLE); // make sure it closed
        current_state = .INITIAL;
    }

    gs.frame_counter += 1;

    // new frame ----------------------------------------------------
    DataStorage.reset(*gs.enc_storage);
    // begin new staging encoder
    gs.staging_encoder = begin_commands(null, .FIRST);

    // move to next frame
    gs.active_frame = (gs.active_frame+1) % FRAME_COUNT;

    // wait for the active frame on the host.
    if gs.frame_counter >= FRAME_COUNT {
        // wait ...
    }

    // release objects
    for gs.release_lists[gs.active_frame] { // TODO add #complete
        if it.kind == {
            case .UNKNOWN;    continue;
            case .SWAPCHAIN;  release_swap_chain_imm(cast(*Swap_Chain) it);
            case .BIND_GROUP; release_bind_group_imm(cast(*Bind_Group) it);
            case .RESOURCE; {
                resource := cast(*Resource) it;
                if #complete resource.resource_type == {
                    case .BUFFER;     release_buffer_imm(cast(*Buffer) it);
                    case .TEXTURE;    release_texture_imm(cast(*Texture) it);
                    case .UNKNOWN; continue;
                }
            }
        }
    }
    gs.release_lists[gs.active_frame].count = 0; // reset but keep memory

    // reset frame memory pool
    Pool.reset(*gs.frame_pools[gs.active_frame]); // reset but keep memory
}

backend_wait_idle :: () {

}

backend_report_backend_debug_msgs :: (loc: Source_Code_Location = #caller_location) #expand {

}

#load "backend_swap_chain.jai";
#load "backend_pipeline.jai";
#load "backend_encoder.jai";
#load "backend_resources.jai";