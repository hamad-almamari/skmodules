#scope_module

Backend_Native_Window      :: *void;

Backend_State :: struct {
    // base
    vk_backend_initialized: bool;
    vk_instance: VkInstance;
    vk_debug_callback_handle: VkDebugReportCallbackEXT;
    vk_adapters_info      : [] Adapter_Info;
    vk_adapters_info_data : [8] Adapter_Info; // we will store the data here
}

Backend_Adapter_Info       :: struct {}
Backend_Debug_Message_Type :: struct {}

dummy_adapters_info: [1] Adapter_Info;

vk_init_instance :: () -> bool {
    pullGs();
    if gs.vk_instance return true;
    #if DEBUG then vk_print_available_vulkan_extensions(); // TODO: report info

    result : VkResult = .ERROR_INITIALIZATION_FAILED;
    // Application Info
    app_info: VkApplicationInfo;
    app_info.pApplicationName   = "Vulkan sk_Gfx";
    app_info.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    app_info.pEngineName        = "sk_Gfx";
    app_info.engineVersion      = VK_MAKE_VERSION(1, 0, 0);
    app_info.apiVersion         = VK_API_VERSION_1_0;
    // Create Vulkan Instance
    create_info : VkInstanceCreateInfo;
    create_info.pApplicationInfo        = *app_info;
    #if !DEBUG {
        extensions: [2] *u8;
        extensions[0] = VK_KHR_SURFACE_EXTENSION_NAME.data;
        // @ToDo: Non-Windows version
        extensions[1] = VK_KHR_WIN32_SURFACE_EXTENSION_NAME.data;
    } else {
        extensions: [3] *u8;
        extensions[0] = VK_KHR_SURFACE_EXTENSION_NAME.data;
        // @ToDo: Non-Windows version
        extensions[1] = VK_KHR_WIN32_SURFACE_EXTENSION_NAME.data;
        extensions[2] = VK_EXT_DEBUG_REPORT_EXTENSION_NAME.data;
    }
    create_info.enabledExtensionCount   = extensions.count;
    create_info.ppEnabledExtensionNames = extensions.data;
    // init validationlayer
  #if DEBUG {
    debug_create_info := create_info;
    debug_create_info.enabledLayerCount   = 1;
    debug_create_info.ppEnabledLayerNames = (*u8).["VK_LAYER_LUNARG_standard_validation"].data;

    result = vkCreateInstance(*debug_create_info, null, *gs.vk_instance);
    if result == .SUCCESS {
        vkCreateDebugReportCallbackEXT  : PFN_vkCreateDebugReportCallbackEXT = xx vkGetInstanceProcAddr(gs.vk_instance, "vkCreateDebugReportCallbackEXT");
        vkDebugReportMessageEXT         : PFN_vkDebugReportMessageEXT = xx vkGetInstanceProcAddr(gs.vk_instance, "vkDebugReportMessageEXT");
        if vkCreateDebugReportCallbackEXT {
            debug_callback_create_info: VkDebugReportCallbackCreateInfoEXT;
            debug_callback_create_info.flags |= .ERROR_BIT_EXT;
            debug_callback_create_info.flags |= .WARNING_BIT_EXT;
            debug_callback_create_info.pfnCallback = vk_debug_callback;
            vkCreateDebugReportCallbackEXT(gs.vk_instance, *debug_callback_create_info, null, *gs.vk_debug_callback_handle);
        } else {
            report_debug_msg(.WARNING, "vkGetInstanceProcAddr failed, no vulkan errors will be reported.");
        }
    }
  }

    if result != .SUCCESS {
        result = vkCreateInstance(*create_info, null, *gs.vk_instance);
    }

    if result != .SUCCESS {
        report_debug_msg(.ERROR, "vkCreateInstance failed, result:%.", result);
        return false;
    }

    return result == .SUCCESS;
}

backend_get_available_adapters_info :: () -> [] Adapter_Info {
    pullGs();
    if !gs.vk_instance then vk_init_instance(); // TODO: Error
    dummy_adapters_info[0].adapter_index = 0;
    return dummy_adapters_info;
}

backend_init :: () -> bool {
    pullGs();
    if !gs.vk_instance then vk_init_instance(); // TODO: Error
    dummy_adapters_info[0].adapter_index = 0;
    return true;
}

backend_deinit :: () {
    pullGs();
    // deinit instance
    #if DEBUG {
        vkDestroyDebugReportCallbackEXT := cast(PFN_vkDestroyDebugReportCallbackEXT) vkGetInstanceProcAddr(gs.vk_instance, "vkDestroyDebugReportCallbackEXT");
        if vkDestroyDebugReportCallbackEXT && gs.vk_debug_callback_handle {
            vkDestroyDebugReportCallbackEXT(gs.vk_instance, gs.vk_debug_callback_handle, null);
        }
    }
    vkDestroyInstance(gs.vk_instance, null);
}

backend_execute :: () {
    pullGs();
    for encoder: gs.enc_storage {
        using encoder;
        if current_state == .INVALID break;   // this the last used one
        Basic.assert(current_state == .EXECUTABLE); // make sure it closed
        current_state = .INVALID;
    }
    // swap buffers
    for gs.swc_storage {
        if !it.swap_required continue;
        using it;
        active_buffer_index  = (active_buffer_index+1) % SWC_BUFFER_COUNT;;
        swap_required        = false;
    }
    // new frame ----------------------------------------------------
    gs.frame_counter += 1;
    // move to next frame
    gs.active_frame = (gs.active_frame+1) % FRAME_COUNT;
    // wait for the active frame on the host (the new acquired frame).
    if gs.frame_counter >= FRAME_COUNT {
        // wait ...
    }
}

backend_wait_idle :: () {

}

backend_report_backend_debug_msgs :: (loc: Source_Code_Location = #caller_location) #expand {

}

#load "backend_swap_chain.jai";
#load "backend_pipeline.jai";
#load "backend_encoder.jai";
#load "backend_resources.jai";

#scope_file
#import "Vulkan";

vk_print_available_vulkan_extensions :: () {
    extension_count: u32;
    vkEnumerateInstanceExtensionProperties(null, *extension_count, null);
    extension_array := Basic.NewArray(extension_count, VkExtensionProperties, allocator=Basic.temp);
    vkEnumerateInstanceExtensionProperties(null, *extension_count, extension_array.data);
    Basic.print("Available extensions:\n");
    for extension_array Basic.print("    % (%)\n", Basic.to_string(it.extensionName.data), it.specVersion);
}

vk_debug_callback :: (flags: VkDebugReportFlagsEXT, objType: VkDebugReportObjectTypeEXT, obj: u64, location: u64, code: s32, layerPrefix: *u8, msg: *u8, userData: *void) -> VkBool32 #c_call {
    new_context: Context;
    push_context new_context {
        Basic.print("VULKAN VALIDATION: %\n", msg);
    }
    return VK_FALSE;
}