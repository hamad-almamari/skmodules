#import "Basic";
#import "Math";

App   :: #import "sk_App"; 
Gfx   :: #import "sk_Gfx";

#import "d3d12"()(INCLUDE_DEBUG_BINDINGS=true); // just to set INCLUDE_DEBUG_BINDINGS

#load "common.jai";

g_window       :  App.Window;
g_swap_chain   : *Gfx.Swap_Chain;
g_depth_targets: [Gfx.FRAME_COUNT] *Gfx.Texture; // depth targets
g_pipeline     : *Gfx.Pipeline;
g_vertex_buffer: *Gfx.Buffer;
g_index_buffer : *Gfx.Buffer;

g_shader_vs :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "VSMain", "vs_5_1");
g_shader_ps :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "PSMain", "ps_5_1");

// In this example we will define the vertices as single array of floats.

MY_VERTEX_LAYOUT :: Gfx.Vertex_Member_Info.[
    .{name = "POSITION", format = .FLOAT_X3},
    .{name = "COLOR"   , format = .FLOAT_X3}
];

// world coord

//   Y+
//    |     / Z+ (forward)
//    |    /    
//    |   /        
//    |  /     
//    | /       
//-------------------X+
//    |

// Cube vertices
//            5                     4
//      (-1,+1,+1)________________(+1,+1,+1)
//               /|              /|
//              / |             / |
//             /  |            /  |
//     0      /   |         1 /   |  
//(-1,+1,-1) /____|__________/(+1,+1,-1)
//           |  6 |__________|____| 7
//           |   /(-1,-1,+1) |    /(+1,-1,+1)
//           |  /            |   /
//           | /             |  /
//           |/              | /
//         3 /_______________|/ 2
//     (-1,-1,-1)       (+1,-1,-1)
//

// our cube vertices
my_vertices :: float.[
    // POSITION  COLOR
    // face 1 (front)
    -1.0,  1.0, -1.0,     0.0, 1.0, 0.0, // 0
     1.0,  1.0, -1.0,     1.0, 1.0, 1.0, // 1
     1.0, -1.0, -1.0,     1.0, 0.0, 0.0, // 2
    -1.0, -1.0, -1.0,     0.0, 0.0, 0.0, // 3
    // far points
     1.0,  1.0, 1.0,      1.0, 1.0, 1.0, // 4
    -1.0,  1.0, 1.0,      1.0, 1.0, 1.0, // 5
    -1.0, -1.0, 1.0,      0.0, 0.0, 1.0, // 6
     1.0, -1.0, 1.0,      1.0, 1.0, 1.0, // 7
];

my_indices :: u32.[
    // ordered clock wise (from left to right)
    0, 1, 2, 0, 2, 3,    // face 1 (front)
    1, 4, 7, 1, 7, 2,    // face 2 (right)
    4, 5, 6, 4, 6, 7,    // face 3 (back)
    5, 0, 3, 5, 3, 6,    // face 4 (left)
    0, 5, 4, 0, 4, 1,    // face 5 (top)
    6, 3, 2, 6, 2, 7,    // face 6 (bottom)
];

main :: () {
    App.enable_dpi_aware();
    // create window
    g_window = App.create_window(700, 700, "Hello Cube");
    // init the graphics
    Gfx.init();
    used_gpu := Gfx.get_selected_adapter_info();
    print("using adapter index:% , %\n", used_gpu.adapter_index, used_gpu.description);

    // create swap chain for our window
    {
        desc: Gfx.Swap_Chain_Desc;
        desc.width, desc.height = App.get_window_size(g_window);
        desc.native_window      = g_window;
        desc.format             = .RGBA8;
        desc.clear_color        = .[0.6, 0.4, 0.8, 1.0];
        g_swap_chain            = Gfx.create_swap_chain(desc);
    }

    // depth targets
    {
        for i:0..g_depth_targets.count-1 {
            desc: Gfx.Texture_Desc;
            desc.width, desc.height = App.get_window_size(g_window);
            desc.format   = .D32F;
            desc.usage    = .DEPTH_STENCIL;
            desc.clear_value.depth = 1.0;
            g_depth_targets[i] = Gfx.create_texture(desc);
        }
    }

    // create graphics pipeline
    {
        desc: Gfx.Pipeline_Desc;
        desc.vs_bytecode     = g_shader_vs;
        desc.ps_bytecode     = g_shader_ps;
        desc.rt_formats[0]   = g_swap_chain.desc.format;
        // depth
        desc.ds_format       = g_depth_targets[0].desc.format;
        desc.ds_state.depth_enable = true;
        desc.ds_state.depth_compare_op = .LESS;
        // rasterizer state
        // enable clip z (do not show far or near objects)
        // desc.ra_state.fill_mode = .WIREFRAME;
        desc.ra_state.depth_clip_enable = true; // only show when z <= 1.0 & > -1 (in d3d12 -1 mapped to 0.0)
        // set our pipeline layout at binding slot number 0.
        desc.vb_bindings[0].rate   = .PER_VERTEX;
        desc.vb_bindings[0].layout = MY_VERTEX_LAYOUT;
        // this just minimal example so we will push single matrix
        // we will push model matrix
        desc.rc_bindings[0].shader_visibilty = .ALL;
        desc.rc_bindings[0].shader_register  = 0;
        desc.rc_bindings[0].size  = size_of(Matrix4); 

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


    // projection := make_orthographic_projection(-4, 4, -4, 4, 0.1, 100, true, true);
    // projection := make_orthographic_projection(-4, 4, -4, 4, -10, 10, false, true); // Tip: you can use with out look at matrix
    projection := make_perspective_projection(60, 4/4, 0.1, 100, true, true);
    view       := make_look_at(.{0,0,-10}, .{0,0,0}, .{0,1,0}, true);

    ROTATE :: true;
    ROTATE_SPEED :: 70.0; // in fps
    transform  := Matrix4_Identity;
    
    {
        // 
        // ver := make_vector4(my_vertices[0], my_vertices[1], my_vertices[2], 1.0);
        // ver = projection * view * transform * ver;
        // print("ver:%\n", ver);
    }

    cube_rotation: Quaternion;
    rotation_angle_x := 0.0;
    rotation_angle_y := 0.0;
    rotation_angle_z := 0.0;
    // game loop
    delta_time := 0.01667;
    while run_game_loop := true {
        frame_start := current_time_monotonic ();
        // Handle app events 
        e: App.Event;
        while App.next_event(*e) {
            if e.type == .WINDOW_CLOSED break run_game_loop;
        }

        // Update/Simulate -----
        // NOTE: in real game you should put this in fixed delta update
        transform  = Matrix4_Identity;
        rotation_angle_x += ROTATE_SPEED * delta_time;
        rotation_angle_y += ROTATE_SPEED * 1.5 * delta_time;
        rotation_angle_z += ROTATE_SPEED * delta_time;
        to_euler_angle :: PI / 180.0;
        // [1] Scale 
        // scale(*transform, .{2,2,2});
        // [2] Rotate
        #if ROTATE {
            set_from_axis_and_angle(*cube_rotation, .{1,0,0}, rotation_angle_x * to_euler_angle);
            rot_matrix := rotation_matrix(Matrix4, cube_rotation);
            transform  = multiply(rot_matrix, transform);
             set_from_axis_and_angle(*cube_rotation, .{0,1,0}, rotation_angle_y * to_euler_angle);
            rot_matrix = rotation_matrix(Matrix4, cube_rotation);
            transform  = multiply(rot_matrix, transform);
            set_from_axis_and_angle(*cube_rotation, .{0,0,1}, rotation_angle_z * to_euler_angle);
            rot_matrix = rotation_matrix(Matrix4, cube_rotation);
            transform  = multiply(rot_matrix, transform);
        }
        // [3] Translate
        //translate(*transform, .{1,0,0});
        // [4] multiply into projection
        {          
            transform = projection * view * transform;
        }

        // Render -----
        // start commands encoder
        encoder := Gfx.begin_commands(g_pipeline);
        {
            Gfx.set_viewport_from_swc_desc(encoder, g_swap_chain.desc);
            Gfx.set_scissor_rect_from_swc_desc(encoder, g_swap_chain.desc);
            targets: Gfx.Renderpass_Targets;
            targets.rt[0].load_op = .CLEAR;
            targets.rt[0].target  = Gfx.get_active_back_buffer(g_swap_chain);
            targets.ds.load_op    = .CLEAR;
            targets.ds.target     = g_depth_targets[Gfx.gs.active_frame];
            Gfx.begin_renderpass(encoder, targets);
            {   
                // bind our index buffer
                Gfx.set_index_buffer(encoder, g_index_buffer);
                // bind our vertex buffer (at binding 0)
                Gfx.set_vertex_buffer(encoder, 0, g_vertex_buffer);
                // set the transform
                Gfx.push_constants(encoder, 0, *transform);
                // draw indexed
                Gfx.draw_indexed(encoder, my_indices.count);
            }
            Gfx.end_renderpass(encoder);
        }
        Gfx.end_commands(encoder);
         
        // call this once per frame
        Gfx.execute();

        //sleep_milliseconds(10);

        frame_end := current_time_monotonic();
		delta_time = cast (float) to_float64_seconds(frame_end - frame_start);
        //print ("delta_time:%\n", delta_time);
    }

    // deinit and release all gpu resources
    Gfx.deinit();
}


// Shaders
//
SHADER_TEXT :: #string DONE
cbuffer PushConstantsData: register(b0)
{
    row_major float4x4 transform;
};

struct VSInput
{
    float3 position : POSITION;
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
    OUT.position = mul(transform, float4(IN.position, 1.0));
    OUT.color    = float4(IN.color, 1.0);
    
    // cool staff you should try
    // [1] use y coord as color, map -1,1 y range to 0,1 
    // float y = IN.position.y * 0.5 + 0.5;
    // OUT.color = float4(y, y, y, 1.0);

    // [2] using screen uv
    // OUT.color = float4(OUT.position.y, OUT.position.y, OUT.position.y, 1.0);

    return OUT;
}

float4 PSMain(PSInput IN) : SV_TARGET
{
    return IN.color;
}
DONE;