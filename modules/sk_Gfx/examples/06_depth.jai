Basic :: #import "Basic";
App   :: #import "sk_App"; 
Gfx   :: #import "sk_Gfx";
#import "d3d12"()(INCLUDE_DEBUG_BINDINGS=true); // just to set INCLUDE_DEBUG_BINDINGS

ENABLE_DEPTH_TEST :bool: true;

g_window       :  App.Window;
g_swap_chain   : *Gfx.Swap_Chain;
g_depth_targets: [Gfx.FRAME_COUNT] *Gfx.Texture; // depth targets for each render frame
g_pipeline     : *Gfx.Pipeline;
g_vertex_buffer: *Gfx.Buffer;

g_shader_vs    :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "VSMain", "vs_5_1");
g_shader_ps    :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "PSMain", "ps_5_1");

MY_VERTEX_LAYOUT :: Gfx.Vertex_Member_Info.[
    .{name = "POSITION", format = .FLOAT_X3} // x, y, z
];
// z 1: far, z:0 near
my_vertices :: float.[
    // x,  y,  z
    // triangle 1 (left)
    -0.5,  0.5, 0.0,
    -0.1, -0.5, 0.0,
    -0.9, -0.5, 0.0,
    // triangle 2 (right)
     0.5,  0.5, 0.0,
     0.9, -0.5, 0.0,
     0.1, -0.5, 0.0,
    // triangle 3 (middle)
     0.0,   0.4, 1.0,
     0.35, -0.6, 1.0,
    -0.35, -0.6, 1.0,
];

main :: () {
    App.enable_dpi_aware();
    // create window
    g_window = App.create_window(1024, 512, "Depth Test Example");
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
        g_swap_chain            = Gfx.create_swap_chain(desc);
    }

    // create depth targets (depth texture)
    #if ENABLE_DEPTH_TEST {
        for i:0..g_depth_targets.count-1 {
            desc: Gfx.Texture_Desc;
            desc.width, desc.height = App.get_window_size(g_window);
            desc.format   = .D32F;
            desc.usage    = .DEPTH_STENCIL;
            desc.clear_value.depth = 1.0;
            g_depth_targets[i] = Gfx.create_texture(desc);
            Basic.assert(g_depth_targets[i] != null);
        }
    }

    // create graphics pipeline
    {
        desc: Gfx.Pipeline_Desc;
        desc.vs_bytecode     = g_shader_vs;
        desc.ps_bytecode     = g_shader_ps;
        desc.rt_formats[0]   = g_swap_chain.desc.format;
        desc.vb_bindings[0].rate     = .PER_VERTEX;
        desc.vb_bindings[0].layout   = MY_VERTEX_LAYOUT;
        desc.rc_bindings[0].shader_visibilty = .ALL;
        desc.rc_bindings[0].shader_register  = 0;
        desc.rc_bindings[0].size  = size_of(float) * 3;
        // set pipeline depth format
        #if ENABLE_DEPTH_TEST then desc.ds_format = g_depth_targets[0].desc.format;
        // enable depth test
        #if ENABLE_DEPTH_TEST then desc.ds_state.depth_enable = true;

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
            // attach our depth write target
            #if ENABLE_DEPTH_TEST {
            targets.ds.load_op    = .CLEAR;
            targets.ds.target     = g_depth_targets[Gfx.gs.active_frame];
            }
            Gfx.begin_renderpass(encoder, targets);
            {   
                // bind our vertex buffer (at binding 0)
                Gfx.set_vertex_buffer(encoder, 0, g_vertex_buffer);
                // our normal draw order is blue -> green -> red
                // after using depth buffer red  -> blue -> green
                // draw first triangle (left)
                color0 := float.[.1,.1,.9];
                Gfx.push_constants(encoder, 0, color0.data);
                Gfx.draw(encoder, 3);
                // draw second triangle (right)
                color1 := float.[.1,.9,.1];
                Gfx.push_constants(encoder, 0, color1.data);
                Gfx.draw(encoder, 3, first_vertex=3);
                // draw middle triangle 
                color2 := float.[.9,.1,.1];
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
    float3 color;
};

struct VSInput
{
    float3 position : POSITION; // x, y, z
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
    OUT.position = float4(IN.position, 1.0);
    return OUT;
}

float4 PSMain(PSInput IN) : SV_TARGET
{
    return float4(color, 1.0);
}
DONE;