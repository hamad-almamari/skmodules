#scope_module

Backend_Swap_Chain :: struct {
    d3d_swapchain: *IDXGISwapChain3;
    d3d_back_buffer_resources: [SWC_BUFFER_COUNT] *ID3D12Resource; // orginal backbuffers (sample_count = 1)
}

backend_init_swap_chain :: (using swap_chain:*Swap_Chain) -> bool {
    // since we use locator for rtv heap offset we must make sure it is valid
    #if DEBUG Basic.assert(locator.packed_locator != DataStorage.INVALID_LOCATOR_PACKED);
    // create the swap chain
    sc_desc: DXGI_SWAP_CHAIN_DESC1;
    sc_desc.BufferCount      = SWC_BUFFER_COUNT;
    sc_desc.Width            = desc.width;
    sc_desc.Height           = desc.height;
    sc_desc.Format           = conv_texture_format(desc.format);
    sc_desc.BufferUsage      = .RENDER_TARGET_OUTPUT;
    sc_desc.SwapEffect       = .FLIP_DISCARD; // BufferCount must be > 1 with FLIP effects.
    sc_desc.SampleDesc.Count = 1;
    sc_desc.Scaling          = .NONE; // .STRETCH;
    swapchain_flags: DXGI_SWAP_CHAIN_FLAG;
	if gs.d3d_tearing_supported then swapchain_flags |= .ALLOW_TEARING;
    sc_desc.Flags            = cast(u32) swapchain_flags;

    swapchain1: *IDXGISwapChain1;
    result := IDXGIFactory2_CreateSwapChainForHwnd(gs.d3d_factory,
        xx gs.d3d_graphics_queue,    // swap chain needs the queue so that it can force a flush on it.
        desc.native_window,
        *sc_desc,
        null,
        null,
        xx *swapchain1
        );
    if result != S_OK {
        report_debug_msg(.ERROR, "IDXGIFactory2_CreateSwapChainForHwnd failed (%).", result);
        return false;
    }
    result = Windows.IUnknown_QueryInterface(swapchain1, *Windows.uid(IDXGISwapChain3_UUID), xx *d3d_swapchain);
    Windows.IUnknown_Release(swapchain1);
    if result != S_OK {
        report_debug_msg(.ERROR, "IUnknown_QueryInterface (IDXGISwapChain3) failed (%).", result);
        return false;
    }
    // we do not support dummy DXGI fullscreen transitions.
    IDXGIFactory_MakeWindowAssociation(gs.d3d_factory, desc.native_window, xx DXGI_MWA.NO_ALT_ENTER);
    // create frame resources.
    {
        rtv_handle        := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(gs.d3d_swc_rtv_heap);
        rtv_heap_inc_size := ID3D12Device_GetDescriptorHandleIncrementSize(gs.d3d_device, .RTV);
        slot_location     := (locator.block_index * gs.swc_storage.max_count_per_block) + locator.slot_index;
        rtv_handle.ptr    += slot_location * rtv_heap_inc_size * SWC_BUFFER_COUNT;
        // create a RTV (Buffer) for each frame.
        for i:0..SWC_BUFFER_COUNT-1 {
            result = IDXGISwapChain_GetBuffer(d3d_swapchain, xx i, *Windows.uid(ID3D12Resource_UUID), xx *d3d_back_buffer_resources[i]);
            if result != S_OK {
                report_debug_msg(.ERROR, "IDXGISwapChain_GetBuffer failed buffer[%] (%).", i, result);
                return false;
            }
            // set pointers
            back_buffers[i] = *back_buffers_data[i];
            back_buffer := back_buffers[i];

            if desc.sample_count == 1 {
                back_buffer.d3d_resource = d3d_back_buffer_resources[i];
                back_buffer.d3d_default_usage_state = .PRESENT;
            } else {
                heap_properties: D3D12_HEAP_PROPERTIES;
                heap_properties.Type                 = .DEFAULT;
                heap_properties.CPUPageProperty      = .UNKNOWN;
                heap_properties.MemoryPoolPreference = .UNKNOWN;
                heap_properties.CreationNodeMask     = 0;
                heap_properties.VisibleNodeMask      = 0;
                res: D3D12_RESOURCE_DESC;
                res.Dimension        = .TEXTURE2D;
                res.Alignment        = 0;
                res.Width            = desc.width;
                res.Height           = desc.height;
                res.DepthOrArraySize = 1;
                res.MipLevels        = 1;
                res.Format           = conv_texture_format(desc.format);
                res.SampleDesc.Count = desc.sample_count;
                res.Layout           = .UNKNOWN;
                res.Flags            = .ALLOW_RENDER_TARGET;
                clear_value: D3D12_CLEAR_VALUE;
                clear_value.Format = res.Format;
                clear_value.Color  = desc.clear_color;
                result = ID3D12Device_CreateCommittedResource(gs.d3d_device, *heap_properties, .NONE, *res, .RENDER_TARGET, *clear_value, *Windows.uid(ID3D12Resource_UUID), xx *back_buffer.d3d_resource);
                if result != S_OK {
                    report_debug_msg(.ERROR, "ID3D12Device_CreateCommittedResource failed buffer[%] (%).", i, result);
                    return false;
                }
                back_buffer.d3d_default_usage_state = .RENDER_TARGET;
            }

            ID3D12Device_CreateRenderTargetView(gs.d3d_device, back_buffer.d3d_resource, null, rtv_handle);
            back_buffer.d3d_rtv_or_dsv_cpu_handle  = rtv_handle;
            back_buffer.d3d_rtv_or_dsv_heap_offset = slot_location;
            // @TextureRTV @TODO: CHECK THIS
            back_buffer.desc.usage        = .RENDER_TARGET;
            back_buffer.desc.format       = desc.format;
            back_buffer.desc.width        = desc.width;
            back_buffer.desc.height       = desc.height;
            back_buffer.desc.sample_count = desc.sample_count;
            back_buffer.desc.clear_value.color = desc.clear_color;
            back_buffer.swap_chain        = swap_chain;
            // move to next offset
            rtv_handle.ptr += (1 * rtv_heap_inc_size);;
        }
    }
    // set the backbuffer index for next present.
    active_buffer_index = cast(u16) IDXGISwapChain3_GetCurrentBackBufferIndex(d3d_swapchain);    
    return true;
}

backend_resize_back_buffers :: (using swap_chain:*Swap_Chain, width:u32, height:u32) {
    // @TODO:
}

backend_deinit_swapchain :: (using swap_chain:*Swap_Chain) {
    for i:0..SWC_BUFFER_COUNT-1 {
        if d3d_back_buffer_resources[i] == back_buffers_data[i].d3d_resource {
            Basic.assert(desc.sample_count == 1);
            if d3d_back_buffer_resources[i] then Windows.IUnknown_Release(d3d_back_buffer_resources[i]);
        } else {
            if d3d_back_buffer_resources[i] then Windows.IUnknown_Release(d3d_back_buffer_resources[i]);
            if back_buffers_data[i].d3d_resource Windows.IUnknown_Release(back_buffers_data[i].d3d_resource);
        }
    }
    if d3d_swapchain Windows.IUnknown_Release(d3d_swapchain);
}