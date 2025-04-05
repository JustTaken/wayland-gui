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
  frames: u32 = 2

  if bytes = make([]u8, 1024 * 1024 * 2); bytes == nil do panic("Out of memory")
  defer delete(bytes)

  mem.arena_init(&arena, bytes)
  context.allocator = mem.arena_allocator(&arena)

  mem.arena_init(&tmp_arena, make([]u8, 1024 * 1024 * 1, context.allocator))
  context.temp_allocator = mem.arena_allocator(&tmp_arena)

  if !init(&vk, &wl, width, height, frames, &arena, &tmp_arena) do panic("Failed to initialize")

  geometries := make([]^Geometry, 10, context.allocator)
  if !init_geometries(&vk, geometries) do panic("Failed to initialize geometries")

  loop(&vk, &wl, &arena, &tmp_arena)

  deinit_wayland(&wl)
  deinit_vulkan(&vk)

  fmt.println("TMP", tmp_arena.offset, tmp_arena.peak_used)
  fmt.println("MAIN", arena.offset - len(tmp_arena.data), arena.peak_used - len(tmp_arena.data))
}

init :: proc(vk: ^VulkanContext, wl: ^WaylandContext, width: u32, height: u32, frames: u32, arena: ^mem.Arena, tmp_arena: ^mem.Arena) -> bool {
  {
    mark := mem.begin_arena_temp_memory(tmp_arena)
    defer mem.end_arena_temp_memory(mark)
    init_vulkan(vk, 1920, 1080, frames, arena, tmp_arena) or_return
  }

  {
    mark := mem.begin_arena_temp_memory(tmp_arena)
    defer mem.end_arena_temp_memory(mark)
    init_wayland(wl, vk, width, height, frames, arena, tmp_arena) or_return
  }

  return true
}

loop :: proc(vk: ^VulkanContext, wl: ^WaylandContext, arena: ^mem.Arena, tmp_arena: ^mem.Arena) {
  for wl.running { 
    mark := mem.begin_arena_temp_memory(tmp_arena)
    defer mem.end_arena_temp_memory(mark)

    if !render(wl) {
      fmt.println("Failed to render frame")
    }
  }
}

init_geometries :: proc(vk: ^VulkanContext, geometries: []^Geometry) -> bool {
  triangle_vertices := [?]Vertex {
    { position = { -0.5, -0.5 } },
    { position = {  0.0,  0.5 } },
    { position = {  0.5, -0.5 } },
  }

  quad_vertices := [?]Vertex {
    { position = { -0.5, -0.5 } },
    { position = { -0.5,  0.5 } },
    { position = {  0.5, -0.5 } },
    { position = {  0.5, -0.5 } },
    { position = { -0.5,  0.5 } },
    { position = {  0.5,  0.5 } },
  }

  geometries[0] = add_geometry(vk, triangle_vertices[:], 1) or_return
  geometries[1] = add_geometry(vk, quad_vertices[:], 1) or_return

  add_geometry_instance(vk, geometries[0], Vertex { position = {  0.5, 0 } }) or_return
  add_geometry_instance(vk, geometries[1], Vertex { position = { -0.5, 0 } }) or_return

  return true
}
