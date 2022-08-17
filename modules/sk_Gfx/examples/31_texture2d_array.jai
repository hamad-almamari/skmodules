Basic :: #import "Basic";
App   :: #import "sk_App"; 
Gfx   :: #import "sk_Gfx";
#import "d3d12"()(INCLUDE_DEBUG_BINDINGS=true); // just to set INCLUDE_DEBUG_BINDINGS

// Texture2D with multi slices example

g_window       :  App.Window;
g_swap_chain   : *Gfx.Swap_Chain;
g_pipeline     : *Gfx.Pipeline;
g_vertex_buffer: *Gfx.Buffer;
g_index_buffer : *Gfx.Buffer;
g_texture      : *Gfx.Texture;
g_bind_group   : *Gfx.Bind_Group;

g_shader_vs :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "VSMain", "vs_5_1");
g_shader_ps :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "PSMain", "ps_5_1");

MY_VERTEX_LAYOUT :: Gfx.Vertex_Member_Info.[
    .{name = "POSITION", format = .FLOAT_X2},
    .{name = "UVI"     , format = .FLOAT_X3} // U V I=(texture index)
];

my_vertices :: float.[
    // Quad 0 (using texture 0)
    // POSITION       U    V   I (texture index)
    -0.8,  0.8,      0.0, 0.0,  0, // left top     vertex:0
    -0.2,  0.8,      1.0, 0.0,  0, // right top    vertex:1
    -0.2, -0.2,      1.0, 1.0,  0, // right bottom vertex:2
    -0.8, -0.2,      0.0, 1.0,  0, // left bottom  vertex:3
    // Quad 1 (using texture 1)
     0.2,  0.8,      0.0, 0.0,  1, // left top     vertex:4
     0.8,  0.8,      1.0, 0.0,  1, // right top    vertex:5
     0.8, -0.2,      1.0, 1.0,  1, // right bottom vertex:6
     0.2, -0.2,      0.0, 1.0,  1, // left bottom  vertex:7
];

my_indices :: u32.[
    0, 1, 2, 0, 2, 3, // quad 1
    4, 5, 6, 4, 6, 7, // quad 2
];

// Texture2D with multi slices
// you can use any image loader module
// here we just will define our own 4px X 4px images (RGBA8) format
TEXTURE_WIDTH  :u32: 4; // note that this the slice width
TEXTURE_HEIGHT :u32: 4; // note that this the slice height
TEXTURE_FORMAT :: Gfx.Texture_Format.RGBA8;
TEXTURE_DATA   :: u8.[
  // Texture 0 (RED-BLACk) 4x4 px -> array slice 0
  // R  G   B  A  - ....
  255, 10, 10, 255, 0, 0, 0, 255, 255, 10, 10, 255, 0, 0, 0, 255,
  0, 0, 0, 255, 255, 10, 10, 255, 0, 0, 0, 255, 255, 10, 10, 255,
  255, 10, 10, 255, 0, 0, 0, 255, 255, 10, 10, 255, 0, 0, 0, 255,
  0, 0, 0, 255, 255, 10, 10, 255, 0, 0, 0, 255, 255, 10, 10, 255,
  // Texture 1 (Green-BLACk) 4x4 px -> array slice 1
  10, 255, 10, 255, 0, 0, 0, 255, 10, 255, 10, 255, 0, 0, 0, 255,
  0, 0, 0, 255, 10, 255, 10, 255, 0, 0, 0, 255, 10, 255, 10, 255,
  10, 255, 10, 255, 0, 0, 0, 255, 10, 255, 10, 255, 0, 0, 0, 255,
  0, 0, 0, 255, 10, 255, 10, 255, 0, 0, 0, 255, 10, 255, 10, 255,
];

// also you need to define your bind group layout
BIND_GROUP_LAYOUT :: Gfx.Bind_Group_Range_Info.[ 
    .{ // at offset 0 of the bind group
        shader_register = 0,        // shader slot "register(t0)"
        resource_type   = .TEXTURE, // resource type
        // NOTE: resource_count (of Bind_Group_Range_Info) shall be one, *it is not related to the texture array slices count*
        resource_count   = 1, // resource count, this by default is one, just we set it here to show that.
    }
];

main :: () {
    App.enable_dpi_aware();
    // create window
    g_window = App.create_window(1024, 512, "Texture2D Array Slices");
    // init the graphics
    Gfx.init();

    // create swap chain for our window
    {
        desc: Gfx.Swap_Chain_Desc;
        desc.width, desc.height = App.get_window_size(g_window);
        desc.native_window      = g_window;
        desc.format             = .RGBA8;
        desc.clear_color        = .[0.3, 0.3, 0.4, 1.0];
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
        // set our root layout
        desc.bg_bindings[0].shader_visibilty = .ALL;
        desc.bg_bindings[0].layout    = BIND_GROUP_LAYOUT;
        // static samplers
        desc.static_samplers[0].shader_visibilty = .PIXEL;
        desc.static_samplers[0].shader_register      = 0;
        // .. it will use default sampler
        g_pipeline           = Gfx.create_pipeline(desc);
    }

    // create vertex buffer
    {
        desc: Gfx.Buffer_Desc;
        desc.usage      = .VERTEX_BUFFER;
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

    // create texture
    {
        desc: Gfx.Texture_Desc;
        desc.usage        = .SHADER_RESOURCE;
        desc.width        = TEXTURE_WIDTH;
        desc.height       = TEXTURE_HEIGHT;
        desc.array_count  = 2; // array slice count
        desc.format       = TEXTURE_FORMAT;
        g_texture         = Gfx.create_texture(desc, TEXTURE_DATA.data);
    }

    // create bind group
    {
        g_bind_group = Gfx.create_bind_group(5);
        Gfx.bind_texture(g_bind_group, 0, g_texture); // bind the texture at offset 0
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
                // bind our bind group (at binding 0)
                Gfx.set_bind_group(encoder, 0, g_bind_group);
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
    float3 uvi      : UVI;
};

struct PSInput
{
    float4 position : SV_POSITION;
    float3 uvi      : UVI;
};

PSInput VSMain(VSInput IN)
{
    PSInput OUT;
    OUT.position = float4(IN.position, 0.0, 1.0);
    OUT.uvi      = IN.uvi;
    return OUT;
}

Texture2DArray g_texture : register(t0);
SamplerState g_sampler   : register(s0);

float4 PSMain(PSInput IN) : SV_TARGET
{
    float4 pixel = g_texture.Sample(g_sampler, IN.uvi);
    return pixel;
}
DONE;