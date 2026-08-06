#pragma once
#include <webgpu.h>
#include <wgpu_helpers.h>
#include <wgpu_render_helpers.h>

static WGPUCommandEncoder gpu_batch_begin(WGPUContext* ctx) {
    return wgpuDeviceCreateCommandEncoder(ctx->device, NULL);
}

static void gpu_batch_dispatch(WGPUCommandEncoder encoder, WGPUComputePipeline pipeline, WGPUBindGroup bind_group, uint32_t workgroup_count_x) {
    WGPUComputePassEncoder pass = wgpuCommandEncoderBeginComputePass(encoder, NULL);
    wgpuComputePassEncoderSetPipeline(pass, pipeline);
    wgpuComputePassEncoderSetBindGroup(pass, 0, bind_group, 0, NULL);
    wgpuComputePassEncoderDispatchWorkgroups(pass, workgroup_count_x, 1, 1);
    wgpuComputePassEncoderEnd(pass);
    wgpuComputePassEncoderRelease(pass);
}

static void gpu_batch_copy_buffer_to_buffer(WGPUCommandEncoder encoder, WGPUBuffer src, WGPUBuffer dst, uint64_t size) {
    wgpuCommandEncoderCopyBufferToBuffer(encoder, src, 0, dst, 0, size);
}

static void gpu_batch_copy_buffer_to_3d_texture(WGPUCommandEncoder encoder, WGPUBuffer buffer, uint64_t offset, WGPURenderTexture* rt, uint32_t dest_x, uint32_t dest_y, uint32_t dest_z, uint32_t width, uint32_t height, uint32_t depth) {
    WGPUTexelCopyTextureInfo destination = {
        .texture = rt->texture,
        .mipLevel = 0,
        .origin = { .x = dest_x, .y = dest_y, .z = dest_z },
        .aspect = WGPUTextureAspect_All,
    };

    WGPUTexelCopyBufferLayout data_layout = {
        .offset = offset,
        .bytesPerRow = width * 8, // RGBA16Float = 8 bytes per pixel
        .rowsPerImage = height,
    };

    WGPUTexelCopyBufferInfo source = {
        .buffer = buffer,
        .layout = data_layout,
    };

    WGPUExtent3D write_size = {
        .width = width,
        .height = height,
        .depthOrArrayLayers = depth,
    };

    wgpuCommandEncoderCopyBufferToTexture(encoder, &source, &destination, &write_size);
}

static void gpu_batch_end(WGPUContext* ctx, WGPUCommandEncoder encoder) {
    WGPUCommandBuffer cmd = wgpuCommandEncoderFinish(encoder, NULL);
    wgpuCommandEncoderRelease(encoder);
    wgpuQueueSubmit(ctx->queue, 1, &cmd);
    wgpuCommandBufferRelease(cmd);
}
