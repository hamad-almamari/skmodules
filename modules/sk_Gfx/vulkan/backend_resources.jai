#scope_module

Backend_Texture :: struct {

}

Backend_Buffer :: struct {

}

Backend_Bind_Group :: struct {

}

backend_init_buffer :: (using buffer:*Buffer) -> bool {
    return true;
}

backend_deinit_buffer :: inline (using buffer:*Buffer) {   

}

backend_init_texture :: (using texture:*Texture, texture_data:*void) -> bool {
    return true;
}

backend_deinit_texture :: inline (using texture:*Texture) {   

}

backend_init_bind_group :: (bind_group:*Bind_Group) -> bool {
    return true;  
}

backend_deinit_bind_group :: (bind_group:*Bind_Group) #expand {

}

backend_bind_texture :: (bind_group:*Bind_Group, offset:u32, texture:*Texture) {

}

backend_bind_constant_buffer :: (bind_group:*Bind_Group, offset:u32, buffer:*Buffer) {

}
