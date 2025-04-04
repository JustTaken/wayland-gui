package main

import "core:fmt"
import "core:mem"

main :: proc() {
  bytes: []u8
  wl: WaylandContext
  vk: VulkanContext
  arena: mem.Arena
  tmp_arena: mem.Arena

  width: u32 = 1920
  height: u32 = 1080

  if bytes = make([]u8, 1024 * 1024 * 100); bytes == nil do panic("Out of memory")
  defer delete(bytes)

  mem.arena_init(&arena, bytes)
  context.allocator = mem.arena_allocator(&arena)

  mem.arena_init(&tmp_arena, make([]u8, 1024 * 1024 * 50, context.allocator))
  context.temp_allocator = mem.arena_allocator(&tmp_arena)

  if !init_vulkan(&vk, 1920, 1080, &arena, &tmp_arena) do panic("Failed to initialize vulkan")
  defer deinit_vulkan(&vk)

  //if !draw(&vk) do panic("Failed to draw frame")
  if !init_wayland(&wl, width, height, &vk, &arena, &tmp_arena) do panic("Failed to initialize wayland")

  for render(&wl) { }
}
