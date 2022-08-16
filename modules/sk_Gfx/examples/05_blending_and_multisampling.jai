Basic :: #import "Basic";
App   :: #import "sk_App"; 
Gfx   :: #import "sk_Gfx";
#import "d3d12"()(INCLUDE_DEBUG_BINDINGS=true); // just to set INCLUDE_DEBUG_BINDINGS

ENABLE_BLEND :bool: true;
SAMPLE_COUNT :u16 : 4; // try 1, 2, 4

g_window       :  App.Window;
g_swap_chain   : *Gfx.Swap_Chain;
g_pipeline     : *Gfx.Pipeline;
g_vertex_buffer: *Gfx.Buffer;

g_shader_vs    :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "VSMain", "vs_5_1");
g_shader_ps    :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "PSMain", "ps_5_1");

MY_VERTEX_LAYOUT :: Gfx.Vertex_Member_Info.[
    .{name = "POSITION", format = .FLOAT_X2}
];

my_vertices :: float.[
    // triangle 1 (left)
    -0.5,  0.5,
    -0.1, -0.5,
    -0.9, -0.5,
    // triangle 2 (right)
     0.5,  0.5,
     0.9, -0.5,
     0.1, -0.5,
    // triangle 3 (middle)
     0.0,   0.4,
     0.35, -0.6,
    -0.35, -0.6,
];

main :: () {
    App.enable_dpi_aware();
    // create window
    g_window = App.create_window(1024, 512, "Blending and Multisampling Example");
    // init the graphics
    Gfx.init();
    used_gpu := Gfx.get_selected_adapter_info();
    Basic.print("using adapter index:% , %\n", used_gpu.adapter_index, used_gpu.description);

    // create swap chain for our window
    {
        desc: Gfx.Swap_Chain_Desc;
        desc.width, desc.height = App.get_window_size(g_window);
        desc.native_window      = g_window;
        desc.format             = .RGBA8;
        desc.clear_color        = .[0.4, 0.4, 0.8, 1.0];
        desc.sample_count       = SAMPLE_COUNT; // set the sample count
        g_swap_chain            = Gfx.create_swap_chain(desc);
    }
    // create graphics pipeline
    {
        desc: Gfx.Pipeline_Desc;
        desc.vs_bytecode     = g_shader_vs;
        desc.ps_bytecode     = g_shader_ps;
        desc.rt_formats[0]   = g_swap_chain.desc.format;
        desc.vb_bindings[0].rate   = .PER_VERTEX;
        desc.vb_bindings[0].layout = MY_VERTEX_LAYOUT;
        // tell the pipeline we will push vector4 color in binding id 0.
        // NOTE: the final size will be equal to Basic.align_forward(size, 4);
        desc.rc_bindings[0].shader_visibilty = .ALL;
        desc.rc_bindings[0].shader_register  = 0;   // slot is the shader register id see register(b0) on the shader
        desc.rc_bindings[0].size  = size_of(float) * 4; // we will push the color RGBA
        // set blend enable state
        desc.bl_state.blend_enable       = ENABLE_BLEND;
        // set the sample count
        desc.sample_count                = SAMPLE_COUNT;

        g_pipeline           = Gfx.create_pipeline(desc);
    }

    // create vertex buffer
    {
        desc: Gfx.Buffer_Desc;
        desc.usage      = .VERTEX_BUFFER;
        desc.size       = size_of(float) * my_vertices.count;
        g_vertex_buffer = Gfx.create_buffer(desc, my_vertices.data);
    }

    // game loop
    while run_game_loop := true {
        // handle app events 
        e: App.Event;
        while App.next_event(*e) {
            if e.type == .WINDOW_CLOSED break run_game_loop;
        }

        // ...

        // start commands encoder
        encoder := Gfx.begin_commands(g_pipeline);
        {
            Gfx.set_viewport_from_swc_desc(encoder, g_swap_chain.desc);
            Gfx.set_scissor_rect_from_swc_desc (encoder, g_swap_chain.desc);
            targets: Gfx.Renderpass_Targets;
            targets.rt[0].load_op = .CLEAR;
            targets.rt[0].target  = Gfx.get_active_back_buffer(g_swap_chain);
            Gfx.begin_renderpass(encoder, targets);
            {   
                // bind our vertex buffer (at binding 0)
                Gfx.set_vertex_buffer(encoder, 0, g_vertex_buffer);
                // draw first triangle (left)
                color0 := float.[.1,.1,.9, 1.0];
                Gfx.push_constants(encoder, 0, color0.data);
                Gfx.draw(encoder, 3);
                // draw second triangle (right)
                color1 := float.[.1,.9,.1, 1.0];
                Gfx.push_constants(encoder, 0, color1.data);
                Gfx.draw(encoder, 3, first_vertex=3);
                // draw middle triangle 
                color2 := float.[.9,.1,.1, .5]; // use alpha 
                Gfx.push_constants(encoder, 0, color2.data);
                Gfx.draw(encoder, 3, first_vertex=6);
            }
            Gfx.end_renderpass(encoder);
        }
        Gfx.end_commands(encoder);
         
        // call this once per frame
        Gfx.execute();
    }

    // deinit and release all gpu resources
    Gfx.deinit();
}


// Shaders
//
SHADER_TEXT :: #string DONE
// our push constants data
cbuffer PushConstantsData: register(b0)
{
    float4 color;
};

struct VSInput
{
    float2 position : POSITION;
    // ...
};

struct PSInput
{
    float4 position : SV_POSITION;
    // ...
};

PSInput VSMain(VSInput IN)
{
    PSInput OUT;
    OUT.position = float4(IN.position, 0.0, 1.0);
    return OUT;
}

float4 PSMain(PSInput IN) : SV_TARGET
{
    return float4(color);
}
DONE;