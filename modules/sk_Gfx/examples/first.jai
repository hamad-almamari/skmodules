#import "Basic";
#import "Math";
#import "d3d12"()(INCLUDE_DEBUG_BINDINGS=true); // just to set INCLUDE_DEBUG_BINDINGS

System  :: #import "System";
String  :: #import "String";
Unicode :: #import "Unicode";

App     :: #import "sk_App"; 

Gfx     :: #import "sk_Gfx"()(INCLUDE_PIX = false);
Batcher :: #import "sk_Batcher";
Bitmap  :: #import "sk_Bitmap";
Font    :: #import "sk_Font";

#load "gui.jai";

g_window      : App.Window;
g_swap_chain  : *Gfx.Swap_Chain;
g_pipeline    : *Gfx.Pipeline;
g_bind_group  : *Gfx.Bind_Group;
g_home_texture: *Gfx.Texture;


g_shader_vs   :: #run Gfx.compile_hlsl_shader(MY_SHADER_TEXT, "VSMain", "vs_5_1");
g_shader_ps   :: #run Gfx.compile_hlsl_shader(MY_SHADER_TEXT, "PSMain", "ps_5_1");

g_home_bitmap : Bitmap.Bitmap;
g_font        : Font.Font;

Im_Vertex :: struct {
    pos: Vector2;
    col: Vector3;
    // we will define the layout here
    LAYOUT :: Gfx.Vertex_Member_Info.[
        .{name = "POSITION", format = .FLOAT_X2},
        .{name = "COLOR"   , format = .FLOAT_X3}
    ];
}


// CreateDescriptorHeap range
ROOT_BINDING_LAYOUT :: Gfx.Bind_Group_Range_Info.[ 
    .{slot = 0, type = .SRV, count = 1}, // offset 0 ?
    //...
];

// bind_group := create_bind_group(8);
// bind_resource(bind_group, 0, texture0);
// bind_resource(bind_group, 1, texture0);

state2d : Batcher.Batcher_State(Im_Vertex);

SAMPLE_COUNT :: 1;
main :: () {
    App.enable_dpi_aware();
    path := String.path_strip_filename(System.get_path_of_running_executable());
    set_working_directory(path);

    // create window
    g_window = App.create_window(1024, 512, "Hello Sailor");

    ww, wh := App.get_window_size(g_window, false);
    Basic.print("window-w:%, window-h:%\n", ww, 0xfe9e);

    g_font = Font.load_from_file("./Cairo-Bold.ttf", 48);
    //Basic.print("g_font:% \n",g_font);
    {
        success := Font.set_unknown_character(*g_font, 0xfffd);                     // REPLACEMENT_CHARACTER
        if !success then success = Font.set_unknown_character(*g_font, 0x2022);     // BULLET
        if !success then success = Font.set_unknown_character(*g_font, #char "?");  // ?
    }

    for 0..150 {
        Font.find_glyph(*g_font, cast(u32)it);
    }

    for 65182..76000 {
        Font.find_glyph(*g_font, cast(u32)it);
    }

    // for 1680..1680 Font.find_glyph(*g_font, cast(u32)it);
    Font.find_glyph(*g_font, 0x0627);
    prepare_text("حمد المعمري");

    for page, page_index :g_font.pages {
        Basic.log("page hash: %", page.hash);
        filepath := sBasic.print("./page-%-bitmap-bitmap.png", page_index);
        Bitmap.save(page.bitmap, filepath);
        Basic.free(filepath);
    }

    // init the graphics
    Gfx.init();

    // create swap chain for our window
    {
        desc: Gfx.Swap_Chain_Desc;
        desc.width, desc.height = App.get_window_size(g_window, false);
        desc.native_window      = g_window;
        desc.format             = .RGBA8;
        desc.clear_color        = .[0.1, 0.1, 0.1, 1.0];
        desc.sample_count       = SAMPLE_COUNT;
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
        desc.bg_bindings[0].layout   = ROOT_BINDING_LAYOUT;
        desc.rt_formats[0]             = g_swap_chain.desc.format;
        desc.bl_state.blend_enable     = true;
    //     desc.bl_state.src_color_blend_factor  = .SRC_ALPHA;       // RenderTarget.SrcBlend
    //     desc.bl_state.dest_color_blend_factor = .ONE;   // RenderTarget.DestBlend
    //     desc.bl_state.color_blend_op          = .ADD;             // RenderTarget.BlendOp
    // // alpha
    //     desc.bl_state.src_alpha_blend_factor  = .SRC_ALPHA;    // RenderTarget.SrcBlendAlpha
    //     desc.bl_state.dest_alpha_blend_factor = .ONE;   // RenderTarget.DestBlendAlpha
    //     desc.bl_state.alpha_blend_op          = .ADD;    // RenderTarget.BlendOpAlpha
//         textBlendStateDesc.RenderTarget[0].SrcBlend = D3D12_BLEND_SRC_ALPHA;
// textBlendStateDesc.RenderTarget[0].DestBlend = D3D12_BLEND_ONE;
// textBlendStateDesc.RenderTarget[0].BlendOp = D3D12_BLEND_OP_ADD;

// textBlendStateDesc.RenderTarget[0].SrcBlendAlpha = D3D12_BLEND_SRC_ALPHA;
// textBlendStateDesc.RenderTarget[0].DestBlendAlpha = D3D12_BLEND_ONE;
// textBlendStateDesc.RenderTarget[0].BlendOpAlpha = D3D12_BLEND_OP_ADD;
        desc.sample_count = SAMPLE_COUNT;
        g_pipeline                     = Gfx.create_pipeline(desc);
    }

    g_home_bitmap = Bitmap.load_from_file("./home-240.png");
    {
        //Basic.print("stride: %\n", g_home_bitmap.stride);
        desc: Gfx.Texture_Desc;
        desc.usage        = .SHADER_RESOURCE;
        desc.width        = xx g_font.pages[0].bitmap.width; // xx g_home_bitmap.width;
        desc.height       = xx g_font.pages[0].bitmap.height;//xx g_home_bitmap.height;
        desc.format       = .R8;
        desc.sample_count = 1;
        g_home_texture    = Gfx.create_texture(desc, g_font.pages[0].bitmap.data.data);
    }

    // create bind group
    {
        g_bind_group = Gfx.create_bind_group(1);
        Gfx.bind_texture(g_bind_group, 0, g_home_texture);
    }

    init_my_widget();

    while true { 
        e: App.Event;
        while App.next_event(*e) {
            if e.type == .WINDOW_CLOSED break;
        }
        if e.type == .WINDOW_CLOSED break;
 
        record_frame_commands();
        draw_my_widget(Gfx.get_active_back_buffer(g_swap_chain)); // make this for all ui
        Gfx.execute();

        //sleep_milliseconds(10);
    }
    Gfx.deinit();
}

prepare_text :: (str:string) {
    t := str.data;
    end := str.data + str.count;
    while t < end { 
        utf32 := Unicode.character_utf8_to_utf32(t, str.count);
        glph := Font.find_glyph(*g_font, utf32);
        Basic.print("glph: %\n", utf32);
        t = Unicode.unicode_next_character(t);
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

        { // first check if there is root bindings
            ID3D12GraphicsCommandList_SetDescriptorHeaps(encoder.d3d_command_list, 1, *Gfx.gs.d3d_bgr_views_heap);
        }

        Gfx.set_bind_group(encoder, 0, g_bind_group); // IM we can use fixed count of textures and the user can set the bind group

        Gfx.begin_renderpass(encoder, targets);
        {    
            // state := Batcher.begin(encoder, 1024, Vertex); // NOTE: THIS all be allocated in the frame pool
            // v := Batcher.check_and_get(state, 6);

            // Batcher.flush(state);

            
            
            // // draw quads
            // im_quad(-.5, .9, -.2, .5, .{1,0,0});
            // im_quad(0, .9, .3, .5, .{0,1,0});
            // Batcher.draw_and_flush(*state2d, encoder, 0);
            // // draw another quads batch
            // im_quad(-.5, .4, -.2, .0, .{0,0,1});
            // im_quad(0, .4, .3, .0, .{0,1,1});
            // Batcher.draw_and_flush(*state2d, encoder, 0);
            draw_text();
            Batcher.draw_and_flush(*state2d, encoder, 0);
        }
        Gfx.end_renderpass(encoder);
    }
    Gfx.end_commands(encoder); 
}

draw_text :: () {
    y  := .9;// top
    x  := -.9;// left
    sw, sh := App.get_window_size(g_window, false);
    nw := 2.0/sw;
    nh := 2.0/sh;
    for 50..100 {
        glyph := Font.find_glyph(*g_font, cast(u32)it);
        // in screen coord
        left    := x    + glyph.offset_x*nw;
        right   := left + glyph.width*nw;
        top     := y    + glyph.offset_y*nh - glyph.pixel_height*nh;
        bottom  := top - glyph.height*nh;
        //Basic.print("n0:%- % -%\n", n0, glyph.width * n0, x - glyph.width);
        x += (glyph.advance_x+4)*nw;
        // t := (glyph.u1 - glyph.u0) * Font.PAGE_ATLAS_WIDTH;
        // a := (right-left) * sw;
        //Basic.print("w:%, t:% , w:%\n", glyph.width, t, a);
        im_quad(left, top, right, bottom, glyph.u0, glyph.v0, glyph.u1, glyph.v1);
    }

    w := 1024.0*nw;
    h := 1024.0*nh;

    //Basic.print("w:%, h:% , sw:%, sh:%\n", w, h, sw, sh);
    //Basic.print("bw:%, bh:% \n", 1/w, 1/h);
    //im_quad(-1, 1, -1+w, 1-h, 0, 0, 1, 1);
}

im_quad :: (left:float, top:float, right:float, bottom:float, u0:float, v0:float, u1:float, v1:float) {
    v := Batcher.check_and_get(*state2d, 6);
    // first triangle
    v[0].pos = make_vector2(left, top);
    v[0].col = make_vector3(u0, v0, 1);
    v[1].pos = make_vector2(right, top);
    v[1].col = make_vector3(u1,v0, 1);
    v[2].pos = make_vector2(right, bottom);
    v[2].col = make_vector3(u1,v1, 1);
    // second triangle
    v[3]     = v[0];
    v[4]     = v[2];
    v[5].pos = make_vector2(left, bottom);
    v[5].col = make_vector3(u0,v1, 1);
}

im_quad :: (x0:float, y0:float, x1:float, y1:float, color:Vector3) {
    v := Batcher.check_and_get(*state2d, 6);
    // first triangle
    v[0].pos = make_vector2(x0, y0);
    v[0].col = color;
    v[1].pos = make_vector2(x1, y0);
    v[1].col = color;
    v[2].pos = make_vector2(x1, y1);
    v[2].col = color;
    // second triangle
    v[3]     = v[0];
    v[4]     = v[2];
    v[5].pos = make_vector2(x0, y1);
    v[5].col = color;
}

// im_quad :: (left:float, y0:float, right:float, bottom:float, color:Vector3) {
//     v := Batcher.check_and_get(*state2d, 6);
//     // first triangle
//     v[0].pos = make_vector2(left, top);
//     v[0].col = color;
//     v[1].pos = make_vector2(right, top);
//     v[1].col = color;
//     v[2].pos = make_vector2(right, bottom);
//     v[2].col = color;
//     // second triangle
//     v[3]     = v[0];
//     v[4]     = v[2];
//     v[5].pos = make_vector2(left, bottom);
//     v[5].col = color;
// }

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
    float4 pixel = g_texture.Sample(g_sampler, IN.color.rg);
    return float4(1, 1, 1, pixel.r);
    return IN.color;
}
DONE;
