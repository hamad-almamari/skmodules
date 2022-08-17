// ------------------------------------------
// pipeline

Pipeline_Desc :: struct { // -> D3D12_GRAPHICS_PIPELINE_STATE_DESC
    // shaders
    vs_bytecode         : [] u8;
    ps_bytecode         : [] u8;
    // pipeline layout (pipeline input)
    vb_bindings         : [PIP_MAX_VB_BINDINGS] Vertex_Buffer_Binding;
    rc_bindings         : [PIP_MAX_RC_BINDINGS] Root_Constants_Binding;
    bg_bindings         : [PIP_MAX_BG_BINDINGS] Bind_Group_Binding;
    static_samplers     : [PIP_MAX_STATIC_SAMPLERS] Static_Sampler;
    primitive_topology  : Primitive_Topology = .TRIANGLE_LIST;
    // renderpass (pipeline output)
    sample_count        : u16 = 1;
    rt_formats          : [PIP_MAX_SIMULTANEOUS_RT_COUNT] Texture_Format;
    ds_format           : Texture_Format; 
    // pipeline options
    bl_state            : Blend_State;
    ds_state            : Depth_Stencil_State;
    ra_state            : Rasterizer_State;
}

Pipeline :: struct {
    #as using base: Base;
    base.kind = .PIPELINE;
    desc                  : Pipeline_Desc;
    locator               := DataStorage.INVALID_LOCATOR;
    vertex_layout_stride  : [PIP_MAX_VB_BINDINGS] u32;

    using bk:Backend_Pipeline;
}

// TODO:
//     NumRenderTargets: u32;
//     RTVFormats: [8] DXGI_FORMAT; // here only we need the format. :)
//     DSVFormat: DXGI_FORMAT;
//     sample_count        : u16 = 1;                  // SampleDesc.Count // RenderPass
//     IBStripCutValue: D3D12_INDEX_BUFFER_STRIP_CUT_VALUE; // DISABLED
//     StreamOutput: D3D12_STREAM_OUTPUT_DESC;
//     NodeMask: u32;
//     CachedPSO: D3D12_CACHED_PIPELINE_STATE;
//     Flags: D3D12_PIPELINE_STATE_FLAGS;

// TODO: change shader_register type to s16 ??????

Shader_Register :: s16; // (if == -1 the binding will be ignored)

Shader_Visibilty :: enum u16 {
    IGNORED_BINDING :: 0; // the binding will be ignored
    ALL     :: 1;
    VERTEX  :: 2;
    PIXEL   :: 3;
}

Root_Constants_Binding :: struct {
    shader_visibilty: Shader_Visibilty;
    shader_register : Shader_Register = -1;          // BaseShaderRegister
    size: u32;          // size in byets
}

Bind_Group_Binding :: struct {
    shader_visibilty : Shader_Visibilty;
    layout: [] Bind_Group_Range_Info; // the array must be valid for whole pipeline life time.
}

Static_Sampler :: struct {
    shader_visibilty: Shader_Visibilty;
    shader_register : Shader_Register = -1;  // BaseShaderRegister
    using desc: Sampler_Desc;   
}

// add offset here???? but vulkan do not have offset!
Bind_Group_Range_Info :: struct {
    shader_register: Shader_Register = -1;    // BaseShaderRegister
    resource_type: Shader_Resource_Type;
    resource_count: u16 = 1;
}

Shader_Resource_Type :: enum u16 {
    INVALID         :: 0;
    CONSTANT_BUFFER :: 1; // KNOWN AS CBV
    TEXTURE         :: 2; // KNOWN AS SRV
}


// Pipeline:Primitive_Topology

Primitive_Topology :: enum u16 {
    TRIANGLE_LIST  :: 0;
    TRIANGLE_STRIP :: 1;
    POINT_LIST     :: 2;
    LINE_LIST      :: 3;                           
    LINE_STRIP     :: 4;                            
    // PATCH?
}

// Vertex Input Layout

Vertex_Buffer_Binding :: struct { // -> D3D12_INPUT_ELEMENT_DESC
    rate : enum u16 {
        PER_VERTEX   :: 0;
        PER_INSTANCE :: 1;
    };
    layout: [] Vertex_Member_Info;
}

Vertex_Member_Info :: struct { // -> D3D12_INPUT_ELEMENT_DESC
    name  : string;
    format: Vertex_Member_Format;
}

Vertex_Member_Format :: enum u16 {
    FLOAT     :: 0;
    FLOAT_X2  :: 1;
    FLOAT_X3  :: 2;
    FLOAT_X4  :: 3;
    FLOAT_2X2 :: 4;
    FLOAT_3X3 :: 5;
    FLOAT_4X4 :: 6;
}

// Blend

Blend_State :: struct {                             // -> D3D12_BLEND_DESC (NOTE: IndependentBlendEnable=false, AlphaToCoverageEnable in Multisample_Desc), D3D12_RENDER_TARGET_BLEND_DESC
    logic_op_enable : bool     = false;             // RenderTarget.LogicOpEnable (if this true blend_enable must be false)
    logic_op        : Logic_OP = .NOOP;             // RenderTarget.LogicOp
    // blend
    blend_enable    : bool = false;                  // RenderTarget.BlendEnable (if this true logic_op_enable must be false)
    // color
    src_color_blend_factor : Blend_Factor = .SRC_ALPHA;       // RenderTarget.SrcBlend
    dest_color_blend_factor: Blend_Factor = .INV_SRC_ALPHA;   // RenderTarget.DestBlend
    color_blend_op         : Blend_Op     = .ADD;             // RenderTarget.BlendOp
    // alpha
    src_alpha_blend_factor : Blend_Factor = .ONE;    // RenderTarget.SrcBlendAlpha
    dest_alpha_blend_factor: Blend_Factor = .ZERO;   // RenderTarget.DestBlendAlpha
    alpha_blend_op         : Blend_Op     = .ADD;    // RenderTarget.BlendOpAlpha
    // write mask
    color_write_mask       : Color_Component_Flags = .ALL; // RenderTarget.RenderTargetWriteMask
    // blend sample mask
    sample_mask            : u32 = 0xffffffff;
}

Logic_OP :: enum u16 {                               // -> D3D12_LOGIC_OP (same values)
    CLEAR         :: 0;
    SET           :: 1;
    COPY          :: 2;
    COPY_INVERTED :: 3;
    NOOP          :: 4;
    INVERT        :: 5;
    AND           :: 6;
    NAND          :: 7;
    OR            :: 8;
    NOR           :: 9;
    XOR           :: 10;
    EQUIV         :: 11;
    AND_REVERSE   :: 12;
    AND_INVERTED  :: 13;
    OR_REVERSE    :: 14;
    OR_INVERTED   :: 15;
}

Blend_Factor :: enum u16 {                          // -> D3D12_BLEND (same values)
    ZERO             :: 1;                          // ZERO             :: 1
    ONE              :: 2;                          // ONE              :: 2
    SRC_COLOR        :: 3;                          // SRC_COLOR        :: 3
    INV_SRC_COLOR    :: 4;                          // INV_SRC_COLOR    :: 4
    SRC_ALPHA        :: 5;                          // SRC_ALPHA        :: 5
    INV_SRC_ALPHA    :: 6;                          // INV_SRC_ALPHA    :: 6
    DEST_ALPHA       :: 7;                          // DEST_ALPHA       :: 7
    INV_DEST_ALPHA   :: 8;                          // INV_DEST_ALPHA   :: 8
    DEST_COLOR       :: 9;                          // DEST_COLOR       :: 9
    INV_DEST_COLOR   :: 10;                         // INV_DEST_COLOR   :: 10
    SRC_ALPHA_SAT    :: 11;                         // SRC_ALPHA_SAT    :: 11
    BLEND_FACTOR     :: 14;                         // BLEND_FACTOR     :: 14
    INV_BLEND_FACTOR :: 15;                         // INV_BLEND_FACTOR :: 15
    SRC1_COLOR       :: 16;                         // SRC1_COLOR       :: 16
    INV_SRC1_COLOR   :: 17;                         // INV_SRC1_COLOR   :: 17
    SRC1_ALPHA       :: 18;                         // SRC1_ALPHA       :: 18
    INV_SRC1_ALPHA   :: 19;                         // INV_SRC1_ALPHA   :: 19
}

Blend_Op :: enum u16 {                              // -> D3D12_BLEND_OP
    ADD          :: 0;                              // ADD :: 1
    SUBTRACT     :: 1;                              // SUBTRACT :: 2
    REV_SUBTRACT :: 2;                              // REV_SUBTRACT :: 3
    MIN          :: 3;                              // MIN :: 4
    MAX          :: 4;                              // MAX :: 5
}

Color_Component_Flags :: enum_flags u16 {           // -> D3D12_COLOR_WRITE_ENABLE
    RED   :: 1;                                     // RED :: 1
    GREEN :: 2;                                     // GREEN :: 2
    BLUE  :: 4;                                     // BLUE :: 4
    ALPHA :: 8;                                     // ALPHA :: 8
    ALL   :: 15;                                    // ALL :: 15
}

// DEPTH STENCIL ---

Depth_Stencil_State :: struct {              // -> D3D12_DEPTH_STENCIL_DESC
    depth_enable       : bool = false;      // DepthEnable
    depth_write_all    : bool = true;       // DepthWriteMask (true-> D3D12_DEPTH_WRITE_MASK.ALL, false-> D3D12_DEPTH_WRITE_MASK.ZERO)
    depth_compare_op   : Compare_Op = .LESS_EQUAL;// DepthFunc
    stencil_enable     : bool = false;      // StencilEnable
    
    stencil_front      : Stencil_Operators;   // FrontFace
    stencil_front.fail_op       = .KEEP;
    stencil_front.pass_op       = .KEEP;
    stencil_front.depth_fail_op = .INCR;
    stencil_front.compare_op    = .ALWAYS;

    stencil_back       : Stencil_Operators;   // BackFace
    stencil_back.fail_op       = .KEEP;
    stencil_back.pass_op       = .KEEP;
    stencil_back.depth_fail_op = .DECR;
    stencil_back.compare_op    = .ALWAYS;

    stencil_read_mask  : u8 = 0xff;         // StencilReadMask
    stencil_write_mask : u8 = 0xff;         // StencilWriteMask
}

Compare_Op :: enum u16 {                 // -> D3D12_COMPARISON_FUNC
    NEVER            :: 0;               // NEVER :: 1
    LESS             :: 1;               // LESS :: 2
    EQUAL            :: 2;               // EQUAL :: 3
    LESS_EQUAL       :: 3;               // LESS_EQUAL :: 4
    GREATER          :: 4;               // GREATER :: 5
    NOT_EQUAL        :: 5;               // NOT_EQUAL :: 6
    GREATER_EQUAL    :: 6;               // GREATER_EQUAL :: 7
    ALWAYS           :: 7;               // ALWAYS :: 8
}

Stencil_Op :: enum u16 {                 // -> D3D12_STENCIL_OP
    KEEP             :: 0;               // KEEP :: 1
    ZERO             :: 1;               // ZERO :: 2
    REPLACE          :: 2;               // REPLACE :: 3
    INCR_SAT         :: 3;               // INCR_SAT :: 4  (INCREMENT AND CLAMP)
    DECR_SAT         :: 4;               // DECR_SAT :: 5  (DECREMENT AND CLAMP)
    INVERT           :: 5;               // INVERT :: 6
    INCR             :: 6;               // INCR :: 7 (INCREMENT AND WRAP)
    DECR             :: 7;               // DECR :: 8 (DECREMENT AND WRAP)
}

Stencil_Operators :: struct {  // -> D3D12_DEPTH_STENCILOP_DESC
    fail_op      : Stencil_Op = .KEEP;  // StencilFailOp
    pass_op      : Stencil_Op = .KEEP;  // StencilPassOp
    depth_fail_op: Stencil_Op = .KEEP;  // StencilDepthFailOp
    compare_op   : Compare_Op = .ALWAYS;// StencilFunc
}


Rasterizer_State :: struct { // -> D3D12_RASTERIZER_DESC
    fill_mode: Fill_Mode = .SOLID;
    cull_mode: Cull_Mode = .BACK;
    front_counter_clockwise: bool;
    depth_clip_enable: bool;
    // ... TODO
}

Fill_Mode :: enum u16 { // -> D3D12_FILL_MODE
    SOLID :: 0;           // SOLID     :: 3;
    WIREFRAME :: 1;       // WIREFRAME :: 2;
}

Cull_Mode :: enum u16 { // -> D3D12_CULL_MODE
    BACK  :: 0;         // BACK  :: 3;
    FRONT :: 1;         // FRONT :: 2;
}


create_pipeline :: (desc:Pipeline_Desc) -> *Pipeline {
    #if DEBUG {
        // TODO; checks
    }
    pipeline, slocator := DataStorage.get(*gs.pip_storage, initialized=true);
    if pipeline == null {
        report_debug_msg(.ERROR, "failed, swap chain storage is full: %.", gs.pip_storage.count);
        return null;
    }
    pipeline.desc    = desc;
    pipeline.locator = slocator;
    if !backend_init_pipeline(pipeline) {
        report_debug_msg(.ERROR, "initialization of pipeline failed.");
        release_pipeline_imm(pipeline);
        return null;
    }

    return pipeline;
}

release_pipeline_imm :: (pipeline:*Pipeline) {
    // release the pipeline immediately
    backend_deinit_pipeline(pipeline);
    << pipeline = .{};
    DataStorage.discard(*gs.pip_storage, pipeline);
}