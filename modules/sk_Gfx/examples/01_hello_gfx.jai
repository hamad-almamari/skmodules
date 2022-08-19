// hello gfx minimal example
Basic :: #import "Basic";
App   :: #import "sk_App"; 


//Gfx   :: #import "sk_Gfx"()(BACKEND = .DUMMY);
Gfx   :: #import "sk_Gfx"()(BACKEND = .D3D12);

// #if false {
    D3d12 :: #import "d3d12"()(INCLUDE_DEBUG_BINDINGS=true); // just to set INCLUDE_DEBUG_BINDINGS
// }

// You can use "sk_Gfx" with any module that provides native window handle all what we need is the native window handle.
// in this example we will use "sk_App" module for creating the window.

// So, All what you need for geting start with this module is window handle
// for creating swapchan then for this minimal example we will define our pipeline shaders.
// After that we will create our graphics pipeline.

g_window    : App.Window;
g_swap_chain: *Gfx.Swap_Chain;
g_pipeline  : *Gfx.Pipeline;

#if Gfx.BACKEND == .D3D12 {
    g_shader_vs :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "VSMain", "vs_5_1");
    g_shader_ps :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "PSMain", "ps_5_1");
} else {
    g_shader_vs :: u8.[];
    g_shader_ps :: u8.[];
}

main :: () {
    App.enable_dpi_aware();
    // create window
    g_window = App.create_window(1024, 512, "Hello Gfx");
    // init the graphics
    // NOTE: you can pass config into "init" if you want
    //
    // config: Gfx.Config;
    // ...
    // Gfx.init(config);

    // here we just we will use default config.
    Gfx.init();

    used_gpu := Gfx.get_selected_adapter_info();
    Basic.print("using adapter index:% , %\n", used_gpu.adapter_index, used_gpu.description);

    // create swap chain for our window
    {
        desc: Gfx.Swap_Chain_Desc;
        desc.width, desc.height = App.get_window_size(g_window);
        desc.native_window      = g_window;
        desc.format             = .RGBA8;
        desc.clear_color        = .[0.1, 0.1, 0.1, 1.0];
        g_swap_chain            = Gfx.create_swap_chain(desc);
    }
    // create graphics pipeline
    {
        desc: Gfx.Pipeline_Desc;
        desc.vs_bytecode     = g_shader_vs;
        desc.ps_bytecode     = g_shader_ps;
        desc.rt_formats[0]   = g_swap_chain.desc.format;
        g_pipeline           = Gfx.create_pipeline(desc);
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
        // NOTE: do not store this for morethan one frame.
        encoder := Gfx.begin_commands(g_pipeline);
        {
            Gfx.set_viewport_from_swc_desc(encoder, g_swap_chain.desc);
            Gfx.set_scissor_rect_from_swc_desc (encoder, g_swap_chain.desc);
            targets: Gfx.Renderpass_Targets;
            targets.rt[0].load_op = .CLEAR;
            targets.rt[0].target  = Gfx.get_active_back_buffer(g_swap_chain); // returns current/active back buffer
            Gfx.begin_renderpass(encoder, targets);
            {    
                Gfx.draw(encoder, 3); // the three vertices defined in the shader.
            }
            Gfx.end_renderpass(encoder);
        }
        Gfx.end_commands(encoder); 

        // call this once per frame
        Gfx.execute();

        Basic.sleep_milliseconds(20);
    }

    // deinit and release all gpu resources
    Gfx.deinit();
}


// Shaders
//
SHADER_TEXT :: #string DONE
// in this example we define vertices in the shader
static float2 vertices[3] = {
    float2(0.0, 0.5),
    float2(0.5, -0.5),
    float2(-0.5, -0.5)
};

float4 VSMain(uint vertex_id: SV_VERTEXID) : SV_POSITION
{
    return float4(vertices[vertex_id], 0.0, 1.0);
}

float4 PSMain(float4 pos: SV_POSITION) : SV_TARGET
{
    return float4(1.0, 1.0, 1.0, 1.0);
}
DONE;