
DXGI_FEATURE :: enum s32 {
    PRESENT_ALLOW_TEARING :: 0;
    DXGI_FEATURE_PRESENT_ALLOW_TEARING :: PRESENT_ALLOW_TEARING;
}

IDXGIFactory5_UUID :: "7632e1f5-ee65-4dca-87fd-84cd75f8838d";
IDXGIFactory5 :: struct {
    using idxgifactory4: IDXGIFactory4;
    #place vtable; idxgifactory5_vtable: *IDXGIFactory5_VTable;
}
IDXGIFactory5_VTable :: struct #type_info_none {
    using idxgifactory4: IDXGIFactory4_VTable;
    CheckFeatureSupport: (this: *IDXGIFactory5, Feature: DXGI_FEATURE, pFeatureSupportData: *void, FeatureSupportDataSize: u32) -> HRESULT #cpp_method;
}
IDXGIFactory5_CheckFeatureSupport :: inline (this: *IDXGIFactory5, Feature: DXGI_FEATURE, pFeatureSupportData: *void, FeatureSupportDataSize: u32) -> HRESULT { return this.idxgifactory5_vtable.CheckFeatureSupport(this, Feature, pFeatureSupportData, FeatureSupportDataSize); }

vtable :: (obj: *IDXGIFactory5) -> *IDXGIFactory5_VTable { return obj.idxgifactory5_vtable; }

DXGI_GPU_PREFERENCE :: enum s32 {
    UNSPECIFIED      :: 0;
    MINIMUM_POWER    :: 1;
    HIGH_PERFORMANCE :: 2;

    DXGI_GPU_PREFERENCE_UNSPECIFIED      :: UNSPECIFIED;
    DXGI_GPU_PREFERENCE_MINIMUM_POWER    :: MINIMUM_POWER;
    DXGI_GPU_PREFERENCE_HIGH_PERFORMANCE :: HIGH_PERFORMANCE;
}

IDXGIFactory6_UUID :: "c1b6694f-ff09-44a9-b03c-77900a0a1d17";
IDXGIFactory6 :: struct {
    using idxgifactory5: IDXGIFactory5;
    #place vtable; idxgifactory6_vtable: *IDXGIFactory6_VTable;
}
IDXGIFactory6_VTable :: struct #type_info_none {
    using idxgifactory5: IDXGIFactory5_VTable;
    EnumAdapterByGpuPreference: (this: *IDXGIFactory6, Adapter: u32, GpuPreference: DXGI_GPU_PREFERENCE, riid: *IID, ppvAdapter: **void) -> HRESULT #cpp_method;
}
IDXGIFactory6_EnumAdapterByGpuPreference :: inline (this: *IDXGIFactory6, Adapter: u32, GpuPreference: DXGI_GPU_PREFERENCE, riid: *IID, ppvAdapter: **void) -> HRESULT { return this.idxgifactory6_vtable.EnumAdapterByGpuPreference(this, Adapter, GpuPreference, riid, ppvAdapter); }

vtable :: (obj: *IDXGIFactory6) -> *IDXGIFactory6_VTable { return obj.idxgifactory6_vtable; }
