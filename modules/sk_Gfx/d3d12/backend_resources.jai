#scope_module

Backend_Texture :: struct {
    d3d_resource  : *ID3D12Resource;
    d3d_default_usage_state: D3D12_RESOURCE_STATES;
    d3d_rtv_or_dsv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE;
    d3d_rtv_or_dsv_heap_offset: u32; // WARNING: this offset can be for rtv in swapchian rtv heap.
}

Backend_Buffer :: struct {
    d3d_resource:*ID3D12Resource;
    d3d_gpu_va  : D3D12_GPU_VIRTUAL_ADDRESS; // DO WE NEED THIS???? we can just use the function, ID3D12Resource_GetGPUVirtualAddress
    d3d_default_usage_state: D3D12_RESOURCE_STATES;
}

Backend_Bind_Group :: struct {
    d3d_heap_offset: u32;
}

backend_init_buffer :: (using buffer:*Buffer) -> bool {
    heap_properties: D3D12_HEAP_PROPERTIES;
    heap_properties.Type = .DEFAULT;
    if desc.usage & .UPLOAD_BUFFER then heap_properties.Type = .UPLOAD;
    heap_properties.CPUPageProperty      = .UNKNOWN;
    heap_properties.MemoryPoolPreference = .UNKNOWN;
    heap_properties.CreationNodeMask     = 0;
    heap_properties.VisibleNodeMask      = 0;
    // in d3d12 Constant buffers must be 256 byte aligned.
    if desc.usage & .CONSTANT_BUFFER then desc.size = cast(u32) Basic.align_forward(desc.size, 256);
    res: D3D12_RESOURCE_DESC;
    res.Dimension  = .BUFFER;
    res.Alignment  = 0;
    res.Width      = desc.size;
    res.Height     = 1;
    res.DepthOrArraySize = 1;
    res.MipLevels  = 1;
    res.Format     = .UNKNOWN;
    res.SampleDesc.Count = 1;
    res.Layout     = .ROW_MAJOR;
    res.Flags      = .NONE;

    if desc.usage & .VERTEX_BUFFER    then d3d_default_usage_state |= .VERTEX_AND_CONSTANT_BUFFER;
    if desc.usage & .CONSTANT_BUFFER  then d3d_default_usage_state |= .VERTEX_AND_CONSTANT_BUFFER;
    if desc.usage & .INDEX_BUFFER     then d3d_default_usage_state |= .INDEX_BUFFER;
    if desc.usage & .INDIRECT_BUFFER  then d3d_default_usage_state |= .INDIRECT_ARGUMENT;
    if desc.usage & .UPLOAD_BUFFER    then d3d_default_usage_state |= .GENERIC_READ; // GENERIC_READ must be used when heap_properties.Type = .UPLOAD

    // for now every buffer can be used as copy source. 
    d3d_default_usage_state |= .COPY_SOURCE; 

    initial_states := d3d_default_usage_state;
    // if this not has UPLOAD_BUFFER usage we shall start with .COPY_DEST state.
    // NOTE: COPY_DEST is write state can not combined with read states. anyway, after copy buffer
    // the buffer will return to the d3d_default_usage_state
    if desc.usage & .UPLOAD_BUFFER == 0 then initial_states = .COPY_DEST;

    // for now we just we will use CommittedResource
    result := ID3D12Device_CreateCommittedResource(gs.d3d_device, *heap_properties, .NONE, *res, initial_states, null, *Windows.uid(ID3D12Resource_UUID), xx *d3d_resource);
    if result != S_OK {
        report_debug_msg(.ERROR, "ID3D12Device_CreateCommittedResource failed (%).", result);
        return false;
    }

    d3d_gpu_va = ID3D12Resource_GetGPUVirtualAddress(d3d_resource);

    if desc.usage & .UPLOAD_BUFFER { 
        result = ID3D12Resource_Map(d3d_resource, 0, null, xx *mapped_ptr);
        if result != S_OK {
            report_debug_msg(.ERROR, "ID3D12Resource_Map failed (%).", result);
            return false;
        }
    } 
    return true;
}

backend_deinit_buffer :: inline (using buffer:*Buffer) {   
    if d3d_resource {
        if mapped_ptr ID3D12Resource_Unmap(d3d_resource, 0, null);
        Windows.IUnknown_Release(d3d_resource);
    }
}


// TODO: make sure the user use correct usages (ex can not be both RT and DS)
// TODO: replace data with [] u8? NAH ITHINK we shouuld keep it *void
backend_init_texture :: (using texture:*Texture, texture_data:*void) -> bool {
    heap_properties: D3D12_HEAP_PROPERTIES;
    heap_properties.Type                 = .DEFAULT;
    heap_properties.CPUPageProperty      = .UNKNOWN;
    heap_properties.MemoryPoolPreference = .UNKNOWN;
    heap_properties.CreationNodeMask     = 0;
    heap_properties.VisibleNodeMask      = 0;

    res: D3D12_RESOURCE_DESC;
    res.Dimension        = .TEXTURE2D;
    if desc.usage & .TEXTURE_1D then res.Dimension = .TEXTURE1D;
    if desc.usage & .TEXTURE_3D then res.Dimension = .TEXTURE3D;

    // Alignment may be one of 0, 4KB(4096), 64KB(65536) or 4MB(4194304).
    // If Alignment is set to 0, the runtime will use 4MB for MSAA textures and 64KB for everything else.
    res.Alignment        = 0;
    res.Width            = desc.width;
    res.Height           = desc.height;
    res.DepthOrArraySize = xx desc.array_layers;
    if desc.usage & .TEXTURE_3D then res.DepthOrArraySize = xx desc.depth;
    res.MipLevels        = desc.mip_levels;
    res.Format           = conv_texture_format(desc.format);
    res.SampleDesc.Count = desc.sample_count;
    // https://docs.microsoft.com/en-us/windows/win32/api/d3d12/ne-d3d12-d3d12_texture_layout
    res.Layout           = .UNKNOWN;

    Basic.assert(desc.usage != 0); // why !!!
    
    // flags
    clear_value: D3D12_CLEAR_VALUE;
    if !(desc.usage & .SHADER_RESOURCE || desc.usage & .PIXEL_SHADER_RESOURCE) && desc.usage & .DEPTH_STENCIL {
        // for optm
        res.Flags |= .DENY_SHADER_RESOURCE;
    }
    if desc.usage & .UNORDERED_ACCESS {
        res.Flags |= .ALLOW_UNORDERED_ACCESS;
    }
    if desc.usage & .RENDER_TARGET {
        res.Flags |= .ALLOW_RENDER_TARGET;
        clear_value.Format = res.Format;
        clear_value.Color  = desc.clear_value.color;
    }
    if desc.usage & .DEPTH_STENCIL {
        res.Flags |= .ALLOW_DEPTH_STENCIL;
        clear_value.Format = res.Format;
        clear_value.DepthStencil.Depth   = desc.clear_value.depth;
        clear_value.DepthStencil.Stencil = desc.clear_value.stencil;
    }

    // resource state
    if desc.usage & .SHADER_RESOURCE {
        d3d_default_usage_state |= .PIXEL_SHADER_RESOURCE;
        d3d_default_usage_state |= .NON_PIXEL_SHADER_RESOURCE;
    }
    if desc.usage & .PIXEL_SHADER_RESOURCE {
        d3d_default_usage_state |= .PIXEL_SHADER_RESOURCE;
    }

    // for now we do not allow the .RENDER_TARGET || DEPTH_STENCIL to be used as copy SRC
    // TODO: fix this, it is better to keep the RT and DS like this so we do not use barriers
    if d3d_default_usage_state != 0 
      then d3d_default_usage_state |= .COPY_SOURCE;

    if desc.usage & .RENDER_TARGET && d3d_default_usage_state == 0 {
        // must be single write state
        d3d_default_usage_state = .RENDER_TARGET;
    }
    if desc.usage & .DEPTH_STENCIL {
        if d3d_default_usage_state == 0 {
            d3d_default_usage_state = .DEPTH_WRITE;
        } else {
            d3d_default_usage_state = .DEPTH_READ;
        }
    }
    
    result: HRESULT;
    if desc.usage & .RENDER_TARGET || desc.usage & .DEPTH_STENCIL {
        result = ID3D12Device_CreateCommittedResource(gs.d3d_device, *heap_properties, .NONE, *res, d3d_default_usage_state, *clear_value, *Windows.uid(ID3D12Resource_UUID), xx *d3d_resource);
    } else {
        // TEMP
        result = ID3D12Device_CreateCommittedResource(gs.d3d_device, *heap_properties, .NONE, *res, .COPY_DEST, null, *Windows.uid(ID3D12Resource_UUID), xx *d3d_resource);
        //result = ID3D12Device_CreateCommittedResource(gs.d3d_device, *heap_properties, .NONE, *res, d3d_default_usage_state, null, *Windows.uid(ID3D12Resource_UUID), xx *d3d_resource);
    }
    if result != S_OK {
        report_debug_msg(.ERROR, "ID3D12Device_CreateCommittedResource failed: %", result);
        return false;
    }

    if desc.usage & .DEPTH_STENCIL {
        heap_inc_size      := ID3D12Device_GetDescriptorHandleIncrementSize(gs.d3d_device, .DSV);
        heap_cpu_handle    := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(gs.d3d_tex_dsv_heap);
        block_index, slot_index := DataStorage.locate(gs.tex_storage, texture);
        slot_location := (block_index * gs.tex_storage.max_count_per_block) + slot_index;
        heap_cpu_handle.ptr += slot_location * heap_inc_size;
        // now create the view
        ID3D12Device_CreateDepthStencilView(gs.d3d_device, d3d_resource, null, heap_cpu_handle);
        d3d_rtv_or_dsv_cpu_handle  = heap_cpu_handle;
        d3d_rtv_or_dsv_heap_offset = slot_location;
    }
    if desc.usage & .RENDER_TARGET {
        heap_inc_size      := ID3D12Device_GetDescriptorHandleIncrementSize(gs.d3d_device, .RTV);
        heap_cpu_handle    := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(gs.d3d_tex_rtv_heap);
        block_index, slot_index := DataStorage.locate(gs.tex_storage, texture);
        slot_location := (block_index * gs.tex_storage.max_count_per_block) + slot_index;
        heap_cpu_handle.ptr += slot_location * heap_inc_size;
        // now create the view
        ID3D12Device_CreateRenderTargetView(gs.d3d_device, d3d_resource, null, heap_cpu_handle);
        d3d_rtv_or_dsv_cpu_handle = heap_cpu_handle;
        d3d_rtv_or_dsv_heap_offset = slot_location;
    }
    {
        texture_upload_size: u64;
        // pResourceDesc: *D3D12_RESOURCE_DESC, FirstSubresource: u32, NumSubresources: u32, BaseOffset: u64, pLayouts: *D3D12_PLACED_SUBRESOURCE_FOOTPRINT, pNumRows: *u32, pRowSizeInBytes: *u64, pTotalBytes: *u64
        ID3D12Device_GetCopyableFootprints(gs.d3d_device, *res, 0, res.MipLevels, 0, null, null, null, *texture_upload_size);
        upload_size = cast(u32) texture_upload_size;
    }

    // TODO: move this outside the backend
    // SEE: https://docs.microsoft.com/en-us/windows/win32/direct3d12/subresources
    if texture_data {
        // Offset
        // D3D12_SUBRESOURCE_FOOTPRINT :: struct {
        //     Format:   DXGI_FORMAT;
        //     Width:    u32;
        //     Height:   u32;
        //     Depth:    u32;
        //     RowPitch: u32; (stride?)
        // }
        // upload size

// copy_texture :: (using encoder:*Encoder, dst:*Texture, dst_offset:u32, src:*Texture, src_offset:u32, size:u32) {

// }

// Texture_Subresource_Info :: struct {
//     []
// }

// get_texture_subresources_layout :: (texture:*Texture) -> [] Texture_Subresource_Info { // temproary

// }

// typedef struct VkImageSubresourceRange {
//     VkImageAspectFlags    aspectMask;
//     uint32_t              baseMipLevel;
//     uint32_t              levelCount;
//     uint32_t              baseArrayLayer;
//     uint32_t              layerCount;
// } VkImageSubresourceRange;

// we should make some thing like this
//input
    // VkImageAspectFlags    aspectMask;
    // uint32_t              mipLevel;
    // uint32_t              arrayLayer;
// output
//  typedef struct VkSubresourceLayout {
//     VkDeviceSize    offset;
//     VkDeviceSize    size;
//     VkDeviceSize    rowPitch;
//     VkDeviceSize    arrayPitch; // or layerpitch?
//     VkDeviceSize    depthPitch;
// } VkSubresourceLayout;

// or just like metal
// [blitCommandEncoder copyFromBuffer:_sourceBuffer
//                       sourceOffset:0
//                  sourceBytesPerRow:pixelSize*textureSize.width
//                sourceBytesPerImage:pixelSize*textureSize.width*textureSize.height
//                         sourceSize:textureSize
//                          toTexture:_privateTexture
//                   destinationSlice:0
//                   destinationLevel:0
//                  destinationOrigin:textureOrigin];

        fp: [16] D3D12_PLACED_SUBRESOURCE_FOOTPRINT;
        src_height : [16] u32; // num_rows (per slice)
        src_row_pitch : [16] u64; // src_row_pitch (per slice (stride))
        texture_upload_size: u64;

        // pResourceDesc: *D3D12_RESOURCE_DESC, FirstSubresource: u32, NumSubresources: u32, BaseOffset: u64, pLayouts: *D3D12_PLACED_SUBRESOURCE_FOOTPRINT, pNumRows: *u32, pRowSizeInBytes: *u64, pTotalBytes: *u64
        sub_resource_count := desc.array_layers * desc.mip_levels; // TODO: DEPTH STINCIL
        ID3D12Device_GetCopyableFootprints(gs.d3d_device, *res, 0, sub_resource_count, 0, fp.data, src_height.data, src_row_pitch.data, *texture_upload_size);
         Basic.print("fp:% \n src_height:% \n src_row_pitch:% \n texture_upload_size:%, size:%\n", fp, src_height, src_row_pitch, texture_upload_size, upload_size);
        // shall we move this otside of the backend???????
        ub_desc: Buffer_Desc;
        ub_desc.usage = .UPLOAD_BUFFER;
        ub_desc.size  = cast(u32) texture_upload_size;
        upload_buffer := create_buffer(ub_desc);
        release_buffer_wafc(upload_buffer);

        // copy each sub resource
        for subrss:0..sub_resource_count-1 {
            // Basic.print("% - %\n", fp[subrss], texture_upload_size);
            src_slice_offset := subrss * desc.depth * src_height[subrss] * src_row_pitch[subrss];
            dst_slice_offset := fp[subrss].Offset;
            dst_depth        := fp[subrss].Footprint.Depth;
            dst_height       := fp[subrss].Footprint.Height;
            dst_row_pitch    := fp[subrss].Footprint.RowPitch;
            for z:0..dst_depth-1 {
                src_layer_offset := z * src_height[subrss] * src_row_pitch[subrss];
                dst_layer_offset := z * dst_height * dst_row_pitch;
                // copy each row
                // @SpeedUp copy all the data into CPU? if we do that the app will use huge amount of memory
                // when many textures created same time. So for now we will copy by row.
                for y:0..dst_height-1 {
                    //Basic.print("z:% - y:%\n", z, y);
                    src_row_offset  := src_slice_offset + src_layer_offset + (y * src_row_pitch[subrss]);
                    dst_row_offset  := dst_slice_offset + dst_layer_offset + (y * dst_row_pitch);
                    //Basic.print("subresource:% - src_row_offset:% - dst_row_offset:%\n", subrss, src_row_offset, dst_row_offset);
                    write_upload_buffer_data_imm(upload_buffer, cast(u32) dst_row_offset, texture_data + src_row_offset, cast(u32) src_row_pitch[subrss]);          
                }
            }
            dst_loc: D3D12_TEXTURE_COPY_LOCATION;
            dst_loc.pResource        = d3d_resource;
            dst_loc.Type             = .SUBRESOURCE_INDEX;
            dst_loc.SubresourceIndex = subrss;
            
            src_loc: D3D12_TEXTURE_COPY_LOCATION;
            src_loc.pResource        = upload_buffer.d3d_resource;
            src_loc.Type             = .PLACED_FOOTPRINT;
            src_loc.PlacedFootprint  = fp[subrss];
            // pDst: *D3D12_TEXTURE_COPY_LOCATION, DstX: u32, DstY: u32, DstZ: u32, pSrc: *D3D12_TEXTURE_COPY_LOCATION, pSrcBox: *D3D12_BOX
            ID3D12GraphicsCommandList_CopyTextureRegion(gs.staging_encoder.d3d_command_list, *dst_loc, 0,0,0, *src_loc, null);

            // uint8_t* uploadStart = texUploadData + fp[mip].Offset;
            // uint8_t* sourceStart = pixelData     + imageDesc->mips[mip].offset;
            // uint32_t sourcePitch = (imageDesc->mips[mip].width * sizeof(uint32_t));
            // for ( uint32_t i = 0; i < fp[mip].Footprint.Height; i++ )
            // {
            //     memcpy (
            //         uploadStart + i * fp[mip].Footprint.RowPitch,
            //         sourceStart + i * sourcePitch,
            //         sourcePitch
            //     );
            // }
            // for ( uint32_t mip = 0; mip < imageDesc->mipCount; mip++ )
            // {
            //     preloaderCommandList->lpVtbl->CopyTextureRegion (
            //         preloaderCommandList,
            //         &(D3D12_TEXTURE_COPY_LOCATION){
            //             .pResource = texRes,
            //             .Type      = D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX,
            //             .SubresourceIndex = mip,
            //         },
            //         0,0,0,
            //         &(D3D12_TEXTURE_COPY_LOCATION){
            //             .pResource = texUploadRes,
            //             .Type      = D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT,
            //             .PlacedFootprint = fp[mip],
            //         },
            //         NULL
            //     );
            // }
        }

        barrier: D3D12_RESOURCE_BARRIER;
        barrier.Type                   = .TRANSITION;
        barrier.Flags                  = .NONE;
        barrier.Transition.pResource   = d3d_resource;
        barrier.Transition.StateBefore = .COPY_DEST;
        barrier.Transition.StateAfter  = d3d_default_usage_state;
        barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        sub_cmd_gpu_barrier(gs.staging_encoder, barrier, false); // we will flush on end
    }

    return true;
}

backend_deinit_texture :: inline (using texture:*Texture) {   
    if d3d_resource {
        Windows.IUnknown_Release(d3d_resource);
    }
}

backend_init_bind_group :: (bind_group:*Bind_Group) -> bool {
    if bind_group.resource_count == 0 return false;
    bind_group.d3d_heap_offset = gs.d3d_bgr_views_heap_mark;
    gs.d3d_bgr_views_heap_mark += bind_group.resource_count;
    Basic.assert(gs.d3d_bgr_views_heap_mark <= 1_000_000);
    return true;  
}

backend_deinit_bind_group :: (bind_group:*Bind_Group) #expand {
    // nothing for now, here Ihinck we shall recoord the empty slots for using them
}

backend_bind_texture :: (bind_group:*Bind_Group, offset:u32, texture:*Texture) {
    heap_inc_size   := ID3D12Device_GetDescriptorHandleIncrementSize(gs.d3d_device, .CBV_SRV_UAV);
    heap_cpu_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(gs.d3d_bgr_views_heap);
    heap_offset     := bind_group.d3d_heap_offset + offset;
    Basic.assert(heap_offset < bind_group.resource_count + offset); // make sure we stil within bind group range
    heap_cpu_handle.ptr += heap_offset * heap_inc_size; 
    // create the view
    Basic.assert(texture.desc.usage & .SHADER_RESOURCE != 0);
    ID3D12Device_CreateShaderResourceView(gs.d3d_device, texture.d3d_resource, null, heap_cpu_handle);    
}

backend_bind_constant_buffer :: (bind_group:*Bind_Group, offset:u32, buffer:*Buffer) {
    heap_inc_size   := ID3D12Device_GetDescriptorHandleIncrementSize(gs.d3d_device, .CBV_SRV_UAV);
    heap_cpu_handle := ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(gs.d3d_bgr_views_heap);
    heap_offset     := bind_group.d3d_heap_offset + offset;
    Basic.assert(heap_offset < bind_group.resource_count + offset); // make sure we stil within bind group range
    // heap_cpu_handle.ptr += heap_offset * heap_inc_size;
    // create the view
    Basic.assert(buffer.desc.usage & .CONSTANT_BUFFER != 0);
    view_desc : D3D12_CONSTANT_BUFFER_VIEW_DESC;
    view_desc.BufferLocation = buffer.d3d_gpu_va;
    view_desc.SizeInBytes    = buffer.desc.size;
    ID3D12Device_CreateConstantBufferView(gs.d3d_device, *view_desc, heap_cpu_handle);
}

// ---

conv_texture_format :: (format:Texture_Format) -> DXGI_FORMAT {
    if format == {
        case .UNKNOWN; return .UNKNOWN;
        case .R8;     return .R8_UNORM;
        case .RG8;    return .R8G8_UNORM;
        case .RGBA8;  return .R8G8B8A8_UNORM;
        case .D32F;   return .D32_FLOAT;
        // TODO: other formats
    }
    Basic.assert(false, "unsupported format"); // unsupported
    return .UNKNOWN;
}

conv_texture_format :: (format:DXGI_FORMAT) -> Texture_Format {
    if format == {
        case .UNKNOWN; return .UNKNOWN;
        case .R8_UNORM;        return .R8;
        case .R8G8_UNORM;      return .RG8;
        case .R8G8B8A8_UNORM;  return .RGBA8;
        case .D32_FLOAT;       return .D32F;
        // TODO: other formats
    }
    Basic.assert(false, "unsupported format"); // unsupported
    return .UNKNOWN;
}