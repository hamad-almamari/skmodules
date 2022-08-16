
// Normlaized Screen coords
// -1,1 ----------- 1, 1
//  |               |
//  |               |
//  -1,-1--------- 1,-1

DataStorage :: #import "sk_Data_Storage";
for_expansion :: DataStorage.for_expansion;

Widget :: struct {
    rect      : Vector4;
    background: Vector3; // VEct 4
    scale     : float = 1;
    // [..] *Element_Base;
    element_storage: DataStorage.Data_Storage(Element_Base, 32, 32);
}

Element_Base :: struct {
    kind: enum u16 {
        UNKNOWN :: 0;
        TEXT    :: 1;
    }
}

Text :: struct {
    #as using base: Element_Base;
    base.kind = .TEXT;
    width: float = 1;  // % 
    color: Vector4;
    value: string;
    get_proc: () -> string;
}

// w := add_widget (we can use index and sort)
// add_text  (w, "label", get_proc);
// add_button(w, "name" , get_proc, set_proc);
// add_button(w, "name" , get_proc, set_proc);
//
//
// draw_proc(vertices: [][] Vertex)

add_text :: (using widget:*Widget) -> *Text {
    return cast(*Text) DataStorage.get(*element_storage);
}

render_info_widget: Widget;

init_my_widget :: () {
    render_info_widget.rect       = .{-1,0, 0,-1};
    render_info_widget.background = .{0,0, 1};
    text := add_text(*render_info_widget);
    text.value = "BOHBOH";
}

draw_my_widget :: (render_target: *Gfx.Texture) {
    encoder := Gfx.begin_commands(g_pipeline);
    {
        Gfx.set_viewport(encoder, 0, 0, xx render_target.desc.width, xx render_target.desc.height);
        Gfx.set_scissor_rect (encoder, 0, 0, xx render_target.desc.width, xx render_target.desc.height);
        targets: Gfx.Renderpass_Targets;
        targets.rt[0].load_op = .PRESERVE;
        targets.rt[0].target  = render_target;

        { // first check if there is root bindings
            ID3D12GraphicsCommandList_SetDescriptorHeaps(encoder.d3d_command_list, 1, *Gfx.gs.d3d_bgr_views_heap);
        }

        Gfx.set_bind_group(encoder, 0, g_bind_group); // IM we can use fixed count of textures and the user can set the bind group

        Gfx.begin_renderpass(encoder, targets);
        {
            // y  := -.9;// top
            // x  := -.9;// left
            // sw, sh := App.get_window_size(g_window, false);
            // nw := 2.0/sw;
            // nh := 2.0/sh;
            // for 50..100 {
            //     glyph := Font.find_glyph(*g_font, cast(u32)it);
            //     // in screen coord
            //     left    := x    + glyph.offset_x*nw;
            //     right   := left + glyph.width*nw;
            //     top     := y    + glyph.offset_y*nh - glyph.pixel_height*nh;
            //     bottom  := top - glyph.height*nh;
            //     //Basic.print("n0:%- % -%\n", n0, glyph.width * n0, x - glyph.width);
            //     x += (glyph.advance_x+4)*nw;
            //     // t := (glyph.u1 - glyph.u0) * Font.PAGE_ATLAS_WIDTH;
            //     // a := (right-left) * sw;
            //     //Basic.print("w:%, t:% , w:%\n", glyph.width, t, a);
            //     im_quad(left, top, right, bottom, glyph.u0, glyph.v0, glyph.u1, glyph.v1);
            // }
            nw := 1.0/render_target.desc.width;
            nh := 1.0/render_target.desc.height;
            rect := render_info_widget.rect;
            im_quad(rect.x, rect.y, rect.z, rect.w, render_info_widget.background);
            for render_info_widget.element_storage {
                Basic.print("el:%\n", it);
                im_quad(-.5, .9, -.2, .5, .{1,0,0});
            }
            Batcher.draw_and_flush(*state2d, encoder, 0);
        }
        Gfx.end_renderpass(encoder);
    }
    Gfx.end_commands(encoder);
}


// Quad :: struct {
//     rect : Vector4;
//     color: Vector4;
// }

// Button :: struct {
//     name : string;
//     width: float = 1; // %
// }

// UI_Vertex :: struct {

// }

// get_backed_vertices :: ($vertex_type: Type) -> []