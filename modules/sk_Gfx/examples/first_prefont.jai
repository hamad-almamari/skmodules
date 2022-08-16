#import "Basic";
#import "System"; // get_path_of_running_executable
#import "String"; // path_strip_filename
#import "Math";
#import "d3d12"()(INCLUDE_DEBUG_BINDINGS=true); // just to set INCLUDE_DEBUG_BINDINGS

App     :: #import "sk_App";
Gfx     :: #import "sk_Gfx"()(INCLUDE_PIX = false);
Batcher :: #import "sk_Batcher";
Bitmap  :: #import "sk_Bitmap";

g_window      : App.Window;
g_swap_chain  : *Gfx.Swap_Chain;
g_pipeline    : *Gfx.Pipeline;
g_shader_vs   :: #run Gfx.compile_hlsl_shader(MY_SHADER_TEXT, "VSMain", "vs_5_1");
g_shader_ps   :: #run Gfx.compile_hlsl_shader(MY_SHADER_TEXT, "PSMain", "ps_5_1");
g_bind_group  : *Gfx.Bind_Group;
g_home_bitmap : Bitmap.Bitmap;
g_home_texture: *Gfx.Texture;

//---------------
g_vertex_buffer: *Gfx.Buffer;
g_index_buffer : *Gfx.Buffer;

MY_VERTEX_LAYOUT :: Gfx.Vertex_Member_Info.[
    .{name = "POSITION", format = .FLOAT_X2},
    .{name = "COLOR"   , format = .FLOAT_X3}
];

my_vertices :: float.[
    // POSITION     COLOR
    -0.5,  0.5,      0.0, 0.0, 0.0, // left top     vertex:0
     0.5,  0.5,      1.0, 0.0, 0.0, // right top    vertex:1
     0.5, -0.5,      1.0, 1.0, 0.0, // right bottom vertex:2
    -0.5, -0.5,      0.0, 1.0, 0.0, // left bottom  vertex:3
];

my_indices :: u32.[
    0, 1, 2, // first triangle
    0, 2, 3, // second triangle
];

//------------
Im_Vertex :: struct {
    pos: Vector2;
    col: Vector3;
    // we will define the layout here
    LAYOUT :: Gfx.Vertex_Member_Info.[
        .{"POSITION", .FLOAT_X2},
        .{"COLOR"   , .FLOAT_X3}
    ];
}

state2d : Batcher.Batcher_State(Im_Vertex);

main :: () {
    #if OS == .WINDOWS {
        Windows.SetProcessDPIAware();

        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows :: #import "Windows";
        Windows.timeBeginPeriod(1);
    }
    path := path_strip_filename(get_path_of_running_executable());
    set_working_directory(path);

    // create window
    g_window = App.create_window(1024, 512, "Hello Sailor");


    // init the graphics
    Gfx.init();
    defer Gfx.deinit();

    // create swap chain for our window
    {
        desc: Gfx.Swap_Chain_Desc;
        desc.width, desc.height = App.get_window_size(g_window, false);
        desc.native_window      = g_window;
        desc.format             = .RGBA8;
        desc.clear_color        = .[0.1, 0.2, 0.4, 1.0];
        g_swap_chain            = Gfx.create_swap_chain(desc);
    }
    // create graphics pipeline
    {
        desc: Gfx.Pipeline_Desc;
        desc.vs_bytecode               = g_shader_vs;
        desc.ps_bytecode               = g_shader_ps;
        desc.vb_bindings[0].rate   = .PER_VERTEX;
        desc.vb_bindings[0].layout = Im_Vertex.LAYOUT;
        desc.bg_bindings[0].stage    = .ALL;
        desc.bg_bindings[0].layout   = Gfx.Bind_Group_Range_Info.[
            .{
                shader_register = 0,
                type  = .SRV,
                count = 1
            }
        ];
        desc.rt_formats[0]             = g_swap_chain.desc.format;
        //desc.bl_state.blend_enable     = true;
        g_pipeline                     = Gfx.create_pipeline(desc);
    }

    // // create vertex buffer
    // {
    //     desc: Gfx.Buffer_Desc;
    //     desc.usage      = .VERTEX_BUFFER;
    //     desc.size       = size_of(float) * 5 * my_vertices.count; // 5 floats per vertex
    //     g_vertex_buffer = Gfx.create_buffer(desc, my_vertices.data);
    // }

    // // create index buffer
    // {
    //     desc: Gfx.Buffer_Desc;
    //     desc.usage     = .INDEX_BUFFER;
    //     desc.size      = size_of(u32) * my_indices.count;
    //     g_index_buffer = Gfx.create_buffer(desc, my_indices.data);
    // }

    g_home_bitmap = Bitmap.load_from_file("./home-240.png");
    {
        Basic.print("stride: %\n", g_home_bitmap.stride);
        desc: Gfx.Texture_Desc;
        desc.usage        = .SHADER_RESOURCE;
        desc.width        = xx g_home_bitmap.width;
        desc.height       = xx g_home_bitmap.height;
        desc.format       = .RGBA8;
        desc.sample_count = 1;
        g_home_texture    = Gfx.create_texture(desc, g_home_bitmap.data.data);
    }

    {
        g_bind_group = Gfx.create_bind_group(1);
        Gfx.bind_texture(g_bind_group, 0, g_home_texture);
    }

    while true { 
        e: App.Event;
        while App.next_event(*e) {
            if e.type == .WINDOW_CLOSED break;
        }
        if e.type == .WINDOW_CLOSED break;
 
        record_frame_commands();
        Gfx.execute();

        sleep_milliseconds(10);
    }
}

record_frame_commands :: () {
    encoder := Gfx.begin_commands(g_pipeline);
    {
        Gfx.set_viewport_from_swc_desc(encoder, g_swap_chain.desc);
        Gfx.set_scissor_rect_from_swc_desc (encoder, g_swap_chain.desc);
        targets: Gfx.Renderpass_Targets;
        targets.rt[0].load_op = .CLEAR;
        targets.rt[0].target  = Gfx.get_active_back_buffer(g_swap_chain);

        {
            ID3D12GraphicsCommandList_SetDescriptorHeaps(encoder.d3d_command_list, 1, *Gfx.gs.d3d_bgr_views_heap);
        }
        Gfx.set_bind_group(encoder, 0, g_bind_group);

        Gfx.begin_renderpass(encoder, targets);
        {
            // draw quads
            // width, height := App.get_window_size(g_window, false);
            // nw := 2.0/width;
            // nh := 2.0/height;
            // r := -.5 + 240.0 * nw;
            // b := .9  - 240.0  * nh;
            // im_quad(-.5, .9, r, b, .{1,0,0});
            // r = 0 + 240.0 * nw * .5;
            // b = .9  - 240.0  * nh * .5;
            // im_quad(0, .9, r, b, .{1,0,0});
            // //im_quad(0, .9, .3, .5, .{0,1,0});
            // Batcher.draw_and_flush(*state2d, encoder, 0);
            // draw another quads batch
            //im_quad(-.5, .4, -.2, .0, .{0,0,1});
            im_quad(-.5, .5, .5, -.5, .{0,1,1});
            Batcher.draw_and_flush(*state2d, encoder, 0);

            //draw_text();
        }
        Gfx.end_renderpass(encoder);
    }
    Gfx.end_commands(encoder); 
}


im_quad :: (left:float, top:float, right:float, bottom:float, color:Vector3) {
    v := Batcher.check_and_get(*state2d, 6);
    // first triangle
    v[0].pos = make_vector2(left, top);
    v[0].col = .{0,0,1};
    v[1].pos = make_vector2(right, top);
    v[1].col = .{1,0,1};
    v[2].pos = make_vector2(right, bottom);
    v[2].col = .{1,1,1};
    // second triangle
    v[3]     = v[0];
    v[4]     = v[2];
    v[5].pos = make_vector2(left, bottom);
    v[5].col = .{0,1,1};
    //Basic.print("v:%\n", v);
}


// Shaders
//
MY_SHADER_TEXT :: #string DONE
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

Texture2D    g_texture : register(t0);
SamplerState g_sampler : register(s0);
float4 PSMain(PSInput IN) : SV_TARGET
{
    return g_texture.Sample(g_sampler, IN.color.rg);
    return IN.color;
}
DONE;