
Basic :: #import "Basic";
App   :: #import "sk_App";

Gfx   :: #import "sk_Gfx"()(INCLUDE_PIX = false);

main :: () {
    App.enable_dpi_aware();
    window  := App.create_window(800, 500, "Hello Sailor");
    window2 := App.create_window(400, 250, "Hello Sailor 2", parent=window, style=.SECONDARY);
    w, h    := App.get_window_size(window);

    Basic.print("%-%\n", w, h);

    while game_loop := true {

        e: App.Event;
        while App.next_event(*e) {
            w, h = App.get_window_size(window, false);
            //print("Size: % - %\n", w, h);
            if e.type == .WINDOW_CLOSED && e.window == window break game_loop;
            Basic.print("Event: %\n", e);
            if e.type == .INPUT {
                if e.key_code == .S     && e.input_flags & .START then App.show_mouse_cursor();
                if e.key_code == .H     && e.input_flags & .START then App.hide_mosue_cursor();
                if e.key_code == .Q     && e.input_flags & .START then App.set_mouse_position(800/2, 500/2);
                if e.key_code == .NUM_0 && e.input_flags & .START then App.hide_window(window2);
                if e.key_code == .NUM_9 && e.input_flags & .START then App.show_window(window2);
            }
        }

        Basic.sleep_milliseconds(200);
        Basic.print("----------\n");
    }
}
