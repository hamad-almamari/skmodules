Basic :: #import "Basic";
App   :: #import "sk_App"; 
Gfx   :: #import "sk_Gfx";
#import "d3d12"()(INCLUDE_DEBUG_BINDINGS=true); // just to set INCLUDE_DEBUG_BINDINGS

g_window    : App.Window;
g_swap_chain: *Gfx.Swap_Chain;
g_pipeline  : *Gfx.Pipeline;
// our constant buffer
g_level_constant_buffer: *Gfx.Buffer;
// our bind group
// bind group used to bind resources to the pipeline for example textures, constant buffers.
// the user shall group his resources into single group.
g_bind_group  : *Gfx.Bind_Group;

g_shader_vs :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "VSMain", "vs_5_1");
g_shader_ps :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "PSMain", "ps_5_1");

// we will bind our level data as constant buffer
// NOTE: make sure the each member is 16 bytes.
Level_Data :: struct {
    foo_color   := float.[1.0, 1.0, 0.2, 1.0]; // 16 byte (a float being 4 bytes)
    foo_number  := 0.0; // 4 byte, so you need to add padding of 12 bytes
    _padding    : [3] float; // 4 + 12 = 16 byte
    master_color := float.[0.0, 0.0, 1.0, 1.0]; // 16 byte
    // ...
}

BIND_GROUP_LAYOUT :: Gfx.Bind_Group_Range_Info.[ 
    .{ // at offset 0 of the bind group
        shader_register = 0,                // shader slot "register(c0)" 
        resource_type   = .CONSTANT_BUFFER, // resource type
    }
    // ...
];

main :: () {
    App.enable_dpi_aware();
    // create window
    g_window = App.create_window(1024, 512, "Constant Buffer");

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
        // set our root layout
        desc.bg_bindings[0].shader_visibilty = .ALL;
        desc.bg_bindings[0].layout    = BIND_GROUP_LAYOUT;
        g_pipeline           = Gfx.create_pipeline(desc);
    }

    // create constant buffer
    {
        my_level_data: Level_Data;

        desc: Gfx.Buffer_Desc;
        desc.usage     = .CONSTANT_BUFFER;
        desc.size      = size_of(Level_Data); // NOTE that the size will be changed to 256 "Constant buffers must be 256 byte aligned".
        g_level_constant_buffer = Gfx.create_buffer(desc, *my_level_data);
    }

    // create bind group
    {
        g_bind_group = Gfx.create_bind_group(5);
        Gfx.bind_constant_buffer(g_bind_group, 0, g_level_constant_buffer); // bind the constant buffer at offset 0
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
                // bind our bind group (at binding 0)
                Gfx.set_bind_group(encoder, 0, g_bind_group);
                // then draw
                Gfx.draw(encoder, 3); // the three vertices defined in the shader.
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

cbuffer LevelData: register(b0)
{
    float4 foo_color;
    float  foo_number;
    float4 master_color;
};

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
    return master_color;
}
DONE;