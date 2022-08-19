Encoder :: struct {  // RESET some of THIS at begin
    #as using base: Base;
    base.kind = .ENCODER;
    priority: Execute_Priority = .NORMAL;
    pipeline: *Pipeline;
    current_state        : Encoder_State = .INVALID;
    thread_guard         : u32;

    using bk:Backend_Encoder;
}

Encoder_State :: enum u16 {
    INVALID      :: 0; // after execute
    INITIAL      :: 1; // when the encoder resrved from the storage
    RECORDING    :: 2; // after begin
    RECORDING_RP :: 3; // inside render pass
    EXECUTABLE   :: 4; // after end
}

// WRNING: The Execute order is same as enum members. @priorityOrder
Execute_Priority :: enum u16 { // FIRST -> NORMAL -> LAST -> GUI 
    FIRST   :: 0;
    NORMAL  :: 1;
    LAST    :: 2;
//    GUI    :: 3; // custom queue?
}

PRIORTY_COUNT :: #run Basic.enum_highest_value(Execute_Priority) + 1;

Viewport ::  struct {
    left , top   : float;
    right, bottom: float;
    min_depth    : float = 0.0;
    max_depth    : float = 1.0;   
}

Scissor_Rect ::  struct {
    left , top   : s32;
    right, bottom: s32;  
}

Renderpass_Targets :: struct {
    Target :: struct {
        load_op: enum u16 {
            PRESERVE :: 0;
            CLEAR    :: 1;
        };
        target: *Texture;
    }
    rt: [PIP_MAX_SIMULTANEOUS_RT_COUNT] Target;
    ds: Target;
}

// NOT THREAD SAFE for cmds note
// DO NOT STORE 
// MUST BE CLOSED BEFORE CALLing execute all commands
begin_commands :: inline (pipeline: *Pipeline = null, priority := Execute_Priority.NORMAL) -> *Encoder {
    encoder: *Encoder = DataStorage.get(*gs.enc_storage, initialized=false);
    Basic.assert(encoder != null); // full
    encoder.priority = priority;
    encoder.pipeline = pipeline;
    encoder.thread_guard = context.thread_index;
    encoder.current_state = .INITIAL;
    if !backend_begin_commands(encoder) {
        report_debug_msg(.ERROR, "begining new command encoder failed.");
        return null;
    }
    encoder.current_state = .RECORDING;
    return encoder;
}

set_viewports :: (using encoder:*Encoder, viewports: [] Viewport) {
    Basic.assert(thread_guard == context.thread_index && pipeline != null);
    Basic.assert(current_state == .RECORDING || current_state == .RECORDING_RP);
    inline backend_set_viewports(encoder, viewports);
}

set_viewport :: (using encoder:*Encoder, left:float, top:float, right:float, bottom:float, min_depth:float=0, max_depth:float=1) {
    Basic.assert(thread_guard == context.thread_index && pipeline != null);
    Basic.assert(current_state == .RECORDING || current_state == .RECORDING_RP);
    viewports: [1] Viewport;
    viewports[0].left      = left;
    viewports[0].top       = top;
    viewports[0].right     = right;
    viewports[0].bottom    = bottom;
    viewports[0].min_depth = min_depth;
    viewports[0].max_depth = max_depth;
    inline backend_set_viewports(encoder, viewports);
}

set_scissor_rects :: (encoder:*Encoder, rects:[] Scissor_Rect) {
    Basic.assert(thread_guard == context.thread_index && pipeline != null);
    Basic.assert(current_state == .RECORDING || current_state == .RECORDING_RP);
    inline backend_set_scissor_rects(encoder, rects);
}

set_scissor_rect :: (using encoder:*Encoder, left:s32, top:s32, right:s32, bottom:s32) {
    Basic.assert(thread_guard == context.thread_index && pipeline != null);
    Basic.assert(current_state == .RECORDING || current_state == .RECORDING_RP);
    rects: [1] Scissor_Rect;
    rects[0].left   = left;
    rects[0].top    = top;
    rects[0].right  = right;
    rects[0].bottom = bottom;
    inline backend_set_scissor_rects(encoder, rects);
}

// helper
set_viewport_from_swc_desc :: inline (encoder:*Encoder, swc_desc:Swap_Chain_Desc) {
    set_viewport(encoder, 0, 0, xx swc_desc.width, xx swc_desc.height);
}

// helper
set_scissor_rect_from_swc_desc :: inline (encoder:*Encoder, swc_desc:Swap_Chain_Desc) {
    set_scissor_rect(encoder, 0, 0, xx swc_desc.width, xx swc_desc.height);
}

push_constants :: (using encoder:*Encoder, binding_index:u16, data:*void) {
    Basic.assert(thread_guard == context.thread_index && pipeline != null);
    Basic.assert(current_state == .RECORDING || current_state == .RECORDING_RP);
    #if DEBUG {
        b := pipeline.desc.rc_bindings[binding_index];
        if b.shader_visibilty == .IGNORED_BINDING || b.shader_register < 0 {
            report_debug_msg(.ERROR, "You are pushing constants into IGNORED_BINDING or with invalid shader register, rc_bindings[%].", binding_index);
            return;
        }
        if !b.size {
            report_debug_msg(.ERROR, "You are pushing constants into binding with invalid size, rc_bindings[%].", binding_index);
            return;
        }
    }
    inline backend_push_constants(encoder, binding_index, data, pipeline.desc.rc_bindings[binding_index].size, 0);
}

set_vertex_buffer :: (using encoder:*Encoder, binding:u16, buffer:*Buffer) {
    Basic.assert(thread_guard == context.thread_index && pipeline != null);
    Basic.assert(current_state == .RECORDING || current_state == .RECORDING_RP);
    Basic.assert(buffer.desc.usage & .VERTEX_BUFFER != 0);
    inline backend_set_vertex_buffer(encoder, binding, buffer);
}

set_index_buffer :: (using encoder:*Encoder, buffer:*Buffer) {
    Basic.assert(thread_guard == context.thread_index && pipeline != null);
    Basic.assert(current_state == .RECORDING || current_state == .RECORDING_RP);
    Basic.assert(buffer.desc.usage & .INDEX_BUFFER != 0);
    inline backend_set_index_buffer(encoder, buffer);
}

set_bind_group :: (using encoder:*Encoder, binding_index:u16, bind_group:*Bind_Group) {
    Basic.assert(thread_guard == context.thread_index && pipeline != null);
    Basic.assert(current_state == .RECORDING || current_state == .RECORDING_RP);
    // TODO: extra checks, validate based on the bind group resources usage
    #if DEBUG {
        b := pipeline.desc.bg_bindings[binding_index];
        if b.shader_visibilty == .IGNORED_BINDING {
            report_debug_msg(.ERROR, "You are seting bind group into IGNORED_BINDING, bg_bindings[%].", binding_index);
            return;
        }
    }
    inline backend_set_bind_group(encoder, binding_index, bind_group);
}

begin_renderpass :: (using encoder:*Encoder, renderpass:Renderpass_Targets) {
    Basic.assert(thread_guard == context.thread_index && pipeline != null);
    Basic.assert(current_state == .RECORDING); 
    // CHECK COUNT + FORMAT + SAMPLE COUNT
    inline backend_begin_renderpass(encoder, renderpass);
    current_state = .RECORDING_RP;
}

end_renderpass :: (using encoder:*Encoder) {
    Basic.assert(thread_guard == context.thread_index && pipeline != null);
    Basic.assert(current_state == .RECORDING_RP);
    inline backend_end_renderpass(encoder);
    current_state = .RECORDING;
}

// vertex_count (Per instance)
draw :: (using encoder:*Encoder, vertex_count:u32, instance_count:u32=1, first_vertex:u32=0, first_instance:u32=0) {
    Basic.assert(thread_guard == context.thread_index && pipeline != null);
    Basic.assert(current_state == .RECORDING_RP);
    inline backend_draw(encoder, vertex_count, instance_count, first_vertex, first_instance);
}

// vertex_count (Per instance)
draw_indexed :: (using encoder:*Encoder, index_count:u32, instance_count:u32=1, first_index:u32=0, first_vertex:u32=0, first_instance:u32=0) {
    Basic.assert(thread_guard == context.thread_index && pipeline != null);
    Basic.assert(current_state == .RECORDING_RP);
    inline backend_draw_indexed(encoder, index_count, instance_count, first_index, first_vertex, first_instance);
}

copy_buffer :: (using encoder:*Encoder, dst:*Buffer, dst_offset:u32, src:*Buffer, src_offset:u32, size:u32) {
    Basic.assert(thread_guard == context.thread_index);
    Basic.assert(current_state == .RECORDING);
    // TODO: make sure no overflow
    inline backend_copy_buffer(encoder, dst, dst_offset, src, src_offset, size);
}

resolve_sub_resource :: (using encoder:*Encoder, dst:*Texture, dst_sub_resource:u16, src:*Texture, src_sub_resource:u16) {
    Basic.assert(thread_guard == context.thread_index);
    Basic.assert(current_state == .RECORDING);
    Basic.assert(dst.desc.format == src.desc.format);
    inline backend_resolve_sub_resources(encoder, dst, dst_sub_resource, src, src_sub_resource);
    if dst.swap_chain {
        swap_chain := dst.swap_chain;
        swap_chain.swap_required = true;
    }
}

end_commands :: (using encoder:*Encoder) {
    Basic.assert(thread_guard == context.thread_index);
    Basic.assert(current_state == .RECORDING);
    inline backend_end_commands(encoder);
    current_state = .EXECUTABLE;
}