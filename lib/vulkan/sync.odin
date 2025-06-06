package vulk

import "lib:error"
import vk "vendor:vulkan"

@(private)
fence_create :: proc(ctx: ^Vulkan_Context) -> (vk.Fence, error.Error) {
  info := vk.FenceCreateInfo {
    sType = .FENCE_CREATE_INFO,
    flags = {.SIGNALED},
  }

  fence: vk.Fence
  if vk.CreateFence(ctx.device.handle, &info, nil, &fence) != .SUCCESS do return fence, .CreateFenceFailed

  return fence, nil
}

@(private)
semaphore_create :: proc(ctx: ^Vulkan_Context) -> (vk.Semaphore, error.Error) {
  info := vk.SemaphoreCreateInfo {
    sType = .SEMAPHORE_CREATE_INFO,
    flags = {},
  }

  semaphore: vk.Semaphore
  if vk.CreateSemaphore(ctx.device.handle, &info, nil, &semaphore) != .SUCCESS do return semaphore, .CreateSemaphoreFailed

  return semaphore, nil
}
