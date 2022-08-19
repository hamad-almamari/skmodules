// MIT License

// Copyright (c) 2022 Hamad Almamari (hamad-r)

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// Good to know:
// This module is not thread safe.

#scope_module
Basic         :: #import "Basic";
String        :: #import "String";
Pool          :: #import "Pool";
DataStorage   :: #import "sk_Data_Storage"; // @TODO: make this local?
for_expansion :: DataStorage.for_expansion;

#if BACKEND == .D3D12 {
    #load "d3d12/backend.jai";
} else #if BACKEND == .DUMMY {
    #load "dummy/backend.jai";
}

#scope_export

#module_parameters ()(
    BACKEND     : Backend = .D3D12, // we should remove default
    DEBUG       := true,
    FRAME_COUNT :u16 = 2);
//---------------------------------------------------------------------

Backend :: enum u16 {
    DUMMY :: 1;
    D3D12 :: 2;
}

ASSERT_ON_FAIL :: true;


SWC_BUFFER_COUNT                :u16: 3;
SWC_STORAGE_MAX_COUNT_PER_BLOCK :u16: 4;
SWC_STORAGE_MAX_BLOCK_COUNT     :u16: 8;

PIP_STORAGE_MAX_COUNT_PER_BLOCK :u16: 4;
PIP_STORAGE_MAX_BLOCK_COUNT     :u16: 8;

PIP_MAX_VB_BINDINGS           :u16: 4;
PIP_MAX_RC_BINDINGS           :u16: 4;
PIP_MAX_BG_BINDINGS           :u16: 4;
PIP_MAX_STATIC_SAMPLERS       :u16: 1;
PIP_MAX_SIMULTANEOUS_RT_COUNT :u16: 4;

debug_messenger_proc :: default_debug_messenger_proc;


// ------------------------------------------
// BACKEND: general
#placeholder Backend_Native_Window;
#placeholder Backend_State;
#placeholder Backend_Adapter_Info;
#placeholder backend_get_available_adapters_info;
#placeholder backend_init;
#placeholder backend_deinit;
#placeholder backend_execute;
#placeholder backend_wait_idle;
// BACKEND: debug
#placeholder backend_report_backend_debug_msgs;
#placeholder Backend_Debug_Message_Type;
// BACKEND: swap chain
#placeholder Backend_Swap_Chain;
#placeholder backend_init_swap_chain;
#placeholder backend_resize_back_buffers;
#placeholder backend_deinit_swapchain;
// BACKEND: pipeline
#placeholder Backend_Pipeline;
#placeholder backend_init_pipeline;
#placeholder backend_deinit_pipeline;
// BACKEND: encoder
#placeholder Backend_Encoder;
#placeholder backend_begin_commands;
#placeholder backend_set_viewports;
#placeholder backend_set_scissor_rects;
#placeholder backend_push_constants;
#placeholder backend_set_vertex_buffer;
#placeholder backend_set_bind_group;
#placeholder backend_begin_renderpass;
#placeholder backend_end_renderpass;
#placeholder backend_draw;
#placeholder backend_draw_indexed;
#placeholder backend_copy_buffer;
#placeholder backend_deinit_encoder;
// BACKEND: resources
#placeholder Backend_Buffer;
#placeholder Backend_Texture;
#placeholder Backend_Bind_Group;
#placeholder backend_init_buffer;
#placeholder backend_deinit_buffer;
#placeholder backend_init_texture;
#placeholder backend_deinit_texture;
#placeholder backend_init_bind_group;
#placeholder backend_deinit_bind_group;
#placeholder backend_bind_texture;

gs: Global_State;

Global_State :: struct {
    using bs: Backend_State;
    using fs: Frontend_State;
}

Config :: struct {
    adapter_index: s32  = 0;
    vsync        : bool = false;
    allocator    : Allocator = .{}; // remove this?
}

Frontend_State :: struct {
    // -- core
    using config   : Config;
    config.adapter_index = -1;
    frame_pools    : [FRAME_COUNT] Pool.Pool; // will be reset at end of each frame.// @threadSupport make this thread local
    active_frame   : u16;
    frame_counter  : u64;
    release_lists  : [FRAME_COUNT][..] *Base;
    // -- swap chain
    swc_storage: DataStorage.Data_Storage(Swap_Chain, SWC_STORAGE_MAX_COUNT_PER_BLOCK, SWC_STORAGE_MAX_BLOCK_COUNT);
    // -- pipeline
    pip_storage: DataStorage.Data_Storage(Pipeline, PIP_STORAGE_MAX_COUNT_PER_BLOCK, PIP_STORAGE_MAX_BLOCK_COUNT);
    // -- encoder (command encoder)
    enc_storage: DataStorage.Data_Storage(Encoder, 32, 32);
    // -- resources
    staging_encoder: *Encoder; // will be reset each frame TODO (what if this empty) (this shall be per thread)
    bfr_storage: DataStorage.Data_Storage(Buffer, 32, 32);
    tex_storage: DataStorage.Data_Storage(Texture, 32, 32);
    bgr_storage: DataStorage.Data_Storage(Bind_Group, 32, 32);
}

Base :: struct {
    kind: enum u16 {
        UNKNOWN   :: 0;
        SWAPCHAIN :: 1;
        PIPELINE  :: 2;
        ENCODER   :: 3;
        RESOURCE  :: 4;
        BIND_GROUP :: 5;
    }
}


Native_Window :: Backend_Native_Window;

Adapter_Info :: struct {
    type: enum u16 {
        INVALID :: 0;
        GPU     :: 1;
        CPU     :: 2;
    };

    Vendor :: enum u32 {
        UNKNOWN   :: 0x0000;
        AMD       :: 0x1002;
        INTEL     :: 0x8086;
        NVIDIA    :: 0x10de;
        MICROSOFT :: 0x1414; // Microsoft Basic Render Driver (SOFTWARE/WRAP)
    }

    adapter_index  : s32 = -1;
    description    : string;
    vendor         : Vendor;
    device_id      : u32;
    vRAM_in_MP     : u64;

    using bk:Backend_Adapter_Info;
}

get_available_adapters_info :: backend_get_available_adapters_info;

init :: (config:Config = .{}) -> bool {
    #if DEBUG Basic.assert(!is_initialized() || config.adapter_index < 0);
    { // set allocators  
        // -- core
        gs.config = config;
        if  !gs.allocator.proc Basic.remember_allocators(*gs.config);
        for *gs.frame_pools    Pool.set_allocators(it, gs.allocator);
        for *gs.release_lists it.allocator = gs.allocator;
        // -- swap chain
        gs.swc_storage.allocator        = gs.allocator;
        // -- pipeline
        gs.pip_storage.allocator = gs.allocator;
        // -- encoder
        gs.enc_storage.allocator = gs.allocator;
        // -- resources
        gs.bfr_storage.allocator     = gs.allocator;
        gs.tex_storage.allocator    = gs.allocator;
        gs.bgr_storage.allocator = gs.allocator;
    }

    // init backend
    if !backend_init() {
        report_debug_msg(.ERROR, "initialization of the backend failed.");
        deinit();
        return false;
    }

    info := get_adapter_info(gs.adapter_index);
    report_debug_msg(.INFO, "initialization is completed: % (adapter_index:%).", info.description, info.adapter_index);

    // this must be here before create the buffer
    gs.staging_encoder = begin_commands(null, .FIRST);

    return true;
}

deinit :: () {
    // wait on the host for the GPU, for all operations
    wait_idle();
    // Release
    // -- resources
    for buffer: gs.bfr_storage {
        release_buffer_imm(buffer);
    }
    for texture: gs.tex_storage {
        release_texture_imm(texture);
    }
    // -- encoders
    {
        // here we want to loop over all items since encoders not reset when discard
        index := -1;
        for block, block_index: gs.enc_storage.all_data_blocks {
            for *slot, slot_index: block.slots {
                index += 1;
                if gs.enc_storage.count_high_water_mark == index break block;
                backend_deinit_encoder(*slot.item);
            }
        }
    }
    // -- pipeline
    for gs.pip_storage release_pipeline_imm(it);
    // -- swap chain
    for gs.swc_storage release_swap_chain_imm(it);
    // deinit backend
    backend_deinit();

    // clean up
    {
        // -- resources
        DataStorage.release(*gs.bfr_storage);
        DataStorage.release(*gs.tex_storage);
        // TODO bgr
        // -- encoder
        DataStorage.release(*gs.enc_storage);
        // -- pipeline
        DataStorage.release(*gs.pip_storage);
        // -- swap chain
        DataStorage.release(*gs.swc_storage);
        // -- core
        for *gs.release_lists Basic.array_reset(it);
        for *gs.frame_pools   Pool.release(it);
    }
    // reset
    gs.fs = .{};
}

execute :: backend_execute;

wait_idle :: backend_wait_idle;

// Helpers
get_adapters_count :: inline () -> int {
    adapters_info := get_available_adapters_info();
    return adapters_info.count;
}

get_adapter_info :: inline (adapter_index:int) -> Adapter_Info {
    adapters_info := get_available_adapters_info();
    return adapters_info[adapter_index];
}

is_initialized :: inline () -> bool {
    return gs.adapter_index > -1;
}

is_vsync :: inline () -> bool {
    return gs.vsync;
}

get_active_frame :: inline () -> u16 {
    return gs.active_frame;
}

get_frame_counter :: inline () -> u64 {
    return gs.frame_counter;
}

get_selected_adapter_info :: inline () -> Adapter_Info {
    #if DEBUG Basic.assert(gs.adapter_index > -1, "You need to call init_device before calling this proc.");
    return get_adapter_info(gs.adapter_index);
}

//#load "data_storage.jai";
#load "swap_chain.jai";
#load "pipeline.jai";
#load "encoder.jai";
#load "resources.jai";

// -------------------------------------------------------
// debug
//

Debug_Message_Severity :: enum u16 {
    ERROR   :: 0;
    WARNING :: 1;
    INFO    :: 2;
}

Backend_Debug_Message :: Backend_Debug_Message_Type;

default_debug_messenger_proc :: (severity:Debug_Message_Severity, text:string, loc:Source_Code_Location, bk_msg:*Backend_Debug_Message) {
    //if severity == .ERROR then Basic.assert(false, text, loc=loc);
    if bk_msg {
        #if BACKEND == .D3D12 {
            Basic.print("[D3D12][%]: % : %\n", bk_msg.Severity, bk_msg.Category, text);
            Basic.print("       (%)\n", loc);
        }
    } else {
        Basic.print("[GFX][%]: %\n", severity, text);
        //Basic.print("     (%)\n", loc);
        if severity == .ERROR then Basic.assert(false, text, loc=loc);
    }
}

#if DEBUG {
    report_debug_msg :: inline (severity:Debug_Message_Severity, format_string:string, args: .. Any, loc := #caller_location) {
        backend_report_backend_debug_msgs(loc);
        text := Basic.tprint(format_string, .. args);
        debug_messenger_proc(severity, text, loc, null);
    }
} else {
    report_debug_msg :: inline (severity:Debug_Message_Severity, format_string:string, args: .. Any, loc := #caller_location) #expand {

    }   
}