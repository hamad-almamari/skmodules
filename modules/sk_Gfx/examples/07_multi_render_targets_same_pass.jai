Basic :: #import "Basic";
App   :: #import "sk_App"; 
Gfx   :: #import "sk_Gfx";
#import "d3d12"()(INCLUDE_DEBUG_BINDINGS=true); // just to set INCLUDE_DEBUG_BINDINGS

g_window       :  App.Window;
g_window2      :  App.Window;
g_swap_chain   : *Gfx.Swap_Chain;
g_swap_chain2  : *Gfx.Swap_Chain;
g_pipeline     : *Gfx.Pipeline;
g_vertex_buffer: *Gfx.Buffer;

g_shader_vs    :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "VSMain", "vs_5_1");
g_shader_ps    :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "PSMain", "ps_5_1");

MY_VERTEX_LAYOUT :: Gfx.Vertex_Member_Info.[
    .{name = "POSITION", format = .FLOAT_X2}
];

my_vertices :: float.[
    // dummy triangle
     0.0,  0.5,
     0.6, -0.5,
    -0.6, -0.5,
];

main :: () {
    App.enable_dpi_aware();
    // create the windows
    g_window  = App.create_window(512, 512, "Multi RT: RT 1 Same Pass");
    g_window2 = App.create_window(512, 512, "Multi RT: RT 2 Same Pass", position_x=514);
    // init the graphics
    Gfx.init();
    used_gpu := Gfx.get_selected_adapter_info();
    Basic.print("using adapter index:% , %\n", used_gpu.adapter_index, used_gpu.description);

    // create swap chain for window 1
    {
        desc: Gfx.Swap_Chain_Desc;
        desc.width, desc.height = App.get_window_size(g_window);
        desc.native_window      = g_window;
        desc.format             = .RGBA8;
        desc.clear_color        = .[0.4, 0.8, 0.4, 1.0];
        g_swap_chain            = Gfx.create_swap_chain(desc);
    }
    // create swap chain for window 2
    {
        desc: Gfx.Swap_Chain_Desc;
        desc.width, desc.height = App.get_window_size(g_window2);
        desc.native_window      = g_window2;
        desc.format             = .RGBA8;
        desc.clear_color        = .[1.0, 1.0, 1.0, 1.0];
        g_swap_chain2           = Gfx.create_swap_chain(desc);
    }
    // create graphics pipeline
    {
        desc: Gfx.Pipeline_Desc;
        desc.vs_bytecode     = g_shader_vs;
        desc.ps_bytecode     = g_shader_ps;
        // we want to render into 2 render targets
        desc.rt_formats[0]   = g_swap_chain.desc.format;  // render target 0
        desc.rt_formats[1]   = g_swap_chain2.desc.format; // render target 1
        desc.vb_bindings[0].rate   = .PER_VERTEX;
        desc.vb_bindings[0].layout = MY_VERTEX_LAYOUT;
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

        {
        encoder := Gfx.begin_commands(g_pipeline);
            {
                // both render targets has same size
                Gfx.set_viewport_from_swc_desc(encoder, g_swap_chain.desc);
                Gfx.set_scissor_rect_from_swc_desc (encoder, g_swap_chain.desc);
                targets: Gfx.Renderpass_Targets;
                // attach render target 0
                targets.rt[0].load_op = .CLEAR;
                targets.rt[0].target  = Gfx.get_active_back_buffer(g_swap_chain);
                // attach render target 1
                targets.rt[1].load_op = .CLEAR;
                targets.rt[1].target  = Gfx.get_active_back_buffer(g_swap_chain2);
                // now begin the render pass
                Gfx.begin_renderpass(encoder, targets);
                {   
                    Gfx.set_vertex_buffer(encoder, 0, g_vertex_buffer);
                    Gfx.draw(encoder, 3);
                }
                Gfx.end_renderpass(encoder);
            }
            Gfx.end_commands(encoder);
        }

        // call this once per frame
        Gfx.execute();
    }

    // deinit and release all gpu resources
    Gfx.deinit();
}


// Shaders
//
SHADER_TEXT :: #string DONE
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

// we are using 2 render targets
struct PSOut
{
    float4 color0 : SV_TARGET0;
    float4 color1 : SV_TARGET1;
};

PSOut PSMain(PSInput IN)
{
    PSOut OUT;
    OUT.color0 = float4(1.0, 0.0, 0.0, 1.0);
    OUT.color1 = float4(IN.position.z, IN.position.z, IN.position.z, 1.0);
    return OUT;
}
DONE;