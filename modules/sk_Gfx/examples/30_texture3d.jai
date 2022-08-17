#import "Basic";
#import "Math";

App   :: #import "sk_App"; 
Gfx   :: #import "sk_Gfx";

#import "d3d12"()(INCLUDE_DEBUG_BINDINGS=true); // just to set INCLUDE_DEBUG_BINDINGS

#load "common.jai";

g_window       :  App.Window;
g_swap_chain   : *Gfx.Swap_Chain;
g_depth_targets: [Gfx.FRAME_COUNT] *Gfx.Texture;
g_pipeline     : *Gfx.Pipeline;
g_vertex_buffer: *Gfx.Buffer;
g_index_buffer : *Gfx.Buffer;
g_texture      : *Gfx.Texture;
g_bind_group   : *Gfx.Bind_Group;

g_shader_vs :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "VSMain", "vs_5_1");
g_shader_ps :: #run Gfx.compile_hlsl_shader(SHADER_TEXT, "PSMain", "ps_5_1");

MY_VERTEX_LAYOUT :: Gfx.Vertex_Member_Info.[
    .{name = "POSITION", format = .FLOAT_X3},
    .{name = "UVW"   , format = .FLOAT_X3},
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

// as we know the texture 2D mapping (UV) is like this
// 0, 0 --------------------- 1, 0
//   |                         |
//   |                         |
//   |                         |
//   |                         |
//   |                         |
// 0, 1 -------------------- 1, 1

// for texture 3D is like this (UVW)
//      (0,0,1)   ________________(1,0,1)  
//               /|              /|
//              / |             / |
//           w /  |            /  |
//            /   |  u        /   |  
//   (0,0,0) /____|__________/(1,0,0)  
//           |    |__________|____|
//         v |   /(0,1,1)    |    /(1,1,1)  
//           |  /            |   /
//           | /             |  /
//           |/              | /
//           /_______________|/
//     (0,1,0)           (1,1,0)  


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
    // POSITION            UVW
    // (front)
    -1.0,  1.0, -1.0,      0.0, 0.0, 0.0, 
     1.0,  1.0, -1.0,      1.0, 0.0, 0.0,
     1.0, -1.0, -1.0,      1.0, 1.0, 0.0,
    -1.0, -1.0, -1.0,      0.0, 1.0, 0.0,
    // (back)
     1.0,  1.0,  1.0,      1.0, 0.0, 1.0,
    -1.0,  1.0,  1.0,      0.0, 0.0, 1.0,
    -1.0, -1.0,  1.0,      0.0, 1.0, 1.0,
     1.0, -1.0,  1.0,      1.0, 1.0, 1.0,
];

my_indices :: u32.[
    // ordered clock wise (from left to right)
    0, 1, 2,  0, 2, 3,    // face 1 (front)
    1, 4, 7,  1, 7, 2,    // face 2 (right)
    4, 5, 6,  4, 6, 7,    // face 3 (back)
    5, 0, 3,  5, 3, 6,    // face 4 (left)
    0, 5, 4,  0, 4, 1,    // face 5 (top)
    6, 3, 2,  6, 2, 7,    // face 6 (bottom)
];


// you can use any image loader module
// here we just will create our own 16px X 16px 3D image (RGBA8) format.
TEXTURE_WIDTH   :s32: 16;
TEXTURE_HEIGHT  :s32: 16;
TEXTURE_DEPTH   :s32: 16;
TEXTURE_FORMAT  :: Gfx.Texture_Format.RGBA8;
// here an example how you calc the base data of any texture
TEXTURE_BPP     :s32: 4; // RGBA (bytes per pixel)
TEXTURE_STRIDE  :s32: (TEXTURE_WIDTH * TEXTURE_BPP + 3) & cast(s32) -4;   // (bytes per row)
TEXTURE_2D_SIZE :s32: TEXTURE_HEIGHT * TEXTURE_STRIDE;
TEXTURE_3D_SIZE :s32: TEXTURE_HEIGHT * TEXTURE_STRIDE * TEXTURE_DEPTH;
// we will fill this later 
random_colors_image: [TEXTURE_3D_SIZE] u8;


BIND_GROUP_LAYOUT :: Gfx.Bind_Group_Range_Info.[ 
    .{ // at offset 0 of the bind group
        shader_register = 0,        // shader slot "register(t0)"
        resource_type   = .TEXTURE, // resource type
    }
];

main :: () {
    App.enable_dpi_aware();
    // create window
    g_window = App.create_window(700, 700, "Hello Texture3D");
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
        desc.clear_color        = .[0.3, 0.3, 0.4, 1.0];
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
        desc.ra_state.depth_clip_enable = true;
        // set our pipeline layout at binding slot number 0.
        desc.vb_bindings[0].rate   = .PER_VERTEX;
        desc.vb_bindings[0].layout = MY_VERTEX_LAYOUT;
        // this just minimal example so we will push single matrix
        // we will push model matrix
        desc.rc_bindings[0].shader_visibilty = .ALL;
        desc.rc_bindings[0].shader_register  = 0;
        desc.rc_bindings[0].size  = size_of(Matrix4);
        // bind groups 
        desc.bg_bindings[0].shader_visibilty  = .ALL;
        desc.bg_bindings[0].layout = BIND_GROUP_LAYOUT;
        // static samplers
        desc.static_samplers[0].shader_visibilty = .PIXEL;
        desc.static_samplers[0].shader_register  = 0;
        desc.static_samplers[0].filter    = .MIN_MAG_MIP_LINEAR; // you shall use LINEAR sampler filter with 3D textures.
        desc.static_samplers[0].address_u = .CLAMP;
        desc.static_samplers[0].address_v = .CLAMP;
        desc.static_samplers[0].address_w = .CLAMP;
        // desc.static_samplers[0].address_u = .REPEAT;
        // desc.static_samplers[0].address_v = .REPEAT;
        // desc.static_samplers[0].address_w = .REPEAT;
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

        // create random 3d texture.
        random : u32 = 0x12345678;
        for z:0..TEXTURE_DEPTH-1 {
            slice_offset := z * TEXTURE_HEIGHT * TEXTURE_STRIDE;
            for y:0..TEXTURE_HEIGHT-1 {
                row_offset := y * TEXTURE_STRIDE;
                for x:0..TEXTURE_WIDTH-1 {
                    pixel_offset := slice_offset + row_offset + (x * TEXTURE_BPP);
                    dst := random_colors_image.data + pixel_offset;
                    // dst[0] = 255; // R
                    // dst[1] = 255; // G
                    // dst[2] = 255; // B
                    // dst[3] = 255; // A
                    // get random color (source:sokol_gfx) github.com/floooh/sokol-samples/sapp/tex3d-sapp.c
                    random ^= random << 13;
                    random ^= random >> 17;
                    random ^= random << 5;
                    memcpy(dst, *random, TEXTURE_BPP);
                }
            }            
        }

        desc: Gfx.Texture_Desc;
        desc.usage        = .SHADER_RESOURCE; // we will use this texture in the shader
        desc.usage       |= .TEXTURE_3D;      // + this is texture 3d
        desc.width        = xx TEXTURE_WIDTH;
        desc.height       = xx TEXTURE_HEIGHT;
        desc.depth        = xx TEXTURE_DEPTH;
        desc.format       = TEXTURE_FORMAT;
        g_texture         = Gfx.create_texture(desc, random_colors_image.data);
    }

    // create bind group
    {
        g_bind_group = Gfx.create_bind_group(1); // creat bind group for one resource only
        Gfx.bind_texture(g_bind_group, 0, g_texture); // bind the texture at offset 0
    }

    projection := make_perspective_projection(60, 4/4, 0.1, 100, true, true);
    view       := make_look_at(.{0,0,-10}, .{0,0,0}, .{0,1,0}, true);

    ROTATE :: true;
    ROTATE_SPEED :: 100.0; // in fps
    transform  := Matrix4_Identity;

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
        rotation_angle_x += ROTATE_SPEED * .6 * delta_time;
        rotation_angle_y += ROTATE_SPEED * 1.0 * delta_time;
        rotation_angle_z += ROTATE_SPEED * .8 * delta_time;
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
                // bind our bind group (at binding 0)
                Gfx.set_bind_group(encoder, 0, g_bind_group);
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
    float3 uvw      : UVW;
};

struct PSInput
{
    float4 position : SV_POSITION;
    float3 uvw      : UVW;
};

PSInput VSMain(VSInput IN)
{
    PSInput OUT;
    OUT.position = mul(transform, float4(IN.position, 1.0));
    OUT.uvw      = IN.uvw;
    return OUT;
}

Texture3D    g_texture : register(t0); // <<------- here now we use texture 3D
SamplerState g_sampler : register(s0);

float4 PSMain(PSInput IN) : SV_TARGET
{ 
    float4 pixel = g_texture.Sample(g_sampler, IN.uvw);
    return pixel;
}
DONE;