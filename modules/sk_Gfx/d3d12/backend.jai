#assert(OS == .WINDOWS);
#scope_module

Backend_Native_Window :: Windows.HWND;

Backend_State :: struct {
    // -- core
    // base
    d3d_factory            : *IDXGIFactory4;
    d3d_tearing_supported  : bool;
    d3d_adapters_info      : [] Adapter_Info;
    d3d_adapters_info_data : [8] Adapter_Info; // we will store the data here
    // device
    d3d_adapter            : *IDXGIAdapter1;
    d3d_device             : *ID3D12Device;
    d3d_debug_info_queue   : *ID3D12InfoQueue;
    // gpu timeline
    d3d_gpu_timeline_fence_value: u64;
    d3d_gpu_timeline_fence : *ID3D12Fence;
    // frame timeline
    d3d_frame_fence        : *ID3D12Fence; 
    // graphics queue
    d3d_graphics_queue     : *ID3D12CommandQueue;
    // other
    d3d_backend_initialized: bool;
    // -- swap chain
    d3d_swc_rtv_heap: *ID3D12DescriptorHeap; // NumDescriptors => max_count_per_block * max_block_count * SWC_BUFFER_COUNT
    // -- pipeline
    // nothing for now
    // -- encoder
    d3d_command_list_arrays: [PRIORTY_COUNT][..] *ID3D12CommandList; // used by "execute"
    // -- resources
    d3d_tex_rtv_heap: *ID3D12DescriptorHeap;
    d3d_tex_dsv_heap: *ID3D12DescriptorHeap;
    d3d_bgr_views_heap: *ID3D12DescriptorHeap; // shader visable (CBV_SRV_UAV) heap
    d3d_bgr_views_heap_mark: u32;
}

Backend_Adapter_Info :: struct {
    d3d_feature_level: D3D_FEATURE_LEVEL;
}

backend_get_available_adapters_info :: () -> [] Adapter_Info {
    if gs.d3d_factory then d3d_init_factory();
    return gs.d3d_adapters_info;
}

backend_init :: () -> bool {
    if gs.d3d_backend_initialized then return true;
    // -- core
    {
        // init factory if not initialized
        if !gs.d3d_factory then d3d_init_factory();
        //---------------
        // pick adapter
        result: HRESULT;
        dxgi_factory6: *IDXGIFactory6;
        factory6_hr := Windows.IUnknown_QueryInterface(gs.d3d_factory, *Windows.uid(IDXGIFactory6_UUID), xx *dxgi_factory6);
        if factory6_hr == S_OK {
            result = IDXGIFactory6_EnumAdapterByGpuPreference(dxgi_factory6, cast(u32) gs.adapter_index, .HIGH_PERFORMANCE, *Windows.uid(IDXGIAdapter1_UUID), xx *gs.d3d_adapter);
        } else {
            result = IDXGIFactory1_EnumAdapters1(gs.d3d_factory, cast(u32) gs.adapter_index, xx *gs.d3d_adapter);
        }
        if dxgi_factory6 then Windows.IUnknown_Release(dxgi_factory6);
        if !SUCCEEDED(result) || !gs.d3d_adapter {
            report_debug_msg(.ERROR, "No capable adapter found: adapter_index:%", gs.adapter_index);
            return false;
        }
        //---------------
        // create d3d12 device
        result = D3D12CreateDevice(gs.d3d_adapter, get_adapter_info(gs.adapter_index).d3d_feature_level, *Windows.uid(ID3D12Device_UUID), xx *gs.d3d_device);
        if result != S_OK {
            report_debug_msg(.ERROR, "D3D12CreateDevice failed: %", result);
            return false;
        }
        ID3D12Object_SetName(gs.d3d_device, xx WinUtf8.utf8_to_wide("device")); 
        //---------------
        // setup debug layer
        #if DEBUG {
            if SUCCEEDED(Windows.IUnknown_QueryInterface(gs.d3d_device, *Windows.uid(ID3D12InfoQueue_UUID), xx *gs.d3d_debug_info_queue)) {
                //  break (while running the .exe in VS)
                ID3D12InfoQueue_SetBreakOnSeverity(gs.d3d_debug_info_queue, .CORRUPTION, .TRUE);
                ID3D12InfoQueue_SetBreakOnSeverity(gs.d3d_debug_info_queue, .ERROR, .TRUE);
                // ID3D12InfoQueue_SetBreakOnSeverity(gs.d3d_debug_info_queue, .D3D12_MESSAGE_SEVERITY_WARNING, .TRUE);
                // ID3D12InfoQueue_SetBreakOnSeverity(gs.d3d_debug_info_queue, .D3D12_MESSAGE_SEVERITY_INFO, .TRUE);
                // ID3D12InfoQueue_SetBreakOnSeverity(gs.d3d_debug_info_queue, .D3D12_MESSAGE_SEVERITY_MESSAGE, .TRUE);
                //  setup
                size := ID3D12InfoQueue_GetStorageFilterStackSize(gs.d3d_debug_info_queue);
                while size > 1 {
                    ID3D12InfoQueue_ClearStorageFilter(gs.d3d_debug_info_queue);
                    size = ID3D12InfoQueue_GetStorageFilterStackSize(gs.d3d_debug_info_queue);
                }
                size = ID3D12InfoQueue_GetRetrievalFilterStackSize(gs.d3d_debug_info_queue);
                while size > 1 {
                    ID3D12InfoQueue_ClearRetrievalFilter(gs.d3d_debug_info_queue);
                    size = ID3D12InfoQueue_GetRetrievalFilterStackSize(gs.d3d_debug_info_queue);
                }
                ID3D12InfoQueue_ClearStoredMessages(gs.d3d_debug_info_queue);
                ID3D12InfoQueue_SetMuteDebugOutput(gs.d3d_debug_info_queue, .FALSE);
            } else {
                report_debug_msg(.WARNING, "QueryInterface failed (ID3D12InfoQueue) no d3d12 errors will be reported.");
            }
        }
        //---------------
        // init GPU Timeline
        gs.d3d_gpu_timeline_fence_value = 0;
        result = ID3D12Device_CreateFence(gs.d3d_device, 0, .SHARED, *Windows.uid(ID3D12Fence_UUID), xx *gs.d3d_gpu_timeline_fence);
        if result != S_OK {
            report_debug_msg(.ERROR, "ID3D12Device_CreateFence failed (gs.d3d_gpu_timeline_fence): %", result);
            return false;
        }
        ID3D12Object_SetName(gs.d3d_gpu_timeline_fence, xx WinUtf8.utf8_to_wide("gpu_timeline_fence"));
        //---------------
        // init frame Timeline
        gs.active_frame  = 0;
        gs.frame_counter = 0;
        result = ID3D12Device_CreateFence(gs.d3d_device, 0, .SHARED, *Windows.uid(ID3D12Fence_UUID), xx *gs.d3d_frame_fence);
        if result != S_OK {
            report_debug_msg(.ERROR, "ID3D12Device_CreateFence failed (gs.d3d_frame_fence): %", result);
            return false;
        }
        ID3D12Object_SetName(gs.d3d_frame_fence, xx WinUtf8.utf8_to_wide("frame_fence"));
        //---------------
        // describe and create the command queues
        // graphics_queue

        queue_desc: D3D12_COMMAND_QUEUE_DESC;
        queue_desc.Type     = .DIRECT;
        queue_desc.Priority = cast(s32) D3D12_COMMAND_QUEUE_PRIORITY.NORMAL;
        queue_desc.Flags    = .NONE;
        queue_desc.NodeMask = 0;
        result = ID3D12Device_CreateCommandQueue(gs.d3d_device, *queue_desc, *Windows.uid(ID3D12CommandQueue_UUID), xx *gs.d3d_graphics_queue);
        if result != S_OK {
            report_debug_msg(.ERROR, "ID3D12Device_CreateCommandQueue failed (gs.d3d_graphics_queue): %", result);
            return false;
        }
        ID3D12Object_SetName(gs.d3d_graphics_queue, xx WinUtf8.utf8_to_wide("graphics_queue"));
    }

    //--------------
    // -- swap chain
    {
        num_descriptors :: gs.swc_storage.max_count_per_block * gs.swc_storage.max_block_count * SWC_BUFFER_COUNT;
        #assert(num_descriptors <= 1_000_000); // Tire one
        rtv_heap: *ID3D12DescriptorHeap;
        rtv_heap_desc: D3D12_DESCRIPTOR_HEAP_DESC;
        rtv_heap_desc.NumDescriptors = num_descriptors;
        rtv_heap_desc.Type           = .RTV;
        rtv_heap_desc.Flags          = .NONE;
        result := ID3D12Device_CreateDescriptorHeap(gs.d3d_device, *rtv_heap_desc, *Windows.uid(ID3D12DescriptorHeap_UUID), xx *gs.d3d_swc_rtv_heap);
        if result != S_OK {
            report_debug_msg(.ERROR, "ID3D12Device_CreateDescriptorHeap failed (gs.d3d_swc_rtv_heap): %", result);
            return false;
        }
        ID3D12Object_SetName(gs.d3d_swc_rtv_heap, xx WinUtf8.utf8_to_wide("swc_rtv_heap"));
    }

    // -- pipeline
    // @TODO: check for root v1.0 at init

    // -- encoder 
    // nothing for now

    // -- resources
    {
        num_descriptors :: gs.tex_storage.max_count_per_block * gs.tex_storage.max_block_count;
        #assert(num_descriptors <= 1_000_000); // Tire one
        rtv_heap_desc: D3D12_DESCRIPTOR_HEAP_DESC;
        rtv_heap_desc.NumDescriptors = num_descriptors;
        rtv_heap_desc.Type           = .RTV;
        rtv_heap_desc.Flags          = .NONE;
        result := ID3D12Device_CreateDescriptorHeap(gs.d3d_device, *rtv_heap_desc, *Windows.uid(ID3D12DescriptorHeap_UUID), xx *gs.d3d_tex_rtv_heap);
        if result != S_OK {
            Basic.log_error("D3D12:ID3D12Device_CreateDescriptorHeap failed.");
            return false;
        }
        dsv_heap_desc: D3D12_DESCRIPTOR_HEAP_DESC;
        dsv_heap_desc.NumDescriptors = num_descriptors;
        dsv_heap_desc.Type           = .DSV;
        dsv_heap_desc.Flags          = .NONE;
        result = ID3D12Device_CreateDescriptorHeap(gs.d3d_device, *dsv_heap_desc, *Windows.uid(ID3D12DescriptorHeap_UUID), xx *gs.d3d_tex_dsv_heap);
        if result != S_OK {
            Basic.log_error("D3D12:ID3D12Device_CreateDescriptorHeap failed.");
            return false;
        }
        heap_desc: D3D12_DESCRIPTOR_HEAP_DESC;
        heap_desc.NumDescriptors = 1_000;    // Tire 1
        heap_desc.Type           = .CBV_SRV_UAV;
        heap_desc.Flags          = .SHADER_VISIBLE;
        result = ID3D12Device_CreateDescriptorHeap(gs.d3d_device, *heap_desc, *Windows.uid(ID3D12DescriptorHeap_UUID), xx *gs.d3d_bgr_views_heap);
        if result != S_OK {
            Basic.log_error("D3D12:ID3D12Device_CreateDescriptorHeap failed.");
        return false;
        }
        gs.d3d_bgr_views_heap_mark = 0;
    }

    Basic.log("init:...done.");
    gs.d3d_backend_initialized = true;
    return true;
}

backend_deinit :: () {
    d3d_report_debug_msgs();
    // -- resources
    if gs.d3d_tex_rtv_heap   Windows.IUnknown_Release(gs.d3d_tex_rtv_heap);
    if gs.d3d_tex_dsv_heap   Windows.IUnknown_Release(gs.d3d_tex_dsv_heap);
    if gs.d3d_bgr_views_heap Windows.IUnknown_Release(gs.d3d_bgr_views_heap);
    // -- encoder
    for *gs.d3d_command_list_arrays Basic.array_reset(it);
    // -- swap chain
    if gs.d3d_swc_rtv_heap Windows.IUnknown_Release(gs.d3d_swc_rtv_heap);

    Basic.log("deinit:...");
    // Queue
    if gs.d3d_graphics_queue {
        Windows.IUnknown_Release(gs.d3d_graphics_queue);
    }

    // Frame Timeline
    if gs.d3d_frame_fence        Windows.IUnknown_Release(gs.d3d_frame_fence);
    if gs.d3d_gpu_timeline_fence Windows.IUnknown_Release(gs.d3d_gpu_timeline_fence);

    // Device
    #if DEBUG {
        if gs.d3d_device {
            debug_device: *ID3D12DebugDevice;
            ok := Windows.IUnknown_QueryInterface(gs.d3d_device, *Windows.uid(ID3D12DebugDevice_UUID), xx *debug_device);
            Windows.IUnknown_Release(gs.d3d_device);
            if ok == S_OK {
                ID3D12DebugDevice_ReportLiveDeviceObjects(debug_device, D3D12_RLDO_FLAGS.DETAIL | .IGNORE_INTERNAL);
                Windows.IUnknown_Release(debug_device);
                d3d_report_debug_msgs();
            }
        }
    } else {
        if gs.d3d_device  Windows.IUnknown_Release(xx gs.d3d_device);
    }
    if gs.d3d_debug_info_queue  Windows.IUnknown_Release(gs.d3d_debug_info_queue);

    // Dxgi deinit factory
    if gs.d3d_adapter Windows.IUnknown_Release(gs.d3d_adapter);  
    if gs.d3d_factory Windows.IUnknown_Release(gs.d3d_factory);

    Basic.log("deinit:...done.");

    //gs = .{};
}

backend_execute :: () {
    // end resource staging encoder
    end_commands(gs.staging_encoder);
    // swc reslove commands 
    resolve_cmds := begin_commands(null, .LAST);
    for gs.swc_storage {
        if !it.swap_required || it.desc.sample_count == 1 continue;
        src := it.back_buffers[it.active_buffer_index];
        //resolve_sub_resource(resolve_cmds, it, src, sub_resource:u16);
        barrier: D3D12_RESOURCE_BARRIER;
        barrier.Type                   = .TRANSITION;
        barrier.Flags                  = .NONE;
        barrier.Transition.pResource   = src.d3d_resource;
        barrier.Transition.StateBefore = src.d3d_default_usage_state;
        barrier.Transition.StateAfter  = .RESOLVE_SOURCE; // can this be combined with default usage states?
        barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        sub_cmd_gpu_barrier(resolve_cmds, barrier, false);
        barrier.Transition.pResource   = it.d3d_back_buffer_resources[it.active_buffer_index];
        barrier.Transition.StateBefore = .PRESENT;
        barrier.Transition.StateAfter  = .RESOLVE_DEST;
        sub_cmd_gpu_barrier(resolve_cmds, barrier, true);
        // resolve the subresource 0
        ID3D12GraphicsCommandList_ResolveSubresource(resolve_cmds.d3d_command_list, it.d3d_back_buffer_resources[it.active_buffer_index], 0, src.d3d_resource, 0, conv_texture_format(it.desc.format));
        barrier.Transition.pResource   = src.d3d_resource;
        barrier.Transition.StateBefore = .RESOLVE_SOURCE;
        barrier.Transition.StateAfter  = src.d3d_default_usage_state;
        sub_cmd_gpu_barrier(resolve_cmds, barrier, false);
        barrier.Transition.pResource   = it.d3d_back_buffer_resources[it.active_buffer_index];
        barrier.Transition.StateBefore = .RESOLVE_DEST;
        barrier.Transition.StateAfter  = .PRESENT;
        sub_cmd_gpu_barrier(resolve_cmds, barrier, true);
    }
    end_commands(resolve_cmds);

    // WRNING: The execute/submit order is same as enum members. @priorityOrder
    {
        for encoder: gs.enc_storage {
            using encoder;
            // break if the encoder not used this frame or not inited
            if current_state == .INITIAL || current_state == .INVALID break;   // this the last used one
            Basic.assert(current_state == .EXECUTABLE); // make sure it closed
            Basic.array_add(*gs.d3d_command_list_arrays[priority], d3d_command_list);
            current_state = .INITIAL;
        }

        for gs.d3d_command_list_arrays {
            if !it.count continue; 
            // else execute
            ID3D12CommandQueue_ExecuteCommandLists(gs.d3d_graphics_queue, cast(u32) it.count, xx it.data);
        }

        for i:0..PRIORTY_COUNT-1 Basic.array_reset_keeping_memory(*gs.d3d_command_list_arrays[i]);
        DataStorage.reset(*gs.enc_storage);
    }

    // timeline mark (execute completed)
    gs.d3d_gpu_timeline_fence_value += 1;
    ID3D12CommandQueue_Signal(gs.d3d_graphics_queue, gs.d3d_gpu_timeline_fence, gs.d3d_gpu_timeline_fence_value);

    // to avoid device removed error
    ID3D12CommandQueue_Wait(gs.d3d_graphics_queue, gs.d3d_gpu_timeline_fence, gs.d3d_gpu_timeline_fence_value);

    for gs.swc_storage {
        if !it.swap_required continue;
        using it;
        //ID3D12CommandQueue_Wait(gs.d3d_graphics_queue, gs.d3d_gpu_timeline_fence, gs.d3d_gpu_timeline_fence_value);
        hr: HRESULT;
        if gs.vsync {
            hr = IDXGISwapChain_Present(d3d_swapchain, 1, 0);
        } else {
            flags: DXGI_PRESENT;
            if gs.d3d_tearing_supported then flags |= .ALLOW_TEARING; // This flag shall be not used with fullscreen of vsync > 0
            // 0 - Cancel the remaining time on the previously presented frame and discard this frame if a newer frame is queued.
            hr = IDXGISwapChain_Present(d3d_swapchain, 0, cast(u32) flags);
        }
        if hr != S_OK {
            err := "Unknown";
            if hr == DXGI_ERROR_DEVICE_RESET   err = "DXGI_ERROR_DEVICE_RESET";
            if hr == DXGI_ERROR_DEVICE_REMOVED err = "DXGI_ERROR_DEVICE_REMOVED";
            if hr == DXGI_STATUS_OCCLUDED      err = "DXGI_STATUS_OCCLUDED";
            Basic.log_error("IDXGISwapChain_Present faild. (%)", err);
            #if DEBUG Basic.assert(hr == S_OK); // SOMETHING BAD HAPPEN
        }

        active_buffer_index       = cast(u16) IDXGISwapChain3_GetCurrentBackBufferIndex(d3d_swapchain);
        swap_required       = false;

        // timeline mark (swapchain x)
        // // DO WE NEED THIS 
        // gs.d3d_gpu_timeline_fence_value += 1;
        // ID3D12CommandQueue_Signal(gs.d3d_graphics_queue, gs.d3d_gpu_timeline_fence, gs.d3d_gpu_timeline_fence_value);
    }

    // signal and increment the frame fence value.
    gs.frame_counter += 1;
    ID3D12CommandQueue_Signal(gs.d3d_graphics_queue, gs.d3d_frame_fence, gs.frame_counter);
    
    // new frame ----------------------------------------------------
    // move to next frame
    gs.active_frame = (gs.active_frame+1) % FRAME_COUNT;

    // wait for the active frame on the host.
    if gs.frame_counter >= FRAME_COUNT {
        // here we do not want the wait value for last frame, we want
        // to wait for the active/current/acquired frame (which in use).
        wait_value : u64 = (gs.frame_counter - FRAME_COUNT) + 1;
        // wait on the host
        if ID3D12Fence_GetCompletedValue(gs.d3d_frame_fence) < wait_value {
            ID3D12Fence_SetEventOnCompletion(gs.d3d_frame_fence, wait_value, null);
        }
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

    // begin new staging encoder
    gs.staging_encoder = begin_commands(null, .FIRST);
}

// wait on the host for the GPU, for all operations.
backend_wait_idle :: () {
    if gs.d3d_frame_fence {
        // wait on the host for the gpu
        if ID3D12Fence_GetCompletedValue(gs.d3d_frame_fence) < gs.frame_counter {
            ID3D12Fence_SetEventOnCompletion(gs.d3d_frame_fence, gs.frame_counter, null);
        }
    }
}

#load "backend_swap_chain.jai";
#load "backend_pipeline.jai";
#load "backend_encoder.jai";
#load "backend_resources.jai";
#load "dxgi_extra.jai";

Windows   :: #import "Windows";
WinUtf8   :: #import "Windows_Utf8";
BOOL      :: Windows.BOOL;
HRESULT   :: Windows.HRESULT;
IID       :: Windows.IID;
S_OK      :: Windows.S_OK;
FAILED    :: Windows.FAILED;
SUCCEEDED :: Windows.SUCCEEDED;
#import "dxgi";
#import "d3d12";
#import "d3d_compiler";

// https://stackoverflow.com/questions/37772540/generating-mipmaps-in-vulkan

#scope_file
// we must make sure to do not use any of other the state members (other than base)
// this may be called before init by backend_get_available_adapters_info
d3d_init_factory :: () -> bool {
    if gs.d3d_factory return true;
    gs.d3d_adapters_info.data = gs.d3d_adapters_info_data.data;
    #if DEBUG {
        // Enable the debug layer (requires the Graphics Tools "optional feature").
        // For Windows 10, to create a device that supports the debug layer,
        // enable the "Graphics Tools" optional feature. Go to the Settings panel,
        // under System, Apps & features, Manage optional Features, Add a feature,
        // and then look for "Graphics Tools".
        // NOTE: Enabling the debug layer after device creation will invalidate the active device.
        debug_interface: *ID3D12Debug1;
        if SUCCEEDED(D3D12GetDebugInterface(*Windows.uid(ID3D12Debug1_UUID), xx *debug_interface)) {
            ID3D12Debug1_EnableDebugLayer(debug_interface);
            ID3D12Debug1_SetEnableGPUBasedValidation(debug_interface, .TRUE);
            // ID3D12Debug1_SetEnableSynchronizedCommandQueueValidation(debug_interface, .TRUE);
        }
    }
    result: HRESULT;
    // Create Factory.
    dxgi_factory_flags: u32 = 0;
    #if DEBUG then dxgi_factory_flags |= DXGI_CREATE_FACTORY_DEBUG;
    result = CreateDXGIFactory2(dxgi_factory_flags, *Windows.uid(IDXGIFactory4_UUID), xx *gs.d3d_factory);
    if result != S_OK {
        report_debug_msg(.ERROR, "CreateDXGIFactory2 failed: %", result);
        return false;
    }
    // Try to obtain Factory6.
    dxgi_factory6: *IDXGIFactory6;
    factory6_hr := Windows.IUnknown_QueryInterface(gs.d3d_factory, *Windows.uid(IDXGIFactory6_UUID), xx *dxgi_factory6);
    // Determines whether tearing support is available.
    allow_tearing : BOOL = .FALSE;
    if factory6_hr == S_OK {
		allow_tearing : BOOL = .FALSE;
		result = IDXGIFactory5_CheckFeatureSupport(xx dxgi_factory6, .PRESENT_ALLOW_TEARING, *allow_tearing, size_of(BOOL));
		if FAILED(result) || allow_tearing == .FALSE {
			gs.d3d_tearing_supported = false;
        } else {
			gs.d3d_tearing_supported = true;
		}
    }
    // Get avilable adapters info (we do not select the adapter here)
    adapter: *IDXGIAdapter1;
    featurelevels := D3D_FEATURE_LEVEL.[
        // ._12_2, @NOTIMP
        ._12_1,
        ._12_0,
        ._11_1,
        ._11_0
    ];
    adapter_index :u32 = 0;
    while true {
        if factory6_hr == S_OK {
            result = IDXGIFactory6_EnumAdapterByGpuPreference(dxgi_factory6, adapter_index, .HIGH_PERFORMANCE, *Windows.uid(IDXGIAdapter1_UUID), xx *adapter);
        } else {
            result = IDXGIFactory1_EnumAdapters1(gs.d3d_factory, adapter_index, xx *adapter);
        }

        if SUCCEEDED(result) {
            desc:DXGI_ADAPTER_DESC1;
            IDXGIAdapter1_GetDesc1(adapter, *desc);
            // get and set the adapter info
            gs.d3d_adapters_info.count = adapter_index + 1;
            info := *gs.d3d_adapters_info[adapter_index];
            // type
            info.type = .GPU;
            if (desc.Flags & cast(u32) DXGI_ADAPTER_FLAG.SOFTWARE) info.type = .CPU;
            // description
            info.description = WinUtf8.wide_to_utf8(xx desc.Description.data, allocator=context.allocator);
            // vendor
            using Adapter_Info.Vendor;
            if desc.VendorId == cast(u16) MICROSOFT then info.vendor = MICROSOFT;
            if desc.VendorId == cast(u16) AMD       then info.vendor = AMD;
            if desc.VendorId == cast(u16) INTEL     then info.vendor = INTEL;
            if desc.VendorId == cast(u16) NVIDIA    then info.vendor = NVIDIA;
            info.device_id  = desc.DeviceId;
            info.vRAM_in_MP = desc.DedicatedVideoMemory / 1_048_576;
            // d3d feature level
            for i:0..featurelevels.count-1 {
                result := D3D12CreateDevice(adapter, featurelevels[i], *Windows.uid(ID3D12Device_UUID), null);
                // If ppDevice is NULL and the function succeeds, S_FALSE (0x1) is returned, rather than S_OK.
                if 0x1 == result {
                    info.d3d_feature_level = featurelevels[i];
                    break i;
                }
            }
            info.adapter_index = cast(s32) adapter_index;
            // move to next adapter
            Windows.IUnknown_Release(adapter);
            adapter = null;
            adapter_index += 1;
        } else {
            break;
        }
    }
    if adapter       then Windows.IUnknown_Release(adapter);
    if dxgi_factory6 then Windows.IUnknown_Release(dxgi_factory6);
    return true;
}

// debug 
#scope_module
Backend_Debug_Message_Type :: D3D12_MESSAGE;
backend_report_backend_debug_msgs :: d3d_report_debug_msgs;

d3d_report_debug_msgs :: (loc: Source_Code_Location = #caller_location) {
    if !gs.d3d_debug_info_queue return;
    d3d_info_queue := gs.d3d_debug_info_queue;
    msgs_count := ID3D12InfoQueue_GetNumStoredMessages(d3d_info_queue);
    // Basic.print("msgs_count: %\n", msgs_count);
    if msgs_count == 0 return;

    for 0..msgs_count-1 {
        size: u64;
        result := ID3D12InfoQueue_GetMessageA(d3d_info_queue, it, null, *size);

        // TODO: WARNING: This is dummy you should never alloc and free for each msg, but this just an example
        // You shall find better way.
        msg:= cast(*D3D12_MESSAGE) fp_alloc(xx size);
        result = ID3D12InfoQueue_GetMessageA(d3d_info_queue, it, msg, *size);
        //Basic.print("size: %\n", size);
        str: string;
        str.data  = msg.pDescription;
        str.count = xx msg.DescriptionByteLength;

        // TODO: convert Severity
        debug_messenger_proc(.ERROR, String.trim(str), loc, msg);
    }

    ID3D12InfoQueue_ClearStoredMessages(d3d_info_queue);
}

#scope_export 
// Compile Shader -----------------------------------------------------
compile_hlsl_shader :: (source: string, entry_point: string, shader_model: string) -> [] u8, bool {
    flags := D3DCOMPILE.ENABLE_STRICTNESS; 
    #if DEBUG {
        // Set the D3DCOMPILE_DEBUG flag to embed debug information in the shaders. 
        // Setting this flag improves the shader debugging experience, but still allows  
        // the shaders to be optimized and to run exactly the way they will run in  
        // the release configuration of this program. 
        flags |= .DEBUG; 
        // Disable optimizations to further improve shader debugging 
        flags |= .SKIP_OPTIMIZATION; 
    }
    defines: [] string;
    bytecode, errors, hr := D3DCompile(source, "source", defines, null, entry_point, shader_model, xx flags, 0);
    defer Basic.free(errors);

    r: [] u8;
    if FAILED(hr) { 
        Basic.free(bytecode);
        if errors Basic.log_error("compile_hlsl_shader: Error msg: %", errors);
        return r, false;
    }
    r.count = bytecode.count;
    r.data  = bytecode.data;
    return r, true;
}