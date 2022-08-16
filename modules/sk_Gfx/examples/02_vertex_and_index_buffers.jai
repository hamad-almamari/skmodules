Basic :: #import "Basic";
App   :: #import "sk_App"; 
Gfx   :: #import "sk_Gfx";
#import "d3d12"()(INCLUDE_DEBUG_BINDINGS=true); // just to set INCLUDE_DEBUG_BINDINGS


g_window       :  App.Window;
g_swap_chain   : *Gfx.Swap_Chain;
g_pipeline     : *Gfx.Pipeline;

// our vertex and index buffers
g_vertex_buffer: *Gfx.Buffer;
g_index_buffer : *Gfx.Buffer;

// see the shader code, the shaders rewriten to match our vertex layout.
g_shader_vs :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "VSMain", "vs_5_1");
g_shader_ps :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "PSMain", "ps_5_1");

// You can define your vertices as single array of floats or array of custom vertex struct
// you can select whatever you want, then define the layout of your vertex to be used while 
// creating the graphics pipeline.
// In this example we will define the vertices as single array of floats.

MY_VERTEX_LAYOUT :: Gfx.Vertex_Member_Info.[
    .{name = "POSITION", format = .FLOAT_X2},
    .{name = "COLOR"   , format = .FLOAT_X3}
];

// viewport coord
// -1, 1 -------------------- 1, 1
//   |                         |
//   |                         |
//   |           0,0           |
//   |                         |
//   |                         |
// -1, -1 ------------------ 1, -1

// our quad vertices
my_vertices :: float.[
    // POSITION     COLOR
    -0.5,  0.5,      1.0, 0.0, 0.0, // left top     vertex:0
     0.5,  0.5,      0.0, 1.0, 0.0, // right top    vertex:1
     0.5, -0.5,      0.0, 0.0, 1.0, // right bottom vertex:2
    -0.5, -0.5,      1.0, 1.0, 0.3, // left bottom  vertex:3
];

my_indices :: u32.[
    0, 1, 2, // first triangle
    0, 2, 3, // second triangle
];

main :: () {
    App.enable_dpi_aware();
    // create window
    g_window = App.create_window(1024, 512, "Hello Vertex and Index Buffers");
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

    // create graphics pipeline
    {
        desc: Gfx.Pipeline_Desc;
        desc.vs_bytecode     = g_shader_vs;
        desc.ps_bytecode     = g_shader_ps;
        desc.rt_formats[0]   = g_swap_chain.desc.format;
        // Set our pipeline layout at binding slot number 0.
        desc.vb_bindings[0].rate   = .PER_VERTEX;
        desc.vb_bindings[0].layout = MY_VERTEX_LAYOUT;
        g_pipeline           = Gfx.create_pipeline(desc);
    }

    // create vertex buffer
    {
        desc: Gfx.Buffer_Desc;
        desc.usage      = .VERTEX_BUFFER;
        // since we are using array of floats the required buffer size will be size_of(float) * vertices count
        // if you prefere to use array of structured vertex, the size will be size_of(Vertex) * vertices count
        desc.size       = size_of(float) * my_vertices.count;
        g_vertex_buffer = Gfx.create_buffer(desc, my_vertices.data);
    }

    // create index buffer
    {
        desc: Gfx.Buffer_Desc;
        desc.usage     = .INDEX_BUFFER;
        desc.size      = size_of(u32) * my_indices.count;
        g_index_buffer = Gfx.create_buffer(desc, my_indices.data);
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
                // bind our index buffer
                Gfx.set_index_buffer(encoder, g_index_buffer);
                // bind our vertex buffer (at binding 0)
                Gfx.set_vertex_buffer(encoder, 0, g_vertex_buffer);
                // draw indexed
                Gfx.draw_indexed(encoder, my_indices.count);
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
struct VSInput
{
    float2 position : POSITION;
    float3 color    : COLOR;
};

struct PSInput
{
    float4 position : SV_POSITION;
    float4 color    : COLOR;
};

PSInput VSMain(VSInput IN)
{
    PSInput OUT;
    OUT.position = float4(IN.position, 0.0, 1.0);
    OUT.color    = float4(IN.color, 1.0);
    return OUT;
}

float4 PSMain(PSInput IN) : SV_TARGET
{
    return IN.color;
}
DONE;