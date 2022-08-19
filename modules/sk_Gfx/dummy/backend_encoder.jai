#scope_module
Backend_Encoder :: struct {

}


backend_begin_commands :: (encoder:*Encoder) -> bool {
    return true;
}

backend_set_viewports :: inline (encoder:*Encoder, viewports:[] Viewport) { 
 
 }

backend_set_scissor_rects :: inline (encoder:*Encoder, rects:[] Scissor_Rect) { 
   
   }

backend_push_constants :: inline (using encoder:*Encoder, binding:u16, data:*void, size:u32, dest_offset:u32) {

}

backend_set_vertex_buffer :: (using encoder:*Encoder, binding:u16, buffer:*Buffer) {

}

backend_set_index_buffer :: (using encoder:*Encoder, buffer:*Buffer) {

}

backend_set_bind_group :: (using encoder:*Encoder, binding:u16, bind_group:*Bind_Group) {

}

backend_begin_renderpass :: (using encoder:*Encoder, renderpass:Renderpass_Targets) {

}

backend_end_renderpass :: (using encoder:*Encoder) {

}

// vertex_count (Per instance)
backend_draw :: inline (using encoder:*Encoder, vertex_count:u32, instance_count:u32, first_vertex:u32, first_instance:u32) {

}

// index_count (Per instance)
backend_draw_indexed :: inline (using encoder:*Encoder, index_count:u32, instance_count:u32, first_index:u32, first_vertex:u32, first_instance:u32) {

}

backend_copy_buffer :: (using encoder:*Encoder, dst:*Buffer, dst_offset:u32, src:*Buffer, src_offset:u32, size:u32) {

}


backend_resolve_sub_resource :: (using encoder:*Encoder, dst:*Texture, dst_sub_resource:u16, src:*Texture, src_sub_resource:u16) {

}

backend_end_commands :: (using encoder:*Encoder) {

}


backend_deinit_encoder :: (using encoder:*Encoder) {

}