// MIT License

// Copyright (c) 2022 Hamad Almamari (hamad-r)

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// Good to know:
// This module not thread safe.

#module_parameters () (
    WINDOW_CREATION_COLOR := float.[.2,.2,.2]
);

#placeholder Window; // native window type

Window_Style :: enum_flags u32 {
    TOPBAR      :: 1;
    MINIMIZEBTN :: 2;
    MAXIMIZEBTN :: 4;
    RESIZABLE   :: 8;
    PRIMARY     :: TOPBAR | MINIMIZEBTN | MAXIMIZEBTN | RESIZABLE;
    SECONDARY   :: TOPBAR | RESIZABLE;
}

Event_Type :: enum u16 {
    INVALID           :: 0;
    WINDOW_CLOSED     :: 1;
    WINDOW_CREATED    :: 2;
    WINDOW_GAINFOCUS  :: 3;
    WINDOW_LOSTFOCUS  :: 4;
    WINDOW_RESIZED    :: 5;
    WINDOW_MINIMIZED  :: 6;
    WINDOW_MAXIMIZED  :: 7;
    INPUT             :: 10;
}

Input_Flags :: enum_flags u32 {
    KEYBOARD :: 1 << 1;
    MOUSE    :: 1 << 2;
    GAMEPAD  :: 1 << 3;
    START    :: 1 << 4; // the key is start being down
    DOWN     :: 1 << 5; // the key is down
    END      :: 1 << 6; // the key is not down anymore
    CONTROL  :: 1 << 7;
    ALT      :: 1 << 8;
    SHIFT    :: 1 << 9;
}

Event :: struct {
    type        : Event_Type;
    window      : Window;
    key_code    : Key_Code;
    input_flags : Input_Flags;
}

#load "key_code.jai";
#if OS == .WINDOWS {
    #load "windows.jai";
}

#scope_module
Basic     :: #import "Basic";
HashTable :: #import "Hash_Table";

// TODO?
// is_child_of
// is_parent_of
// is_closed
// is_hiden