#scope_module
Backend_Encoder :: struct {
    d3d_command_allocator : [FRAME_COUNT] *ID3D12CommandAllocator;
    d3d_command_list      : *ID3D12GraphicsCommandList4; // I Do not think 4 is required
    d3d_gpu_barriers      : [..] D3D12_RESOURCE_BARRIER;
    d3d_current_rp_targets: Renderpass_Targets;
}
// NOT THREAD SAFE for cmds note
// DO NOT STORE 
// MUST BE CLOSED BEFORE CALLing execute all commands
// REMOVE enc_storage
// TODO check the encoder state
backend_begin_commands :: (encoder:*Encoder) -> bool {
    frame := gs.active_frame;
    Basic.assert(encoder != null); // valid

    if !encoder.d3d_command_allocator[frame] {
        using encoder;
        result := ID3D12Device_CreateCommandAllocator(gs.d3d_device, .DIRECT, *Windows.uid(ID3D12CommandAllocator_UUID), xx *d3d_command_allocator[frame]);
        if result != S_OK {
            Basic.log_error("ID3D12Device_CreateCommandAllocator failed.");
            #if ASSERT_ON_FAIL Basic.assert(false);
            return false;
        }
        ID3D12Object_SetName(d3d_command_allocator[frame], xx WinUtf8.utf8_to_wide(Basic.tprint("GQ:CommandAllocator:[%]", frame)));
    }

    // if not initted
    if !encoder.d3d_command_list {
        using encoder;
        result := ID3D12Device_CreateCommandList(gs.d3d_device, 0, .DIRECT, d3d_command_allocator[frame], null, *Windows.uid(ID3D12GraphicsCommandList4_UUID), xx *d3d_command_list);
        if result != S_OK {
            Basic.log_error("ID3D12Device_CreateCommandList failed.");
            report_debug_msg(.ERROR, "ID3D12Device_CreateCommandList failed:%", result);
            // release???
            return false;
        }
        ID3D12Object_SetName(d3d_command_list, xx WinUtf8.utf8_to_wide(Basic.tprint("GQ:CommandList:%", "todo")));
        // Command lists are created in the recording state, but there is nothing
        // to record yet. The main loop expects it to be closed, so close it now.
        ID3D12GraphicsCommandList_Close(d3d_command_list);
        current_state = .INITIAL;
        d3d_gpu_barriers.allocator = gs.allocator;
    }

    Basic.assert(encoder.current_state == .INITIAL);

    // begin
    result: HRESULT;
    {
        using encoder;
        result = ID3D12CommandAllocator_Reset(d3d_command_allocator[frame]);
        #if DEBUG Basic.assert(S_OK == result);
        if pipeline {
            result = ID3D12GraphicsCommandList_Reset(d3d_command_list, d3d_command_allocator[frame], pipeline.d3d_pipeline_state);
            #if DEBUG Basic.assert(S_OK == result);
            if pipeline.d3d_root_signature {
                ID3D12GraphicsCommandList_SetGraphicsRootSignature(d3d_command_list, pipeline.d3d_root_signature);
                ID3D12GraphicsCommandList_SetDescriptorHeaps(d3d_command_list, 1, *gs.d3d_bgr_views_heap);
            }
            ID3D12GraphicsCommandList_IASetPrimitiveTopology  (d3d_command_list, pipeline.d3d_primitive_topology);
        } else {
            result = ID3D12GraphicsCommandList_Reset(d3d_command_list, d3d_command_allocator[frame], null);
            #if DEBUG Basic.assert(S_OK == result);
        }
    }

    return true;
}

backend_set_viewports :: inline (encoder:*Encoder, viewports:[] Viewport) { 
    #assert(size_of(D3D12_VIEWPORT) == size_of(Viewport));
    ID3D12GraphicsCommandList_RSSetViewports(encoder.d3d_command_list, xx viewports.count, cast(*D3D12_VIEWPORT) viewports.data);
}

backend_set_scissor_rects :: inline (encoder:*Encoder, rects:[] Scissor_Rect) { 
    #assert(size_of(D3D12_RECT) == size_of(Scissor_Rect));
    ID3D12GraphicsCommandList_RSSetScissorRects(encoder.d3d_command_list, xx rects.count, cast(*D3D12_RECT) rects.data);
}

backend_push_constants :: inline (using encoder:*Encoder, binding:u16, data:*void, size:u32, dest_offset:u32) {
    if pipeline.d3d_rc_parameter_index[binding] < 0 return; // do error
    num32bit :u32 = size/4;
    parameter_index: u32 = xx pipeline.d3d_rc_parameter_index[binding];
    ID3D12GraphicsCommandList_SetGraphicsRoot32BitConstants(d3d_command_list, parameter_index, num32bit, data, dest_offset);
}

backend_set_vertex_buffer :: (using encoder:*Encoder, binding:u16, buffer:*Buffer) {
    sub_cmd_flush_gpu_barriers_if_any(encoder);
    buffer_view: D3D12_VERTEX_BUFFER_VIEW;
    buffer_view.BufferLocation = buffer.d3d_gpu_va;
    buffer_view.StrideInBytes  = pipeline.vertex_layout_stride[binding];
    buffer_view.SizeInBytes    = buffer.desc.size;
    ID3D12GraphicsCommandList_IASetVertexBuffers(d3d_command_list, binding, 1, *buffer_view);
}

backend_set_index_buffer :: (using encoder:*Encoder, buffer:*Buffer) {
    sub_cmd_flush_gpu_barriers_if_any(encoder);
    buffer_view: D3D12_INDEX_BUFFER_VIEW;
    buffer_view.BufferLocation = buffer.d3d_gpu_va;
    buffer_view.SizeInBytes    = buffer.desc.size;
    buffer_view.Format         = .R32_UINT;        // TODO: Allow other formats or pass stride in desc
    ID3D12GraphicsCommandList_IASetIndexBuffer(d3d_command_list, *buffer_view);
}

backend_set_bind_group :: (using encoder:*Encoder, binding:u16, bind_group:*Bind_Group) {
    if pipeline.d3d_bg_parameter_index[binding] < 0 return; // do error
    heap_inc_size   := ID3D12Device_GetDescriptorHandleIncrementSize(gs.d3d_device, .CBV_SRV_UAV);
    heap_gpu_handle := ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(gs.d3d_bgr_views_heap);
    heap_gpu_handle.ptr += bind_group.d3d_heap_offset * heap_inc_size;
    parameter_index: u32 = xx pipeline.d3d_bg_parameter_index[binding];
    ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(d3d_command_list, RootParameterIndex=parameter_index, BaseDescriptor=heap_gpu_handle);
}

backend_begin_renderpass :: (using encoder:*Encoder, renderpass:Renderpass_Targets) {
    // Indicate that the back buffer will be used as a render target. (begin_renderpass)
    rt_count : u16 = 0;
    rt_desc  : [8] D3D12_RENDER_PASS_RENDER_TARGET_DESC;
    for rt, i: renderpass.rt {
        if !rt.target || !rt.target.d3d_resource break;
        // barriers
        if rt.target.d3d_default_usage_state != .RENDER_TARGET {
            rt_barrier: D3D12_RESOURCE_BARRIER;
            rt_barrier.Type                   = .TRANSITION;
            rt_barrier.Flags                  = .NONE;
            rt_barrier.Transition.pResource   = rt.target.d3d_resource;
            rt_barrier.Transition.StateBefore = rt.target.d3d_default_usage_state;
            rt_barrier.Transition.StateAfter  = .RENDER_TARGET;
            rt_barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
            sub_cmd_gpu_barrier(encoder, rt_barrier, false);
        }
        // render pass
        rt_desc[i].cpuDescriptor        = rt.target.d3d_rtv_or_dsv_cpu_handle;
        if #complete rt.load_op == {
            case .PRESERVE; rt_desc[i].BeginningAccess.Type = .PRESERVE;
            case .CLEAR;    rt_desc[i].BeginningAccess.Type = .CLEAR;
        }
        rt_desc[i].BeginningAccess.Clear.ClearValue.Format = .R32G32B32_FLOAT;
        rt_desc[i].BeginningAccess.Clear.ClearValue.Color  = rt.target.desc.clear_value.color;
        rt_desc[i].EndingAccess.Type = .PRESERVE;
        // other
        if rt.target.swap_chain {
            swap_chain := renderpass.rt[i].target.swap_chain;
            swap_chain.swap_required = true;
        } 

        rt_count += 1;
    }

    sub_cmd_flush_gpu_barriers_if_any(encoder);

    if renderpass.ds.target {
        ds_desc: D3D12_RENDER_PASS_DEPTH_STENCIL_DESC;
        ds_desc.cpuDescriptor               = renderpass.ds.target.d3d_rtv_or_dsv_cpu_handle;
        if #complete renderpass.ds.load_op == {
            case .PRESERVE; ds_desc.DepthBeginningAccess.Type = .PRESERVE;
            case .CLEAR;    ds_desc.DepthBeginningAccess.Type = .CLEAR;
        }
        ds_desc.DepthBeginningAccess.Clear.ClearValue.Format = .D32_FLOAT;
        ds_desc.DepthBeginningAccess.Clear.ClearValue.DepthStencil.Depth   = 1;//0xffff_ffff;
        ds_desc.DepthBeginningAccess.Clear.ClearValue.DepthStencil.Stencil = 0;
        //ds_desc.StencilBeginningAccess.Type = .NO_ACCESS;
        ds_desc.DepthEndingAccess.Type      = .PRESERVE;
        //ds_desc.StencilEndingAccess.Type    = .DISCARD;
        ID3D12GraphicsCommandList4_BeginRenderPass(d3d_command_list, rt_count, rt_desc.data, *ds_desc, .NONE);
    } else {
        ID3D12GraphicsCommandList4_BeginRenderPass(d3d_command_list, rt_count, rt_desc.data, null, .NONE);
    }
    d3d_current_rp_targets = renderpass;
}

backend_end_renderpass :: (using encoder:*Encoder) {
    ID3D12GraphicsCommandList4_EndRenderPass(d3d_command_list);
    for attachment, i: d3d_current_rp_targets.rt {
        if !attachment.target || !attachment.target.d3d_resource break;
        // barriers
        if attachment.target.d3d_default_usage_state != .RENDER_TARGET {
            rt_barrier: D3D12_RESOURCE_BARRIER;
            rt_barrier.Type                   = .TRANSITION;
            rt_barrier.Flags                  = .NONE;
            rt_barrier.Transition.pResource   = attachment.target.d3d_resource;
            rt_barrier.Transition.StateBefore = .RENDER_TARGET;
            rt_barrier.Transition.StateAfter  = attachment.target.d3d_default_usage_state;
            rt_barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
            sub_cmd_gpu_barrier(encoder, rt_barrier, false);
        }
    }
}

// vertex_count (Per instance)
backend_draw :: inline (using encoder:*Encoder, vertex_count:u32, instance_count:u32, first_vertex:u32, first_instance:u32) {
    ID3D12GraphicsCommandList_DrawInstanced(d3d_command_list, vertex_count, instance_count, first_vertex, first_instance);
}

// index_count (Per instance)
backend_draw_indexed :: inline (using encoder:*Encoder, index_count:u32, instance_count:u32, first_index:u32, first_vertex:u32, first_instance:u32) {
    ID3D12GraphicsCommandList_DrawIndexedInstanced(d3d_command_list, index_count, instance_count, first_index, xx first_vertex, first_instance);
}

backend_copy_buffer :: (using encoder:*Encoder, dst:*Buffer, dst_offset:u32, src:*Buffer, src_offset:u32, size:u32) {
    ID3D12GraphicsCommandList_CopyBufferRegion(d3d_command_list, dst.d3d_resource, dst_offset, src.d3d_resource, src_offset, size);
    // in d3d12: after above call the resource state will set to COPY_DEST we will add defered barrier 
    barrier: D3D12_RESOURCE_BARRIER;
    barrier.Type                   = .TRANSITION;
    barrier.Flags                  = .NONE;
    barrier.Transition.pResource   = dst.d3d_resource;
    barrier.Transition.StateBefore = .COPY_DEST;
    barrier.Transition.StateAfter  = dst.d3d_default_usage_state;
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    sub_cmd_gpu_barrier(encoder, barrier, false);
}


backend_resolve_sub_resource :: (using encoder:*Encoder, dst:*Texture, dst_sub_resource:u16, src:*Texture, src_sub_resource:u16) {
    barrier: D3D12_RESOURCE_BARRIER;
    barrier.Type                   = .TRANSITION;
    barrier.Flags                  = .NONE;
    barrier.Transition.pResource   = src.d3d_resource;
    barrier.Transition.StateBefore = src.d3d_default_usage_state;
    barrier.Transition.StateAfter  = .RESOLVE_SOURCE; // check if can this be combined with default usage states?
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    sub_cmd_gpu_barrier(encoder, barrier, false);
    barrier.Transition.pResource   = dst.d3d_resource;
    barrier.Transition.StateBefore = dst.d3d_default_usage_state;
    barrier.Transition.StateAfter  = .RESOLVE_DEST;
    sub_cmd_gpu_barrier(encoder, barrier, true);
    // resolve the subresource
    ID3D12GraphicsCommandList_ResolveSubresource(d3d_command_list, dst.d3d_resource, dst_sub_resource, src.d3d_resource, src_sub_resource, conv_texture_format(dst.desc.format));
    barrier.Transition.pResource   = src.d3d_resource;
    barrier.Transition.StateBefore = .RESOLVE_SOURCE;
    barrier.Transition.StateAfter  = src.d3d_default_usage_state;
    sub_cmd_gpu_barrier(encoder, barrier, false);
    barrier.Transition.pResource   = dst.d3d_resource;
    barrier.Transition.StateBefore = .RESOLVE_DEST;
    barrier.Transition.StateAfter  = dst.d3d_default_usage_state;
    sub_cmd_gpu_barrier(encoder, barrier, true);
}

backend_end_commands :: (using encoder:*Encoder) {
    sub_cmd_flush_gpu_barriers_if_any(encoder);
    result := ID3D12GraphicsCommandList_Close(d3d_command_list);
    d3d_report_debug_msgs();
    #if DEBUG Basic.assert(S_OK == result);
}


backend_deinit_encoder :: (using encoder:*Encoder) {
    if d3d_command_list Windows.IUnknown_Release(d3d_command_list);
    for i:0..FRAME_COUNT-1 {
        if d3d_command_allocator[i] then Windows.IUnknown_Release(d3d_command_allocator[i]);
    }
}

// impl those???
// internal use (it used by other commands)
sub_cmd_gpu_barrier :: (using encoder:*Encoder, barrier:D3D12_RESOURCE_BARRIER, im_flush:= false) {
    Basic.assert(thread_guard == context.thread_index);
    Basic.assert(current_state == .RECORDING || current_state == .RECORDING_RP);
    Basic.array_add(*d3d_gpu_barriers, barrier);
    if im_flush then sub_cmd_flush_gpu_barriers_if_any(encoder);
}

// internal use (used by other commands)
sub_cmd_flush_gpu_barriers_if_any :: (using encoder:*Encoder) {
    if d3d_gpu_barriers.count == 0 return;
    Basic.assert(thread_guard == context.thread_index);
    Basic.assert(current_state == .RECORDING);
    ID3D12GraphicsCommandList_ResourceBarrier(d3d_command_list, xx d3d_gpu_barriers.count, d3d_gpu_barriers.data);
    d3d_gpu_barriers.count = 0; // reset but keep the memory allocated
}