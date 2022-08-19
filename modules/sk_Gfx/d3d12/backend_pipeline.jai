#scope_module

Backend_Pipeline :: struct {
    d3d_pipeline_state    : *ID3D12PipelineState;
    d3d_primitive_topology: D3D_PRIMITIVE_TOPOLOGY;
    d3d_root_signature    : *ID3D12RootSignature;

    d3d_rc_parameter_index: [PIP_MAX_RC_BINDINGS] s16;
    d3d_bg_parameter_index: [PIP_MAX_BG_BINDINGS] s16;

    constants_binding_count: u16;
}

// TODO COPY Array views to the desc?
backend_init_pipeline :: (using pipeline:*Pipeline) -> bool {
    pullGs();
    // Create an empty root signature.
    // NOTE: see https://alain.xyz/blog/raw-directx12 if you want to use Root Signature Version 1.

    //--------------------------------------------------
    PACOUNT :: PIP_MAX_RC_BINDINGS + PIP_MAX_BG_BINDINGS;
    parameters: [PACOUNT] D3D12_ROOT_PARAMETER;
    parameter_count : u16 = 0;
    // root constants == 32BIT_CONSTANTS
    for *desc.rc_bindings {
        using it;
        if shader_visibilty == .IGNORED_BINDING || shader_register < 0 || size == 0 {
            d3d_rc_parameter_index[it_index] = -1;
            continue;
        }
        if size == 0 {
            report_debug_msg(.WARNING, "The size of root constants binding [index=%] is 0, it will be ignored.", it_index);
            d3d_rc_parameter_index[it_index] = -1;
            continue;
        }
        size = cast(u32) Basic.align_forward(size, 4);
        parameters[parameter_count].ParameterType            = ._32BIT_CONSTANTS;
        parameters[parameter_count].Constants.ShaderRegister = cast(u32) shader_register; 
        parameters[parameter_count].Constants.RegisterSpace  = 0; 
        parameters[parameter_count].Constants.Num32BitValues = size/4; 
        parameters[parameter_count].ShaderVisibility         = conv_shader_visibilty(shader_visibilty); 
        d3d_rc_parameter_index[it_index] = cast,no_check(s16) parameter_count;
        parameter_count += 1;
    }

    // bind group binding = DESCRIPTOR_TABLE
    for binding: desc.bg_bindings {
        using binding;
        if shader_visibilty == .IGNORED_BINDING {
            d3d_bg_parameter_index[it_index] = -1;
            continue;
        }
        if !layout.count {
            report_debug_msg(.WARNING, "The unknown layout of bind group binding [index=%], it will be ignored.", it_index);
            d3d_bg_parameter_index[it_index] = -1;
            continue;
        }
        ranges := Basic.NewArray(layout.count, D3D12_DESCRIPTOR_RANGE, allocator=Basic.temp);
        offset_in_bg: u32 = 0; // offset in descriptors (within DESCRIPTOR_TABLE)
        for i:0..ranges.count-1 {
            if #complete layout[i].resource_type == {
                case .INVALID; Basic.assert(false);// TODO: ignore
                case .CONSTANT_BUFFER; ranges[i].RangeType = .CBV;
                case .TEXTURE;         ranges[i].RangeType = .SRV;
            }
            ranges[i].NumDescriptors     = layout[i].resource_count; // count of the resources in the range
            // TODO: check if the shader_register is used by root constants
            ranges[i].BaseShaderRegister = cast(u32) layout[i].shader_register; // need ERROR check
            ranges[i].RegisterSpace      = 0;
            ranges[i].OffsetInDescriptorsFromTableStart = offset_in_bg;
            offset_in_bg += ranges[i].NumDescriptors;
        }
        parameters[parameter_count].ParameterType   = .DESCRIPTOR_TABLE;
        parameters[parameter_count].DescriptorTable.NumDescriptorRanges = cast(u32) ranges.count;
        parameters[parameter_count].DescriptorTable.pDescriptorRanges   = ranges.data;
        parameters[parameter_count].ShaderVisibility = conv_shader_visibilty(shader_visibilty);
        d3d_bg_parameter_index[it_index] = cast,no_check(s16) parameter_count;
        parameter_count += 1;
    }

    // parameter_count := 0;
    // for desc.rc_bindings {
    //     if !it.size break;
    //     parameter_count += 1;
    //     constants_binding_count += 1;
    // }
    // for desc.bg_bindings {
    //     if !it.layout.count break;
    //     parameter_count += 1;
    // }

    // parameters := fp_NewArray(parameter_count, D3D12_ROOT_PARAMETER);
    // parms_offset := 0;
    // for *desc.rc_bindings {
    //     if !it.size break;
    //     it.size        = cast(u32) Basic.align_forward(it.size, 4);
    //     parameters[parms_offset].ParameterType            = ._32BIT_CONSTANTS;
    //     parameters[parms_offset].Constants.ShaderRegister = cast(u32) it.shader_register; 
    //     parameters[parms_offset].Constants.RegisterSpace  = 0; 
    //     parameters[parms_offset].Constants.Num32BitValues = it.size/4; 
    //     parameters[parms_offset].ShaderVisibility         = conv_shader_visibilty(it.shader_visibilty); 
    //     parms_offset += 1;
    // }

    // for binding: desc.bg_bindings {
    //     if !binding.layout.count break;
    //     ranges := fp_NewArray(binding.layout.count, D3D12_DESCRIPTOR_RANGE);
    //     offset_in_descriptors: u32 = 0;
    //     for i:0..ranges.count-1 {
    //         // TODO assert for view type
    //         ranges[i].RangeType          = .SRV; // TEMP-----------------------------
    //         ranges[i].NumDescriptors     = binding.layout[i].count;
    //         ranges[i].BaseShaderRegister = cast(u32) binding.layout[i].shader_register;
    //         ranges[i].RegisterSpace      = 0;
    //         ranges[i].OffsetInDescriptorsFromTableStart = offset_in_descriptors;
    //         offset_in_descriptors += ranges[i].NumDescriptors;
    //     }
    //     parameters[parms_offset].ParameterType   = .DESCRIPTOR_TABLE;
    //     parameters[parms_offset].DescriptorTable.NumDescriptorRanges = cast(u32) ranges.count;
    //     parameters[parms_offset].DescriptorTable.pDescriptorRanges   = ranges.data;
    //     parameters[parms_offset].ShaderVisibility = conv_shader_visibilty(binding.shader_visibilty);
    //     parms_offset += 1;
    // }

    // root_parameters: [3] D3D12_ROOT_PARAMETER;
    // root_parameters[0] = parameters[0];

    // // this only for buffers
    // // put the most frequently updated ones in the root
    // root_parameters[1].ParameterType    = .CBV;
    // root_parameters[1].Descriptor       = .{1, 0}; // ShaderRegister, RegisterSpace
    // root_parameters[1].ShaderVisibility = .ALL;

    // range: D3D12_DESCRIPTOR_RANGE;
    // range.RangeType          = .CBV;
    // range.NumDescriptors     = 1;
    // range.BaseShaderRegister = 2;
    // range.RegisterSpace      = 0;
    // range.OffsetInDescriptorsFromTableStart = 0;

    // root_parameters[2].ParameterType    = .DESCRIPTOR_TABLE;
    // root_parameters[2].DescriptorTable.NumDescriptorRanges = 1;
    // root_parameters[2].DescriptorTable.pDescriptorRanges   = *range;
    // root_parameters[2].ShaderVisibility = .ALL;

    // range: D3D12_DESCRIPTOR_RANGE;
    // range.RangeType          = .SRV;
    // range.NumDescriptors     = 1;
    // range.BaseShaderRegister = 0;
    // range.RegisterSpace      = 0;
    // range.OffsetInDescriptorsFromTableStart = 0;

    // root_parameters[2].ParameterType    = .DESCRIPTOR_TABLE;
    // root_parameters[2].DescriptorTable.NumDescriptorRanges = 1;
    // root_parameters[2].DescriptorTable.pDescriptorRanges   = *range;
    // root_parameters[2].ShaderVisibility = .ALL;
//---------------------------------------------------

    samplers:[PIP_MAX_STATIC_SAMPLERS] D3D12_STATIC_SAMPLER_DESC;
    samplers_count :u32= 0; 
    for desc.static_samplers {
        using it;
        if shader_visibilty == .IGNORED_BINDING || shader_register < 0 then continue;
        samplers[samplers_count].Filter         = cast(D3D12_FILTER) filter;
        samplers[samplers_count].AddressU       = cast(D3D12_TEXTURE_ADDRESS_MODE) (1 + address_u);
        samplers[samplers_count].AddressV       = cast(D3D12_TEXTURE_ADDRESS_MODE) (1 + address_v);
        samplers[samplers_count].AddressW       = cast(D3D12_TEXTURE_ADDRESS_MODE) (1 + address_w);
        samplers[samplers_count].MipLODBias     = mip_lod_bias;
        samplers[samplers_count].MaxAnisotropy  = max_anisotropy;
        samplers[samplers_count].ComparisonFunc = cast(D3D12_COMPARISON_FUNC) (1 + compare_op);
        samplers[samplers_count].MinLOD         = min_lod;
        samplers[samplers_count].MaxLOD         = max_lod; //D3D12_FLOAT32_MAX;
        // other
        samplers[samplers_count].BorderColor      = .TRANSPARENT_BLACK;
        samplers[samplers_count].ShaderRegister   = cast(u32) shader_register;
        samplers[samplers_count].RegisterSpace    = 0;
        samplers[samplers_count].ShaderVisibility = conv_shader_visibilty(shader_visibilty); 
        samplers_count += 1;
    }

    root_signature_desc: D3D12_ROOT_SIGNATURE_DESC;
    root_signature_desc.NumParameters     = parameter_count;
    root_signature_desc.pParameters       = ifx parameter_count then parameters.data else null;
    root_signature_desc.NumStaticSamplers = samplers_count;
    root_signature_desc.pStaticSamplers   = ifx samplers_count then samplers.data else null;
    root_signature_desc.Flags = .D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;

    signature: *ID3DBlob; // should we save this and reuse it?
    error: *ID3DBlob;
    result := D3D12SerializeRootSignature(*root_signature_desc, .D3D_ROOT_SIGNATURE_VERSION_1,  *signature, *error);
    if result != S_OK {
        report_debug_msg(.ERROR, "D3D12SerializeRootSignature failed (%).", result);
        return false;
    }
    result = ID3D12Device_CreateRootSignature(gs.d3d_device, 0,
     ID3D10Blob_GetBufferPointer(signature),
     ID3D10Blob_GetBufferSize(signature), 
     *Windows.uid(ID3D12RootSignature_UUID), xx *d3d_root_signature);

    if result != S_OK {
        report_debug_msg(.ERROR, "ID3D12Device_CreateRootSignature failed (%).", result);
        return false;
    }

    // Create pipeline state
    de: D3D12_GRAPHICS_PIPELINE_STATE_DESC;
    // RootSignature (pipeline layout)
    de.pRootSignature = d3d_root_signature;

    // Vertex Shader
    de.VS.pShaderBytecode = desc.vs_bytecode.data;
    de.VS.BytecodeLength  = xx desc.vs_bytecode.count;
    // Pixel Shader
    de.PS.pShaderBytecode = desc.ps_bytecode.data;
    de.PS.BytecodeLength  = xx desc.ps_bytecode.count;
    
    // Vertex input layout
    input_element_count := 0;
    for binding, slot: desc.vb_bindings {
        if !binding.layout.count break;
        input_element_count += binding.layout.count;
    }

    input_elements := Basic.NewArray(input_element_count, D3D12_INPUT_ELEMENT_DESC, allocator=Basic.temp);
    i := -1;
    for binding, slot: desc.vb_bindings {
        if !binding.layout.count break;
        class: D3D12_INPUT_CLASSIFICATION;
        if #complete binding.rate == {
            case .PER_VERTEX;   class = .PER_VERTEX_DATA;
            case .PER_INSTANCE; class = .PER_INSTANCE_DATA;
        }
        offset : u32 = 0;
        for binding.layout {
            i += 1;
            input_elements[i].SemanticName      = it.name.data;
            input_elements[i].SemanticIndex     = 0;
            input_elements[i].AlignedByteOffset = offset;
            eformat: DXGI_FORMAT;
            if it.format == {
                //case .FLOAT;    f = .R32_FLOAT; ??
                case .FLOAT_X2; 
                    eformat = .R32G32_FLOAT;
                    offset += 8;
                case .FLOAT_X3;
                    eformat = .R32G32B32_FLOAT;
                    offset += 12;
                case .FLOAT_X4;
                    eformat = .R32G32B32A32_FLOAT;
                    offset += 16;
                case; Basic.assert(false);
            }
            input_elements[i].Format               = eformat;
            input_elements[i].InputSlot            = cast(u32) slot;
            input_elements[i].InputSlotClass       = class;
            if #complete binding.rate == {
                case .PER_VERTEX;   input_elements[i].InstanceDataStepRate = 0;
                case .PER_INSTANCE; input_elements[i].InstanceDataStepRate = 1;
            }
        }
        vertex_layout_stride[slot] = offset;
    }

    de.InputLayout.NumElements        = xx input_elements.count;
    de.InputLayout.pInputElementDescs = input_elements.data;

    // Primitive Topology 
    if #complete desc.primitive_topology == {
    case .TRIANGLE_LIST;  
        d3d_primitive_topology = .TRIANGLELIST;
        de.PrimitiveTopologyType = .TRIANGLE;
    case .TRIANGLE_STRIP;
        d3d_primitive_topology = .TRIANGLESTRIP;
        de.PrimitiveTopologyType = .TRIANGLE;
    case .POINT_LIST;
        d3d_primitive_topology = .POINTLIST;
        de.PrimitiveTopologyType = .POINT;
    case .LINE_LIST;
        d3d_primitive_topology = .LINELIST;
        de.PrimitiveTopologyType =.LINE;                           
    case .LINE_STRIP;
        d3d_primitive_topology = .LINESTRIP; 
        de.PrimitiveTopologyType = .LINE; 
    }
    de.IBStripCutValue       = .DISABLED;

    // Blend State
    // Specifies whether to use alpha-to-coverage as a multisampling technique when setting a pixel to a render target.
    // SEE: https://docs.microsoft.com/en-us/windows/win32/direct3d11/d3d10-graphics-programming-guide-blend-state#alpha-to-coverage
    de.BlendState.AlphaToCoverageEnable  = .FALSE;
    de.BlendState.IndependentBlendEnable = .FALSE;
     {
        i := 0;
        using desc.bl_state;
        de.BlendState.RenderTarget[i].LogicOpEnable  = ifx logic_op_enable then BOOL.TRUE else BOOL.FALSE;
        de.BlendState.RenderTarget[i].LogicOp        = cast(D3D12_LOGIC_OP) logic_op;
        de.BlendState.RenderTarget[i].BlendEnable    = ifx blend_enable then BOOL.TRUE else BOOL.FALSE;
        de.BlendState.RenderTarget[i].SrcBlend       = cast(D3D12_BLEND) src_color_blend_factor;
        de.BlendState.RenderTarget[i].DestBlend      = cast(D3D12_BLEND) dest_color_blend_factor;
        de.BlendState.RenderTarget[i].BlendOp        = cast(D3D12_BLEND_OP) (1 + color_blend_op);
        de.BlendState.RenderTarget[i].SrcBlendAlpha  = cast(D3D12_BLEND) src_alpha_blend_factor;
        de.BlendState.RenderTarget[i].DestBlendAlpha = cast(D3D12_BLEND) dest_alpha_blend_factor;
        de.BlendState.RenderTarget[i].BlendOpAlpha   = cast(D3D12_BLEND_OP) (1 + color_blend_op);
        de.BlendState.RenderTarget[i].RenderTargetWriteMask = cast(u8) color_write_mask; 
        de.SampleMask = sample_mask; 
    }

    // Rasterizer State
    {
        using desc.ra_state;
        if #complete fill_mode == {
            case .SOLID; de.RasterizerState.FillMode = .SOLID;
            case .WIREFRAME; de.RasterizerState.FillMode = .WIREFRAME;
        }
        if #complete cull_mode == {
            case .BACK; de.RasterizerState.CullMode = .BACK;
            case .FRONT; de.RasterizerState.CullMode = .FRONT;
        }
        de.RasterizerState.FrontCounterClockwise = ifx front_counter_clockwise then BOOL.TRUE else BOOL.FALSE;;
        de.RasterizerState.DepthClipEnable       = ifx depth_clip_enable then BOOL.TRUE else BOOL.FALSE; // clip z (do not show far or near objects)
        de.RasterizerState.DepthBias             = D3D12_DEFAULT_DEPTH_BIAS;
        de.RasterizerState.DepthBiasClamp        = D3D12_DEFAULT_DEPTH_BIAS_CLAMP;
        de.RasterizerState.SlopeScaledDepthBias  = D3D12_DEFAULT_SLOPE_SCALED_DEPTH_BIAS;
        de.RasterizerState.AntialiasedLineEnable = .FALSE;
        de.RasterizerState.MultisampleEnable     = .FALSE; // @Multisample related?
    }


    // Depth Stencil State
    {
        // Depth Stencil State
        using desc.ds_state;
        // depth
        de.DepthStencilState.DepthEnable    = ifx depth_enable then BOOL.TRUE else BOOL.FALSE;
        de.DepthStencilState.DepthWriteMask = ifx depth_write_all then D3D12_DEPTH_WRITE_MASK.ALL else D3D12_DEPTH_WRITE_MASK.ZERO;
        de.DepthStencilState.DepthFunc      = cast(D3D12_COMPARISON_FUNC) (1 + depth_compare_op);
        // stencil
        de.DepthStencilState.StencilEnable  = ifx stencil_enable then BOOL.TRUE else BOOL.FALSE;;
        de.DepthStencilState.FrontFace.StencilFailOp      = cast(D3D12_STENCIL_OP) (1 + stencil_front.fail_op);
        de.DepthStencilState.FrontFace.StencilPassOp      = cast(D3D12_STENCIL_OP) (1 + stencil_front.pass_op);
        de.DepthStencilState.FrontFace.StencilDepthFailOp = cast(D3D12_STENCIL_OP) (1 + stencil_front.depth_fail_op);
        de.DepthStencilState.FrontFace.StencilFunc        = cast(D3D12_COMPARISON_FUNC) (1 + stencil_front.compare_op);
        de.DepthStencilState.BackFace.StencilFailOp       = cast(D3D12_STENCIL_OP) (1 + stencil_back.fail_op);
        de.DepthStencilState.BackFace.StencilPassOp       = cast(D3D12_STENCIL_OP) (1 + stencil_back.pass_op);
        de.DepthStencilState.BackFace.StencilDepthFailOp  = cast(D3D12_STENCIL_OP) (1 + stencil_back.depth_fail_op);
        de.DepthStencilState.BackFace.StencilFunc         = cast(D3D12_COMPARISON_FUNC) (1 + stencil_back.compare_op);
        de.DepthStencilState.StencilReadMask              = stencil_read_mask; 
        de.DepthStencilState.StencilWriteMask             = stencil_write_mask;
    }
    
    // RenderPass
    {
        de.SampleDesc.Count   = desc.sample_count; // TODO: CHECK > 1
        de.SampleDesc.Quality = 0;
        formats: [8] DXGI_FORMAT;
        formats_count: u32 = 0;
        for desc.rt_formats {
            if it == .UNKNOWN break; // we break on first .UNKNOWN format
            formats_count += 1;
            formats[it_index] = conv_texture_format(it);
        }
        de.NumRenderTargets   = formats_count;
        de.RTVFormats         = formats;
        de.DSVFormat          = conv_texture_format(desc.ds_format);
    }

    result = ID3D12Device_CreateGraphicsPipelineState(gs.d3d_device, *de, *Windows.uid(ID3D12PipelineState_UUID), xx *d3d_pipeline_state);
    if result != S_OK {
        report_debug_msg(.ERROR, "ID3D12Device_CreateGraphicsPipelineState failed (%).", result);
        return false;
    }

    return true;
}

backend_deinit_pipeline :: (using pipeline:*Pipeline) {
    // TODO: check this
    if d3d_pipeline_state then Windows.IUnknown_Release(d3d_pipeline_state);
    if d3d_root_signature then Windows.IUnknown_Release(d3d_root_signature);
}

conv_shader_visibilty :: (ss:Shader_Visibilty) -> D3D12_SHADER_VISIBILITY {
    if ss == {
        case .ALL; return .ALL;
        case .VERTEX; return .VERTEX;
        case .PIXEL; return .PIXEL;
    }
    Basic.assert(false, "TODO");
    return .ALL;
}