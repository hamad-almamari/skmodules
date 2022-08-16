#assert(OS == .WINDOWS);

Window :: HWND;

// NOTE: Windows messages are sent exclusively to the thread in which the window was created.
// TODO: move events_batch to context?
next_event :: (event:*Event) -> bool {
    if !window_class_initted init_window_class();
    if event_count_to_return > 0 {
        i := events_batch.count - event_count_to_return;
        event_count_to_return -= 1;
        << event = events_batch[i];
        return true;
    } else {
        // Basic.array_reset_keeping_memory
        events_batch.count    = 0;
        event_count_to_return = 0;
    }
    // if we done from the last batch ask for new one
    while true {
        msg: MSG;
        result := PeekMessageW(*msg, null, 0, 0, PM_REMOVE);
        if !result break;
        TranslateMessage(*msg);
        DispatchMessageW(*msg);
    }
    // return first event if any
    if event_count_to_return > 0 {
        i := events_batch.count - event_count_to_return;
        event_count_to_return -= 1;
        << event = events_batch[i];
        return true;
    } 
    // if we are here means we do not care about this message so we will return false
    return false;
}

//-----------------------------------------------------

// call this only before creating any window
enable_dpi_aware :: () {
    if window_class_initted return;
    SetProcessDPIAware();
}

// Window Api
create_window :: (width:u32, height:u32, name:string, position_x:s32 = -1 , position_y:s32 = -1, style:Window_Style = 0, parent:*Window = null) -> *Window {
    if !window_class_initted init_window_class();
    ws_style: u32;
    if parent {
        ws_style = ifx style == 0 then conv_window_style(Window_Style.SECONDARY) else conv_window_style(style);
    } else {
        ws_style = ifx style == 0 then conv_window_style(Window_Style.PRIMARY) else conv_window_style(style);
    }
    // adjust window width and height.
    rect : RECT;
    rect.right  = xx width;
    rect.bottom = xx height;
    AdjustWindowRect(*rect, ws_style, .FALSE);
    r_width  := rect.right-rect.left;
    r_height := rect.bottom-rect.top;
    //print("A: % -- %\n", width, height);
    //print("B: % -- %\n", r_width, r_height);

    // window default postion
    SPI_GETWORKAREA :: 0x30;
    SystemParametersInfoW :: (uiAction: u32, uiParam: u32, pvParam: *void, fWinIni: u32) -> BOOL #foreign user32;
    if position_x == -1 || position_y == -1 {
        work_area: RECT;
        work_area_success := SystemParametersInfoW(SPI_GETWORKAREA, 0, *work_area, 0);
        if work_area_success {
            if position_x == -1 then position_x = work_area.left;
            if position_y == -1 then position_y = work_area.top;
        }
    }
    // Create the window
    hwnd := CreateWindowExW(0, 
        utf8_to_wide(WINDOW_CLASS_NAME),
        utf8_to_wide(name),
        ws_style,
        xx position_x, xx position_y,
        xx r_width, xx r_height,
        parent,
        null,
        class_hinstance,
        null); 
    Basic.assert(hwnd != null, "create_window: CreateWindowExW failed.");

    UpdateWindow(hwnd);
    ShowWindow(hwnd, SW_SHOW);
    return hwnd;
}

// check if the application has focus (currently)
is_app_has_focus :: inline () -> bool {
    hwnd := GetFocus();
    if hwnd return true;
    return false;
}

// check if the window is has focus (currently)
is_window_has_focus :: inline (window:Window) -> bool {
    hwnd := GetFocus();
    if !hwnd return false;
    return hwnd == window;
}

// check if the window is minimized (currently)
is_window_minimized :: inline (window:Window) -> bool {
    IsIconic :: (hwnd:HWND) -> BOOL #foreign user32;
    result := IsIconic(window);
    return result == .TRUE;
}

// // check if the window is closed (currently)
// is_window_closed :: inline (using window:Window) -> bool {
//     return (flags & .IS_CLOSED) != 0;
// }

// // check if the window is maximized (currently)
// is_window_maximized :: inline (using window:Window) -> bool {
//     return (flags & .IS_MAXIMIZED) != 0;
// }

show_window :: inline (window:Window) {
    ShowWindow(window, SW_SHOW);
    UpdateWindow(window);
}

hide_window :: inline (window:Window) {
    ShowWindow(window, SW_HIDE);
}

// WARNING: This will add WINDOW_RESIZE event.
minimize_window :: inline (window:Window) {
    ShowWindow(window, SW_MINIMIZE);
    // What about key input release events???
}

// WARNING: This will add WINDOW_RESIZE event.
maximize_window :: inline (window:Window) {
    ShowWindow(window, SW_MAXIMIZE);
    UpdateWindow(window);
}

// WARNING: This will add WINDOW_RESIZE event.
restore_window :: inline (window:Window) {
    ShowWindow(window, SW_RESTORE);
    UpdateWindow(window);
}

get_window_size :: (window:Window, including_borders := false) -> (width: u32, height: u32) {
    if !window return 0, 0;
    r: RECT;
    if including_borders { 
        GetWindowRect(window, *r);
    } else {
        GetClientRect(window, *r);
    }
    return cast(u32)(r.right - r.left), cast(u32)(r.bottom - r.top);
}

show_mouse_cursor :: inline () {
	ShowCursor(1);
}

hide_mosue_cursor :: inline () {
	ShowCursor(0);
}

set_mouse_position :: inline (x: s32, y: s32) {
	SetCursorPos :: (x : s32, y : s32) -> s32 #foreign user32;
	SetCursorPos(x, y);
}

// ------------------------------------[Privete]----------------------------------------------
#scope_file
#import "Windows";
#import "Windows_Utf8";
user32  :: #foreign_system_library "user32";

// we do this so we get our messages from window proc at one time
events_batch: [..] Event;
event_count_to_return : int;
window_class_initted := false;
class_hinstance      : HINSTANCE;
WINDOW_CLASS_NAME    :: "WINDOWS_APP_DEFAULT_CLASS_NAME";
init_window_class :: (background_color_rgb: [3] float = WINDOW_CREATION_COLOR) {
    if window_class_initted return;
    // use rember allocator
    events_batch.allocator = Context.default_allocator;
    timeBeginPeriod(1); // Windows is very bad at thread-switching by default unless you do this.
    class_hinstance := cast(HINSTANCE) GetModuleHandleW(null);
    // Load the first icon resource (RESOURCE_ID_FIRST_ICON).
    icon := LoadIconW(class_hinstance, cast(*u16)2 );
    err := GetLastError();
    // If the icon is null, then use the first one found in the exe.
    if icon == null {
        exe_path : [MAX_PATH]u16;
        GetModuleFileNameW(null, exe_path.data, MAX_PATH);
        icon = ExtractIconW(class_hinstance, exe_path.data, 0); // 0 means first icon.
    }
    to_u8_inside_u32 :: (f: float) -> u32 {
        u := cast(s16)(f * 255);
        if u < 0    u = 0;
        if u > 255  u = 255;

        return cast(u32) u;
    }
    // CreateSolidBrush takes a BGR color
    r := to_u8_inside_u32(background_color_rgb[0]);
    g := to_u8_inside_u32(background_color_rgb[1]);
    b := to_u8_inside_u32(background_color_rgb[2]);
    brush := CreateSolidBrush((b << 16) | (g << 8) | r);
    wc: WNDCLASSEXW;
    wc.cbSize               = size_of(WNDCLASSEXW);
    wc.style                = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
    wc.lpfnWndProc          = xx window_proc;
    wc.cbClsExtra           = 0;
    wc.cbWndExtra           = 0;
    wc.hInstance            = class_hinstance;
    wc.hIcon                = icon;
    wc.hCursor              = LoadCursorW(null, IDC_ARROW);
    wc.hbrBackground        = brush;  // cast(HBRUSH) GetStockObject(WHITE_BRUSH);
    wc.lpszMenuName         = null;
    wc.lpszClassName        = utf8_to_wide(WINDOW_CLASS_NAME);
    // Register the window class
    if RegisterClassExW(*wc) == 0 {
        Basic.assert(false, "init_window_class: RegisterClassExW faild.");
    }
    window_class_initted = true;
}

window_proc :: (hwnd: HWND, message: u32, wParam: WPARAM, lParam: LPARAM) -> s64 #c_call {
    new_context: Context; // TODO make sure that messages_buffer use same allocator
    new_context.allocator = Context.default_allocator;
    new_context.logger    = Context.default_logger;
    push_context new_context {
    if message == {
        case WM_CREATE;
            {
                e: Event;
                e.type   = .WINDOW_CREATED;
                e.window = hwnd;
                Basic.array_add(*events_batch, e);
                event_count_to_return += 1;
            }
        case WM_QUIT; #through;
        case WM_CLOSE;
            {
                e: Event;
                e.type   = .WINDOW_CLOSED;
                e.window = hwnd;
                Basic.array_add(*events_batch, e);
                event_count_to_return += 1;
            }
            // here we can add quit intercept thing?

        case WM_DESTROY;
            //report_window_event(hwnd, .WINDOW_CLOSE); already reported using WM_QUIT

        case WM_PAINT;
		    ValidateRect(hwnd, null);

        case WM_SIZE;
            if wParam == SIZE_MINIMIZED {
                e: Event;
                e.type   = .WINDOW_MINIMIZED;
                e.window = hwnd;
                Basic.array_add(*events_batch, e);
                event_count_to_return += 1;
            }
            if wParam == SIZE_MAXIMIZED {
                e: Event;
                e.type   = .WINDOW_MAXIMIZED;
                e.window = hwnd;
                Basic.array_add(*events_batch, e);
                event_count_to_return += 1;
            }

            resize_reported := false; // only we want to report resize once
            if events_batch.count > 0 {
                last_event := events_batch[events_batch.count-1];
                if last_event.window == hwnd && last_event.type == .WINDOW_RESIZED resize_reported = true;
            }
            if !resize_reported {
                e: Event;
                e.type = .WINDOW_RESIZED;
                e.window = hwnd;
                Basic.array_add(*events_batch, e);
                event_count_to_return += 1;
            }

            // TODO: RESTORE??   
            //return 0;      
        
// //             case WM_EXITSIZEMOVE;
// //                 // NOTE: if a child window is has been resized/moved this event goes to its parent. +_+ 
// //                 // the hwnd value is not child window it is its parent.
// //                 // win32_windows_events[index] |= .RESIZED;
// //                 return 0;

//             case WM_MOVE;
//                 window = find_window_by_hwnd(hwnd);
//                 // win events order FOCUS -> MOVE -> SIZE
//                 // we do not want to fire moved if the window just minimized
//                 // so we add this check to do not add .MOVED event if the window is minimized or un-minimized (restored)
//                 if window {
//                     check : bool = (window.flags & .HAS_FOUCS) && !(window.events & .LOSTFOUCS);
//                     if check then window.events |= .MOVED;
//                     return 0;
//                 }

            case WM_SETFOCUS;
                e: Event;
                e.type = .WINDOW_GAINFOCUS;
                e.window = hwnd;
                Basic.array_add(*events_batch, e);
                event_count_to_return += 1;
            case WM_KILLFOCUS;
                e: Event;
                e.type   = .WINDOW_LOSTFOCUS;
                e.window = hwnd;
                Basic.array_add(*events_batch, e);
                event_count_to_return += 1;

// //             // case WM_INPUT;
// //             //     log("INPUT");
// //             //     extra := GetMessageExtraInfo();
// //             //     if (extra & 0x82) == 0x82 {
// //             //         // Ignore touch input!
// //             //     } else {
// //             //         process_raw_input(cast(HRAWINPUT)lParam);
// //             //     }
// //             //     DefWindowProcW(hwnd, msg, wParam, lParam);

            case WM_SYSKEYDOWN; #through;
            case WM_KEYDOWN;
                repeat := ((cast (s32) lParam) & 0x40000000);
                e: Event;
                e.type         = .INPUT;
                e.window       = hwnd;
                e.key_code     = conv_vk_key_code(wParam);
                e.input_flags |= (Input_Flags.KEYBOARD | .DOWN);
                if !repeat then e.input_flags |= .START;
 
                if (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0 then e.input_flags |= .CONTROL;
                if (message == WM_SYSKEYDOWN) && (lParam & (1 << 29)) != 0   then e.input_flags |= .ALT;
                if (GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0   then e.input_flags |= .SHIFT;

                Basic.array_add(*events_batch, e);
                event_count_to_return += 1;
            case WM_SYSKEYUP; #through;
            case WM_KEYUP;
                e: Event;
                e.type         = .INPUT;
                e.window       = hwnd;
                e.key_code     = conv_vk_key_code(wParam);
                e.input_flags |= (Input_Flags.KEYBOARD | .END);

                if (GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0  then e.input_flags |= .CONTROL;
                if (message == WM_SYSKEYUP) && (lParam & (1 << 29)) != 0  then e.input_flags |= .ALT;
                if (GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0   then e.input_flags |= .SHIFT;

                Basic.array_add(*events_batch, e);
                event_count_to_return += 1;

            // mouse
            case WM_LBUTTONDOWN;
                SetCapture(hwnd);
                //report_key_press  (hwnd, .MOUSE_LEFT);
            case WM_LBUTTONUP;
                ReleaseCapture();
                //report_key_release(hwnd, .MOUSE_LEFT);
            case WM_RBUTTONDOWN;
                //report_key_press  (hwnd, .MOUSE_RIGHT);
            case WM_RBUTTONUP;
                //report_key_release(hwnd, .MOUSE_RIGHT);
            case WM_MBUTTONDOWN;
                //report_key_press  (hwnd, .MOUSE_MIDDLE);
            case WM_MBUTTONUP;
                //report_key_release(hwnd, .MOUSE_MIDDLE);

// //             case WM_MOUSEMOVE;
// //             // we use diff way now
// //                 // x := (lParam & 0xffff);
// //                 // y := (lParam >> 16) & 0xffff;
// //                 // // update our mouse positions
// //                 // state.mouse_x_position = xx x;
// //                 // state.mouse_y_position = xx y;

//             // Mouse wheel
//             case WM_MOUSEWHEEL;
//                 window = find_window_by_hwnd(hwnd);
//                 if window {
//                     window.input_events |= .MOUSE_WHEEL_SCROLL;
//                     //state.mouse_wheel_delta = xx cast,trunc(s16)(wParam >> 16);
//                 }

        } // if msg ==

    return DefWindowProcW(hwnd, message, wParam, lParam);
    }
}

conv_window_style :: (style:Window_Style) -> u32 {
    if style == 0 return 0;
    ws_style := WS_OVERLAPPED;
    if style & .TOPBAR      then ws_style |= (WS_CAPTION | WS_SYSMENU);
    if style & .MINIMIZEBTN then ws_style |= WS_MINIMIZEBOX;
    if style & .MAXIMIZEBTN then ws_style |= WS_MAXIMIZEBOX;
    if style & .RESIZABLE   then ws_style |= WS_THICKFRAME;
    return cast(u32) ws_style;
}

// Map Windows Virtual-Key Codes to our codes
// https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
conv_vk_key_code :: (wParam: WPARAM) -> Key_Code #no_context {
    // for Numbers windows use same as ours
    if (wParam >= 48) && (wParam <= 57) return cast(Key_Code) wParam;
    // A-Z windows use same as ours
    if (wParam >= 65) && (wParam <= 90) return cast(Key_Code) wParam;
    using Key_Code;
    // common keys first
    if wParam == {
        // arows
        case VK_UP;     return ARROW_UP;
        case VK_DOWN;   return ARROW_DOWN;
        case VK_LEFT;   return ARROW_LEFT;
        case VK_RIGHT;  return ARROW_RIGHT;
        // mods
        case VK_CONTROL;  return CONTROL;
        case VK_MENU;     return ALT;
        case VK_SHIFT;    return SHIFT;
        case VK_CAPITAL;  return CAPS_LOCK;
        // other
        case VK_INSERT;   return INSERT;
        case VK_HOME;     return HOME;
        case VK_END;      return END;
        case VK_NEXT;     return PAGE_UP;
        case VK_PRIOR;    return PAGE_DOWN;
        case VK_SNAPSHOT; return PRINT_SCREEN;
        case VK_PAUSE;    return PAUSE;
    }
    // Other Keys
    if wParam == {
        case VK_BACK;       return BACKSPACE;
        case VK_TAB;        return TAB;
        case VK_RETURN;     return ENTER;
        case VK_ESCAPE;     return ESCAPE;
        case VK_SPACE;      return SPACEBAR;
        case VK_OEM_7;      return APOSTROPHE; // '
        case VK_OEM_COMMA;  return COMMA;  // ,
        case VK_OEM_MINUS;  return MINUS;  // -
        case VK_OEM_PERIOD; return PERIOD; // .
        case VK_OEM_2;      return SLASH;  // /
        // numbers above ...
        case VK_OEM_1;      return SEMICOLON;  // ; 
        case VK_OEM_PLUS;   return EQUAL;      // = 
        // a-z above ...
        case VK_OEM_4;      return LEFT_BRACKET;   // [ 
        case VK_OEM_5;      return BACKSLASH;      // '\'
        case VK_OEM_6;      return RIGHT_BRACKET;  // ] 
        case VK_OEM_3;      return GRAVE_ACCENT;   // ` 
        case VK_DELETE;     return DELETE;
        // Non-ASCII table above ...
        // F1 - F12
        case VK_F1; return F1;
        case VK_F2; return F2;
        case VK_F3; return F3;
        case VK_F4; return F4;
        case VK_F5; return F5;
        case VK_F6; return F6;
        case VK_F7; return F7;
        case VK_F8; return F8;
        case VK_F9; return F9;
        case VK_F10; return F10;
        case VK_F11; return F11;
        case VK_F12; return F12;
    }
    return UNKNOWN;
}


conv_key_code :: (key_code: Key_Code) -> s32 #no_context {
    n := cast(s32) key_code;
    // for Numbers windows use same as ours
    if (n >= 48) && (n <= 57) return n;
    // A-Z windows use same as ours
    if (n >= 65) && (n <= 90) return n;
    using Key_Code;
    if key_code == {
        case MOUSE_LEFT;    return VK_LBUTTON;
        case MOUSE_MIDDLE;  return VK_MBUTTON;
        case MOUSE_RIGHT;   return VK_RBUTTON;
    }
    // common keys first
    if key_code == {
        // arows
        case ARROW_UP;     return VK_UP;
        case ARROW_DOWN;   return VK_DOWN;
        case ARROW_LEFT;   return VK_LEFT;
        case ARROW_RIGHT;  return VK_RIGHT;
        // mods
        case CONTROL;  return VK_CONTROL;
        case ALT;      return VK_MENU;
        case SHIFT;    return VK_SHIFT;
        case CAPS_LOCK;return VK_CAPITAL;
        // other
        case INSERT;   return VK_INSERT;
        case HOME;     return VK_HOME;
        case END;      return VK_END;
        case PAGE_UP;      return VK_NEXT;
        case PAGE_DOWN;    return VK_PRIOR;
        case PRINT_SCREEN; return VK_SNAPSHOT;
        case PAUSE;    return VK_PAUSE;
    }
    // Other Keys
    if key_code == {
        case BACKSPACE; return VK_BACK;
        case TAB;       return VK_TAB;
        case ENTER;     return VK_RETURN;
        case ESCAPE;    return VK_ESCAPE;
        case SPACEBAR;  return VK_SPACE;
        case APOSTROPHE; return VK_OEM_7; // '
        case COMMA;      return VK_OEM_COMMA;  // ,
        case MINUS;      return VK_OEM_MINUS;  // -
        case PERIOD;     return VK_OEM_PERIOD; // .
        case SLASH;      return VK_OEM_2;  // /
        // numbers above ...
        case SEMICOLON;  return VK_OEM_1;  // ; 
        case EQUAL;      return VK_OEM_PLUS;      // = 
        // a-z above ...
        case LEFT_BRACKET;  return VK_OEM_4;   // [ 
        case BACKSLASH;     return VK_OEM_5;      // '\'
        case RIGHT_BRACKET; return VK_OEM_6;  // ] 
        case GRAVE_ACCENT;  return VK_OEM_3;   // ` 
        case DELETE;        return VK_DELETE;
        // Non-ASCII table above ...
        // F1 - F12
        case F1; return VK_F1;
        case F2; return VK_F2;
        case F3; return VK_F3;
        case F4; return VK_F4;
        case F5; return VK_F5;
        case F6; return VK_F6;
        case F7; return VK_F7;
        case F8; return VK_F8;
        case F9; return VK_F9;
        case F10; return VK_F10;
        case F11; return VK_F11;
        case F12; return VK_F12;
    }
    return 0;
}