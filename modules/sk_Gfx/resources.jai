Clear_Value :: struct {
    color  : [4] float;
    #place color;
    depth  : float;
    stencil: u8;
}

//     COMMON                            :: 0;

//     VERTEX_AND_CONSTANT_BUFFER        :: 1;
//     INDEX_BUFFER                      :: 2;

//     RENDER_TARGET                     :: 4; // auto
//     UNORDERED_ACCESS                  :: 8;
//     DEPTH_WRITE                       :: 16;
//     DEPTH_READ                        :: 32;
//     NON_PIXEL_SHADER_RESOURCE         :: 64;
//     PIXEL_SHADER_RESOURCE             :: 128;
//     STREAM_OUT                        :: 256;

//     INDIRECT_ARGUMENT                 :: 512;

//     COPY_DEST                         :: 1024;
//     COPY_SOURCE                       :: 2048;
//     RESOLVE_DEST                      :: 4096;
//     RESOLVE_SOURCE                    :: 8192;
//     RAYTRACING_ACCELERATION_STRUCTURE :: 4194304;
//     SHADING_RATE_SOURCE               :: 16777216;

//     GENERIC_READ                      :: 2755;
//     PRESENT                           :: 0;
//     PREDICATION                       :: 512;

	// enum class ResourceState
	// {
	// 	// Common resource states:
	// 	.NONE = 0,						// invalid state (don't preserve contents) // vk has this
	// 	SHADER_RESOURCE = 1 << 0,			// shader resource, read only
	// 	SHADER_RESOURCE_COMPUTE = 1 << 1,	// shader resource, read only, non-pixel shader
	// 	UNORDERED_ACCESS = 1 << 2,			// shader resource, write enabled
	// 	COPY_SRC = 1 << 3,					// copy from
	// 	COPY_DST = 1 << 4,					// copy to

	// 	// Texture specific resource states:
	// 	RENDERTARGET = 1 << 5,				// render target, write enabled
	// 	DEPTHSTENCIL = 1 << 6,				// depth stencil, write enabled
	// 	DEPTHSTENCIL_READONLY = 1 << 7,		// depth stencil, read only
	// 	SHADING_RATE_SOURCE = 1 << 8,		// shading rate control per tile

	// 	// GPUBuffer specific resource states:
	// 	VERTEX_BUFFER = 1 << 9,				// vertex buffer, read only
	// 	INDEX_BUFFER = 1 << 10,				// index buffer, read only
	// 	CONSTANT_BUFFER = 1 << 11,			// constant buffer, read only
	// 	INDIRECT_ARGUMENT = 1 << 12,			// argument buffer to DrawIndirect() or DispatchIndirect()
	
    // 	RAYTRACING_ACCELERATION_STRUCTURE = 1 << 13, // acceleration structure storage or scratch
	// 	PREDICATION = 1 << 14				// storage for predication comparison value
	// };

//     VK_ACCESS_INDIRECT_COMMAND_READ_BIT :: 1;
//     VK_ACCESS_INDEX_READ_BIT :: 2;
//     VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT :: 4;
//     VK_ACCESS_UNIFORM_READ_BIT :: 8;
//     VK_ACCESS_INPUT_ATTACHMENT_READ_BIT :: 16;
//     VK_ACCESS_SHADER_READ_BIT :: 32;
//     VK_ACCESS_SHADER_WRITE_BIT :: 64;
//     VK_ACCESS_COLOR_ATTACHMENT_READ_BIT :: 128;
//     VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT :: 256;
//     VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT :: 512;
//     VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT :: 1024;
//     VK_ACCESS_TRANSFER_READ_BIT :: 2048;
//     VK_ACCESS_TRANSFER_WRITE_BIT :: 4096;
//     VK_ACCESS_HOST_READ_BIT :: 8192;
//     VK_ACCESS_HOST_WRITE_BIT :: 16384;
//     VK_ACCESS_MEMORY_READ_BIT :: 32768;
//     VK_ACCESS_MEMORY_WRITE_BIT :: 65536;

// IDEA block resource from being used with write state from useing with other encoder with same priroty.
// it will be manged by the backend
// the resource initial state as per usage flags in this order
// COPY_DST -> UNORDERED_ACCESS -> RENDER_TARGET -> DEPTH_STENCIL -> (all read only states)

// read-only states cannot be combined with write-states
// one write state only
// Resource_State_Flags :: enum_flags u32 {
//     COPY_SRC          :: 1 << 1;  // read only
//     COPY_DST          :: 1 << 2;  // write only (auto)
//     UNORDERED_ACCESS  :: 1 << 3;  // read/write (with buffer only)

//     SHADER_RESOURCE   :: 1 << 4;     // read only
//     PIXEL_SHADER_RESOURCE :: 1 << 5; // read only

//     RENDER_TARGET     :: 1 << 8;  // write only
//     DEPTH_STENCIL     :: 1 << 9;  // write only

//     VERTEX_BUFFER     :: 1 << 14; // read only
// 	INDEX_BUFFER      :: 1 << 15; // read only
// 	CONSTANT_BUFFER   :: 1 << 16; // read only
// 	INDIRECT_BUFFER   :: 1 << 17; // read only

//     PRESENT           :: 1 << 25;
// }

// Texture_State_Flags :: enum_flags u32 {
//     COPY_SRC              :: 1 << 1;  // read only
//     COPY_DST              :: 1 << 2;  // write only (auto)
//     UNORDERED_ACCESS      :: 1 << 3;  // read/write (with buffer only or texture)

//     SHADER_RESOURCE       :: 1 << 4;  // read only (shader resource view.)
//     PIXEL_SHADER_RESOURCE :: 1 << 5;  // read only     (shader resource view.)

//     // one of the three
//     RENDER_TARGET     :: 1 << 8;  // write only
//     DEPTH_STENCIL     :: 1 << 9;  // write only

//     // one of them
//     VERTEX_BUFFER     :: 1 << 14; // read only
// 	INDEX_BUFFER      :: 1 << 15; // read only
// 	CONSTANT_BUFFER   :: 1 << 16; // read only
// 	INDIRECT_BUFFER   :: 1 << 17; // read only

//     PRESENT           :: 1 << 25;
// }

// D3D12_RESOURCE_STATES :: enum s32 {
//     COMMON                            :: 0;

//     VERTEX_AND_CONSTANT_BUFFER        :: 1;
//     INDEX_BUFFER                      :: 2;

//     RENDER_TARGET                     :: 4; // auto
//     UNORDERED_ACCESS                  :: 8;
//     DEPTH_WRITE                       :: 16;
//     DEPTH_READ                        :: 32;
//     NON_PIXEL_SHADER_RESOURCE         :: 64;
//     PIXEL_SHADER_RESOURCE             :: 128;
//     STREAM_OUT                        :: 256;

//     INDIRECT_ARGUMENT                 :: 512;

//     COPY_DEST                         :: 1024;
//     COPY_SOURCE                       :: 2048;
//     RESOLVE_DEST                      :: 4096;
//     RESOLVE_SOURCE                    :: 8192;
//     RAYTRACING_ACCELERATION_STRUCTURE :: 4194304;
//     SHADING_RATE_SOURCE               :: 16777216;

//     GENERIC_READ                      :: 2755;
//     PRESENT                           :: 0;
//     PREDICATION                       :: 512;

// convert_resource_state :: (st:Resource_State_Flags) -> D3D12_RESOURCE_STATES {
//     // state can not has more than 2 write states.
//     // state can not has write state and read-only state combined.
//     r: D3D12_RESOURCE_STATES;

//     write_count := 0;
//     read_count  := 0;

//     if st & .COPY_SRC { // read only
//         r |= .COPY_SOURCE;
//         read_count += 1;
//     } 
//     if st & .COPY_DST { // write only
//         r |= .COPY_DEST;
//         write_count += 1;
//     } 
//     if st & .UNORDERED_ACCESS { // read/write
//         r |= .UNORDERED_ACCESS;
//         write_count += 1;
//     } 
//     if st & .SHADER_RESOURCE { // read only
//         r |= .PIXEL_SHADER_RESOURCE;
//         r |= .NON_PIXEL_SHADER_RESOURCE;
//         read_count += 1;
//     } 
//     if st & .PIXEL_SHADER_RESOURCE { // read only
//         r |= .PIXEL_SHADER_RESOURCE;
//         read_count += 1;
//     }
//     if st & .RENDER_TARGET { // write only
//         r |= .RENDER_TARGET;
//         write_count += 1;
//     }
//     if st & .DEPTH_STENCIL { // write only
//         r |= .DEPTH_WRITE;
//         write_count += 1;
//     }   
//     if st & .VERTEX_BUFFER { // read only
//         r |= .VERTEX_AND_CONSTANT_BUFFER;
//         read_count += 1;
//     }
//     if st & .INDEX_BUFFER { // read only
//         r |= .INDEX_BUFFER;
//         read_count += 1;
//     }
//     if st & .CONSTANT_BUFFER { // read only
//         r |= .VERTEX_AND_CONSTANT_BUFFER;
//         read_count += 1;
//     }
//     if st & .INDIRECT_BUFFER { // read only
//         r |= .INDIRECT_ARGUMENT;
//         read_count += 1;
//     }
//     if st == .PRESENT { // can not be used with other states
//         r |= .PRESENT;
//         read_count += 1;
//     }
//     #if DEBUG {
//         if read_count > 0  && write_count > 0  then Basic.assert(false);
//         if read_count == 0 && write_count != 1 then Basic.assert(false);
//     }

//     return r;
// }

// Texture_Usage_Flags :: enum_flags u32 {
//     COPY_SRC          :: 1 << 1;
//     COPY_DST          :: 1 << 2;
//     UNORDERED_ACCESS  :: 1 << 3; 
//     SHADER_RESOURCE   :: 1 << 4;
//     PIXEL_SHADER_RESOURCE :: 1 << 5;
//     RENDER_TARGET     :: 1 << 8;
//     DEPTH_STENCIL     :: 1 << 9;
// }

// Buffer_State_Flags :: Buffer_Usage_Flags;
// Buffer_Usage_Flags :: enum u32 {
//     TRANSFER_SRC      :: 1 << 1;  // read only
//     TRANSFER_DST      :: 1 << 2;  // write only
//     UNORDERED_ACCESS  :: 1 << 3;  // read/write 
//     // SHADER_RESOURCE   :: 1 << 4;  // read only
//     VERTEX_BUFFER     :: 1 << 20; // read only
// 	INDEX_BUFFER      :: 1 << 21; // read only
// 	CONSTANT_BUFFER   :: 1 << 22; // read only
// 	INDIRECT_BUFFER   :: 1 << 23; // read only
// }


// Texture -----------------------------------------

Texture_Desc :: struct {
    usage       : Texture_Usage;
    width       : u32;
    height      : u32;
    depth       : u32 = 1;
    format      : Texture_Format;
    sample_count: u16 = 1;
    mip_levels  : u16 = 1;
    array_layers: u16 = 1;
    clear_value : Clear_Value;
}

// same as Simp module
Texture_Format :: enum u16 {
    UNKNOWN  :: 0;

    R8       :: 1;   // Fixed point formats.
    RG8      :: 2;
    RGB8     :: 3;
    RGBA8    :: 4;
    BGRA8;
    B5G6R5;
    RGB10A2;
    R16;

    R16F :: 0x10;   // Floating point formats.
    RG16F;
    RGBA16F;
    R32F;
    RG32F;
    RGBA32F;
    RG11B10F;
    RGB9E5F;

    R16I;           // Integer formats.
    RG16I;
    RGBA16I;
    R32I;
    RG32I;
    RGBA32I;

    BC1 :: 0x100; // Block compression formats.
    BC3;
    BC4;
    BC5;
    BC6;
    BC7;

    ETC_RGB;
    ETC_RGBA;
    ETC_R;
    ETC_RG;
    ETC_RGB_A1;

    D16;        // Depth formats.
    D24S8;
    D32F;
    D32FS8;
}



// no need for this just use footprint
// get_bytes_per_texel :: (format:Texture_Format) -> u16 { 
//     if format == {
//         case .UNKNOWN; return 0;
//         case .R8; return 1;
//         case .RG8; return 2;
//         case .RGB8; return 3;
//         case .RGBA8; return 4;
//         // TODO: other formats
//     }
//     Basic.assert(false, "unsupported format"); // unsupported
//     return 0;
// }

Texture_Usage :: enum_flags u32 {
    // texture type (default is TEXTURE_2D)
    TEXTURE_1D            :: 1 << 1;
    TEXTURE_3D            :: 1 << 2;
    // read-only usage
    SHADER_RESOURCE       :: 1 << 3; // this mean the texture will be used in the shader
    PIXEL_SHADER_RESOURCE :: 1 << 4;
    // read/write usage
    UNORDERED_ACCESS      :: 1 << 5; // STORAGE?
    // write-only usage 
    RENDER_TARGET         :: 1 << 6;
    DEPTH_STENCIL         :: 1 << 7;
}

Texture :: struct {
    using #as resource: Resource;
    resource.resource_type = .TEXTURE;
    desc          : Texture_Desc;
    upload_size   : u32; // upload size (the size of the resource in the gpu)
    swap_chain    : *Swap_Chain;

    using bk:Backend_Texture;
}

// TODO: make sure the user use correct usages (ex can not be both RT and DS)
// NOTE: stride of texture_data must be 4 byte algin
// BUG: if texture data is null and then the texture used at the shader will crash!!! fix this
create_texture :: (texture_desc:Texture_Desc, texture_data:*void = null) -> *Texture {
    // TODO: check sample count?
    // check that depth can only used with 3d textures
    // array count can be used with 2d textures (we can also add support for 1D textures if it worthing)
    // check if the array count not 1 , and the user by mistake give the whole texture width & height
    // NOTE: for now when using texture 3d array the slices must be ordered VER! can we add auto detict for HOR.
    using texture := DataStorage.get(*gs.tex_storage, initialized=true);
    Basic.assert(texture != null);
    desc  = texture_desc;

    if !backend_init_texture(texture, texture_data) {
        report_debug_msg(.ERROR, "initialization of texture failed.");
        release_texture_imm(texture);
        return null;
    }

    // TODO: move initing data from the backend to here

    return texture;
}

release_texture_imm :: (texture:*Texture) {   
    backend_deinit_texture(texture);
    << texture = .{};
    // discard?
}

release_texture_wafc :: (texture:*Texture) {   
    Basic.array_add(*gs.release_lists[gs.active_frame], texture);
}


// Buffer ------------------------------------------

Buffer_Usage :: enum_flags u32 { 
    VERTEX_BUFFER   :: 1;  // read only
    INDEX_BUFFER    :: 2;  // read only
    CONSTANT_BUFFER :: 4;  // read only
    INDIRECT_BUFFER :: 8;  // read only
    UPLOAD_BUFFER   :: 16; // buffer with host write access
    // TODO
    // UNORDERED_ACCESS
} 

// NOTE: BIND_GROUP is base
Resource_Type :: enum u16 {
    UNKNOWN :: 0;
    BUFFER  :: 1;
    TEXTURE :: 2;
    // SAMPLER :: 3; // TODO
}

Resource :: struct {
    #as using base: Base;
    base.kind = .RESOURCE;
    resource_type: Resource_Type;
}

// create upload buffer and encoder per thread? or we just check the index of the encooder

    // by default allow this usage
    // COPY_SRC              :: 1 << 1;  // read only
    // COPY_DST              :: 1 << 2;  // write only (auto)

    // UNORDERED_ACCESS  :: 1 << 3;  // read/write (with buffer only or texture)

Buffer_Desc :: struct {
    usage   : Buffer_Usage;
    size    : u32;
}

Buffer :: struct {
    #as using resource: Resource;
    resource.resource_type = .BUFFER;
    desc: Buffer_Desc;
    mapped_ptr: *u8;
    using bk:Backend_Buffer;
}

create_buffer :: (buffer_desc:Buffer_Desc, buffer_data:*void = null) -> *Buffer {
    Basic.assert(buffer_desc.usage != 0);
    using buffer := DataStorage.get(*gs.bfr_storage, initialized=true);
    Basic.assert(buffer != null);
    desc = buffer_desc;

    if !backend_init_buffer(buffer) {
        report_debug_msg(.ERROR, "initialization of buffer failed.");
        release_buffer_imm(buffer);
        return null;
    }

    if buffer_data {
        if desc.usage & .UPLOAD_BUFFER { 
            // if upload buffer copy the initial data into the gpu now
            write_upload_buffer_data_imm(buffer, 0, buffer_data, desc.size);
        } else {
            // create temporary upload buffer
            ub_desc: Buffer_Desc;
            ub_desc.usage = .UPLOAD_BUFFER;
            ub_desc.size  = cast(u32) desc.size;
            upload_buffer := create_buffer(ub_desc);
            release_buffer_wafc(upload_buffer);
            // now copy the data to the temporary upload buffer
            write_upload_buffer_data_imm(upload_buffer, 0, buffer_data, desc.size);
            // add copy buffer command for copy the data from our upload buffer to the created buffer.
            copy_buffer(gs.staging_encoder, buffer, 0, upload_buffer, 0, desc.size);
        }       
    }

    return buffer;
}

release_buffer_imm :: (using buffer:*Buffer) {   
    inline backend_deinit_buffer(buffer);
    << buffer = .{};
}

release_buffer_wafc :: inline (buffer:*Buffer) {
    Basic.array_add(*gs.release_lists[gs.active_frame], buffer);
}

// TODO: rename this to write_buffer_data_imm
// This CPU method it will over write the buffer (gpu) memory immediately.
// to avoid changing data that meby in use by the GPU we only allow to overwrite same data once by FRAME count.
write_upload_buffer_data_imm :: (using dst_buffer:*Buffer, dst_offset:u32, data:*void, size:u32) {
    Basic.assert(mapped_ptr != null && data != null && desc.usage & .UPLOAD_BUFFER != 0);
    Basic.assert(dst_offset + size <= desc.size);
    memcpy(mapped_ptr+dst_offset, data, size);
}

// from simp
    // sRGB;
    // Cube;
    // Array;
    // Volume;
    // Buffer;
    // Render_Target;
    // Multisampled;
    // No_Skip_Mipmaps;
    // Display_Target;


	// struct TextureDesc
	// {
	// 	enum class Type
	// 	{
	// 		TEXTURE_1D,
	// 		TEXTURE_2D,
	// 		TEXTURE_3D,
	// 	} type = Type::TEXTURE_2D;
	// 	uint32_t width = 0;
	// 	uint32_t height = 0;
	// 	uint32_t depth = 0;
	// 	uint32_t array_size = 1;
	// 	uint32_t mip_levels = 1;
	// 	Format format = Format::UNKNOWN;
	// 	uint32_t sample_count = 1;
	// 	Usage usage = Usage::DEFAULT;
	// 	BindFlag bind_flags = BindFlag::NONE;
	// 	ResourceMiscFlag misc_flags = ResourceMiscFlag::NONE;
	// 	ClearValue clear = {};
	// 	ResourceState layout = ResourceState::SHADER_RESOURCE;
	// };

	// enum class Usage
	// {
	// 	DEFAULT,	// CPU no access, GPU read/write
	// 	UPLOAD,	    // CPU write, GPU read
	// 	READBACK,	// CPU read, GPU write
	// };

	// enum class ResourceState
	// {
	// 	// Common resource states:
	// 	.NONE = 0,						// invalid state (don't preserve contents) // vk has this
	// 	SHADER_RESOURCE = 1 << 0,			// shader resource, read only
	// 	SHADER_RESOURCE_COMPUTE = 1 << 1,	// shader resource, read only, non-pixel shader
	// 	UNORDERED_ACCESS = 1 << 2,			// shader resource, write enabled
	// 	COPY_SRC = 1 << 3,					// copy from
	// 	COPY_DST = 1 << 4,					// copy to

	// 	// Texture specific resource states:
	// 	RENDERTARGET = 1 << 5,				// render target, write enabled
	// 	DEPTHSTENCIL = 1 << 6,				// depth stencil, write enabled
	// 	DEPTHSTENCIL_READONLY = 1 << 7,		// depth stencil, read only
	// 	SHADING_RATE_SOURCE = 1 << 8,		// shading rate control per tile

	// 	// GPUBuffer specific resource states:
	// 	VERTEX_BUFFER = 1 << 9,				// vertex buffer, read only
	// 	INDEX_BUFFER = 1 << 10,				// index buffer, read only
	// 	CONSTANT_BUFFER = 1 << 11,			// constant buffer, read only
	// 	INDIRECT_ARGUMENT = 1 << 12,			// argument buffer to DrawIndirect() or DispatchIndirect()
	
    // 	RAYTRACING_ACCELERATION_STRUCTURE = 1 << 13, // acceleration structure storage or scratch
	// 	PREDICATION = 1 << 14				// storage for predication comparison value
	// };

	// enum class BindFlag
	// {
	// 	NONE = 0,
	// 	VERTEX_BUFFER = 1 << 0,
	// 	INDEX_BUFFER = 1 << 1,
	// 	CONSTANT_BUFFER = 1 << 2,
	// 	SHADER_RESOURCE = 1 << 3,
	// 	RENDER_TARGET = 1 << 4,
	// 	DEPTH_STENCIL = 1 << 5,
	// 	UNORDERED_ACCESS = 1 << 6,
	// 	SHADING_RATE = 1 << 7,
	// };

	// enum class ResourceMiscFlag
	// {
	// 	NONE = 0,
	// 	TEXTURECUBE = 1 << 0,
	// 	INDIRECT_ARGS = 1 << 1,
	// 	BUFFER_RAW = 1 << 2,
	// 	BUFFER_STRUCTURED = 1 << 3,
	// 	RAY_TRACING = 1 << 4,
	// 	PREDICATION = 1 << 5,
	// };

// D3D12_RESOURCE_DIMENSION :: enum s32 {
//     UNKNOWN   :: 0;
//     BUFFER    :: 1;
//     TEXTURE1D :: 2;
//     TEXTURE2D :: 3;
//     TEXTURE3D :: 4;
// }
// using VkImageType :: enum u32 {
//     VK_IMAGE_TYPE_1D :: 0;
//     VK_IMAGE_TYPE_2D :: 1;
//     VK_IMAGE_TYPE_3D :: 2;
// }

// D3D12_RESOURCE_FLAGS :: enum_flags u32 {
//     NONE                        :: 0x0;
//     ALLOW_RENDER_TARGET         :: 0x1;
//     ALLOW_DEPTH_STENCIL         :: 0x2;
//     ALLOW_UNORDERED_ACCESS      :: 0x4;
//     DENY_SHADER_RESOURCE        :: 0x8;  // will add this based on state?

//     ALLOW_CROSS_ADAPTER         :: 0x10;

//     ALLOW_SIMULTANEOUS_ACCESS   :: 0x20;
//     VIDEO_DECODE_REFERENCE_ONLY :: 0x40;
// }

// using VkImageLayout :: enum u32 {
//     VK_IMAGE_LAYOUT_.NONE :: 0; // D3D12 RP DISCARD  or discardresourec
//     VK_IMAGE_LAYOUT_GENERAL :: 1; // make this shader resource
//     VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL :: 2;
//     VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL :: 3;
//     VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL :: 4;
//     VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL :: 5;
//     VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL :: 6;
//     VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL :: 7;
//     VK_IMAGE_LAYOUT_PREINITIALIZED :: 8;

//     VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_STENCIL_ATTACHMENT_OPTIMAL :: 1000117000;
//     VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_STENCIL_READ_ONLY_OPTIMAL :: 1000117001;
//     VK_IMAGE_LAYOUT_PRESENT_SRC_KHR :: 1000001002;
//     VK_IMAGE_LAYOUT_SHARED_PRESENT_KHR :: 1000111000;
//     VK_IMAGE_LAYOUT_SHADING_RATE_OPTIMAL_NV :: 1000164003;
//     VK_IMAGE_LAYOUT_DEPTH_READ_ONLY_STENCIL_ATTACHMENT_OPTIMAL_KHR :: 1000117000;
//     VK_IMAGE_LAYOUT_DEPTH_ATTACHMENT_STENCIL_READ_ONLY_OPTIMAL_KHR :: 1000117001;
// }
// using VkAccessFlags :: enum_flags u32 {
//     VK_ACCESS_INDIRECT_COMMAND_READ_BIT :: 1;
//     VK_ACCESS_INDEX_READ_BIT :: 2;
//     VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT :: 4;
//     VK_ACCESS_UNIFORM_READ_BIT :: 8;
//     VK_ACCESS_INPUT_ATTACHMENT_READ_BIT :: 16;
//     VK_ACCESS_SHADER_READ_BIT :: 32;
//     VK_ACCESS_SHADER_WRITE_BIT :: 64;
//     VK_ACCESS_COLOR_ATTACHMENT_READ_BIT :: 128;
//     VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT :: 256;
//     VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT :: 512;
//     VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT :: 1024;
//     VK_ACCESS_TRANSFER_READ_BIT :: 2048;
//     VK_ACCESS_TRANSFER_WRITE_BIT :: 4096;
//     VK_ACCESS_HOST_READ_BIT :: 8192;
//     VK_ACCESS_HOST_WRITE_BIT :: 16384;
//     VK_ACCESS_MEMORY_READ_BIT :: 32768;
//     VK_ACCESS_MEMORY_WRITE_BIT :: 65536;
// }
// using VkBufferUsageFlags :: enum_flags u32 {
//     VK_BUFFER_USAGE_TRANSFER_SRC_BIT :: 1;
//     VK_BUFFER_USAGE_TRANSFER_DST_BIT :: 2;

//     VK_BUFFER_USAGE_UNIFORM_TEXEL_BUFFER_BIT :: 4;
//     VK_BUFFER_USAGE_STORAGE_TEXEL_BUFFER_BIT :: 8; // UAV
//     VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT :: 16;
//     VK_BUFFER_USAGE_STORAGE_BUFFER_BIT :: 32; // UAV
//     VK_BUFFER_USAGE_INDEX_BUFFER_BIT :: 64;
//     VK_BUFFER_USAGE_VERTEX_BUFFER_BIT :: 128;
//     VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT :: 256;
//     VK_BUFFER_USAGE_CONDITIONAL_RENDERING_BIT_EXT :: 512;
//     VK_BUFFER_USAGE_RAYTRACING_BIT_NVX :: 1024;
//     VK_BUFFER_USAGE_FLAG_BITS_MAX_ENUM :: 2147483647;
// }
// using VkImageUsageFlags :: enum_flags u32 {
//     VK_IMAGE_USAGE_TRANSFER_SRC_BIT :: 1;
//     VK_IMAGE_USAGE_TRANSFER_DST_BIT :: 2;
//     VK_IMAGE_USAGE_SAMPLED_BIT :: 4; // SHADER RES
//     VK_IMAGE_USAGE_STORAGE_BIT :: 8;      // UAV
//     VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT :: 16;
//     VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT :: 32;

//     VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT :: 64;
//     VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT :: 128;
//     VK_IMAGE_USAGE_SHADING_RATE_IMAGE_BIT_NV :: 256;
//     VK_IMAGE_USAGE_FLAG_BITS_MAX_ENUM :: 2147483647;
// }

//
// D3D12_RESOURCE_STATES :: enum s32 {
//     COMMON                            :: 0;

//     VERTEX_AND_CONSTANT_BUFFER        :: 1;
//     INDEX_BUFFER                      :: 2;

//     RENDER_TARGET                     :: 4; // auto
//     UNORDERED_ACCESS                  :: 8;
//     DEPTH_WRITE                       :: 16;
//     DEPTH_READ                        :: 32;
//     NON_PIXEL_SHADER_RESOURCE         :: 64;
//     PIXEL_SHADER_RESOURCE             :: 128;
//     STREAM_OUT                        :: 256;

//     INDIRECT_ARGUMENT                 :: 512;

//     COPY_DEST                         :: 1024;
//     COPY_SOURCE                       :: 2048;
//     RESOLVE_DEST                      :: 4096;
//     RESOLVE_SOURCE                    :: 8192;
//     RAYTRACING_ACCELERATION_STRUCTURE :: 4194304;
//     SHADING_RATE_SOURCE               :: 16777216;

//     GENERIC_READ                      :: 2755;
//     PRESENT                           :: 0;
//     PREDICATION                       :: 512;
// }

Bind_Group :: struct {
    #as using base: Base;
    base.kind = .BIND_GROUP;
    //elements: [] Resource_View_Desc; // REMOVE or add some thing better 
    resource_count : u32;
    using bk:Backend_Bind_Group;
}

create_bind_group :: (resource_count: u32) -> *Bind_Group {
    if resource_count == 0 return null;
    bind_group := DataStorage.get(*gs.bgr_storage, initialized=true);
    Basic.assert(bind_group != null);
    bind_group.resource_count  = resource_count;
    inline backend_init_bind_group(bind_group); // TODO: add error
    return bind_group;  
}

// TODO: use one proc like bind resource?
// @Speed meby we want to do not allow re bind with same offset???
bind_texture :: (bind_group:*Bind_Group, offset:u32, texture:*Texture) {
    inline backend_bind_texture(bind_group, offset, texture);   
}

bind_constant_buffer :: (bind_group:*Bind_Group, offset:u32, buffer:*Buffer) {
    inline backend_bind_constant_buffer(bind_group, offset, buffer);   
}


release_bind_group_imm :: (bind_group:*Bind_Group) {   
    inline backend_deinit_bind_group(bind_group);
    << bind_group = .{};
    // discard?
}

release_bind_group_wafc :: (bind_group:*Bind_Group) {   
    Basic.array_add(*gs.release_lists[gs.active_frame], bind_group);
}


Sampler_Desc :: struct { // -> D3D12_SAMPLER_DESC, D3D12_STATIC_SAMPLER_DESC
    filter:    Sampler_Filter = .MIN_MAG_MIP_POINT;
    address_u: Sampler_Address_Mode = .BORDER;
    address_v: Sampler_Address_Mode = .BORDER;
    address_w: Sampler_Address_Mode = .BORDER;
    mip_lod_bias: float;
    max_anisotropy: u32;
    compare_op: Compare_Op = .NEVER;
    min_lod:  float;
    max_lod:  float = 1000;
}

Sampler_Filter :: enum u16 { // we use same d3d (D3D12_FILTER) values 
    MIN_MAG_MIP_POINT               :: 0;
    MIN_MAG_POINT_MIP_LINEAR        :: 1;
    MIN_POINT_MAG_LINEAR_MIP_POINT  :: 4;
    MIN_POINT_MAG_MIP_LINEAR        :: 5;
    MIN_LINEAR_MAG_MIP_POINT        :: 16;
    MIN_LINEAR_MAG_POINT_MIP_LINEAR :: 17;
    MIN_MAG_LINEAR_MIP_POINT        :: 20;
    MIN_MAG_MIP_LINEAR              :: 21;
    ANISOTROPIC                     :: 85;
}

Sampler_Address_Mode :: enum u16 { // we use same vulkan values and value+1 d3d values of D3D12_TEXTURE_ADDRESS_MODE
    REPEAT  :: 0;
    MIRROR  :: 1;
    CLAMP   :: 2;
    BORDER  :: 3;
    MIRROR_ONCE :: 4;
}

// // TODO: REWRITE this proc
// create_resource_view_group :: (elements: [] Resource_View_Desc) -> *Bind_Group {
//     using g_resource_manager;
//     // first get heap values
//     heap_inc_size   := ID3D12Device_GetDescriptorHandleIncrementSize(gs.d3d_device, .CBV_SRV_UAV);
//     heap_cpu_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(gs.d3d_bgr_views_heap);
//     heap_cpu_handle.ptr += gs.d3d_bgr_views_heap_mark * heap_inc_size;
//     // we just save the offset
//     // heap_gpu_handle := ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart(gs.d3d_bgr_views_heap);
//     // heap_gpu_handle.ptr += gs.d3d_bgr_views_heap_mark * heap_inc_size;

//     Basic.assert(elements.count == 1 && elements[0].type == .SRV);

//     bind_group := DataStorage.get(*gs.bgr_storage, initialized=true); //
//     Basic.assert(bind_group != null);
//     bind_group.elements = elements;
//     bind_group.d3d_heap_offset = gs.d3d_bgr_views_heap_mark;

//     for elements {
//         Basic.assert(it.type != .INVALID);
//         tex := cast(*Texture) it.resource;
//         view_desc: D3D12_SHADER_RESOURCE_VIEW_DESC; // TEMP fill base on desc
//         view_desc.Format           = conv_texture_format(tex.desc.format);
//         view_desc.ViewDimension    = .TEXTURE2D;
//         view_desc.Shader4ComponentMapping = cast(u32) D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING();
//         view_desc.Texture2D.MipLevels     = 1; // @mipCount
//         // for now we do not pass the desc
//         ID3D12Device_CreateShaderResourceView(gs.d3d_device, tex.d3d_resource, null, heap_cpu_handle);
//         // inc the cursour
//         gs.d3d_bgr_views_heap_mark += 1;
//         heap_cpu_handle.ptr    += heap_inc_size;
//     }

//     // for elements {
//     //     Basic.assert(it.type != .INVALID);
//     //     // TODO: check usage, is multi? desc.usage & .CONSTANT_BUFFER
//     //     buffer := cast(*Buffer) it.resource;
//     //     view_desc: D3D12_CONSTANT_BUFFER_VIEW_DESC;
//     //     view_desc.BufferLocation = buffer.d3d_gpu_va;
//     //     view_desc.SizeInBytes    = buffer.desc.size;
//     //     ID3D12Device_CreateConstantBufferView(gs.d3d_device, *view_desc, heap_cpu_handle);
//     //     // inc the cursour
//     //     gs.d3d_bgr_views_heap_mark += 1;
//     //     heap_cpu_handle.ptr    += heap_inc_size;
//     // }

//     return bind_group;
// }