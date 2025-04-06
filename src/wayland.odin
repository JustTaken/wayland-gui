package main

import wl "wayland"
import "core:os"
import "core:mem"
import "core:sys/posix"
import "core:path/filepath"
import "base:intrinsics"
import "base:runtime"

import "core:fmt"
import "core:time"

Vector :: struct(T: typeid) {
  data: []T,
  cap: u32,
  len: u32,
}

Callback :: proc(^WaylandContext, u32, []wl.Argument)
CallbackConfig :: struct {
  name: string,
  function: Callback,
}

InterfaceObject :: struct {
  interface: ^wl.Interface,
  callbacks: []Callback,
}

Buffer :: struct {
  data: []u8,
  id: u32,
  offset: u32,

  width: u32,
  height: u32,

  released: bool,
  bound: bool,

  frame: ^Frame,
  next: ^Buffer,
}

Modifier :: struct {
  format: u32,
  modifier: u64,
}

WaylandContext :: struct {
  socket: posix.FD,
  objects: Vector(InterfaceObject),
  output_buffer: Vector(u8),
  input_buffer: Vector(u8),
  values: Vector(wl.Argument),
  bytes: []u8,

  in_fds: []wl.Fd,
  in_fds_len: u32,
  in_fd_index: u32,

  out_fds: [^]wl.Fd,
  out_fds_len: u32,
  header: []u8,

  modifiers: Vector(Modifier),

  display_id: u32,
  registry_id: u32,
  compositor_id: u32,
  surface_id: u32,
  xdg_wm_base_id: u32,
  xdg_surface_id: u32,
  xdg_toplevel_id: u32,
  dma_id: u32,
  dma_feedback_id: u32,
  dma_params_id: u32,

  get_registry_opcode: u32,
  registry_bind_opcode: u32,
  create_surface_opcode: u32,
  surface_attach_opcode: u32,
  surface_commit_opcode: u32,
  surface_damage_opcode: u32,
  ack_configure_opcode: u32,
  get_xdg_surface_opcode: u32,
  get_toplevel_opcode: u32,
  pong_opcode: u32,
  destroy_buffer_opcode: u32,
  dma_destroy_opcode: u32,
  dma_create_param_opcode: u32,
  dma_surface_feedback_opcode: u32,
  dma_feedback_destroy_opcode: u32,
  dma_params_create_immed_opcode: u32,
  dma_params_add_opcode: u32,
  dma_params_destroy_opcode: u32,

  dma_main_device: u64,

  buffers: []Buffer,
  buffer: ^Buffer,

  width: u32,
  height: u32,
  running: bool,

  vk: ^VulkanContext,

  arena: ^mem.Arena,
  allocator: runtime.Allocator,

  tmp_arena: ^mem.Arena,
  tmp_allocator: runtime.Allocator,
}

init_wayland :: proc(ctx: ^WaylandContext, vk: ^VulkanContext, width: u32, height: u32, frame_count: u32, arena: ^mem.Arena, tmp_arena: ^mem.Arena) -> bool {
  ctx.arena = arena
  ctx.allocator = mem.arena_allocator(arena)
  ctx.tmp_arena = tmp_arena
  ctx.tmp_allocator = mem.arena_allocator(tmp_arena)

  ctx.vk = vk

  mark := mem.begin_arena_temp_memory(ctx.tmp_arena)
  defer mem.end_arena_temp_memory(mark)

  xdg_path := os.get_env("XDG_RUNTIME_DIR", allocator = ctx.tmp_allocator)
  wayland_path := os.get_env("WAYLAND_DISPLAY", allocator = ctx.tmp_allocator)

  if len(xdg_path) == 0 || len(wayland_path) == 0 {
    return false
  }

  path := filepath.join({ xdg_path, wayland_path }, ctx.tmp_allocator)
  ctx.socket = posix.socket(.UNIX, .STREAM)

  if ctx.socket < 0 {
    return false
  }

  sockaddr := posix.sockaddr_un {
    sun_family = .UNIX,
  }

  count: uint = 0
  for c in path {
    sockaddr.sun_path[count] = u8(c)
    count += 1
  }

  if posix.connect(ctx.socket, (^posix.sockaddr)(&sockaddr), posix.socklen_t(size_of(posix.sockaddr_un))) == .FAIL do return false

  resize(ctx, width, height)

  ctx.values = new_vec(wl.Argument, 40, ctx.allocator)
  ctx.objects = new_vec(InterfaceObject, 40, ctx.allocator)
  ctx.output_buffer = new_vec(u8, 4096, ctx.allocator)
  ctx.input_buffer = new_vec(u8, 4096, ctx.allocator)
  ctx.modifiers = new_vec(Modifier, 512, ctx.allocator)
  ctx.bytes = make([]u8, 1024, ctx.allocator)
  ctx.header = make([]u8, 512, ctx.allocator)
  ctx.out_fds = ([^]wl.Fd)(raw_data(ctx.header[mem.align_formula(size_of(posix.cmsghdr), size_of(uint)):]))
  ctx.out_fds_len = 0
  ctx.in_fds = make([]wl.Fd, 10, ctx.allocator)
  ctx.in_fds_len = 0
  ctx.in_fd_index = 0

  ctx.input_buffer.cap = 0
  ctx.running = true
  ctx.buffers = make([]Buffer, frame_count, ctx.allocator)
  ctx.buffer = &ctx.buffers[0]

  buffer := ctx.buffer
  for i in 1..<frame_count {
    buffer.next = &ctx.buffers[i]
    buffer = buffer.next
  }

  buffer.next = ctx.buffer

  ctx.display_id = get_id(ctx, "wl_display", { new_callback("error", error_callback), new_callback("delete_id", delete_callback) }, wl.WAYLAND_INTERFACES[:])
  ctx.registry_id = get_id(ctx, "wl_registry", { new_callback("global", global_callback), new_callback("global_remove", global_remove_callback) }, wl.WAYLAND_INTERFACES[:])
  ctx.get_registry_opcode = get_request_opcode(ctx, "get_registry", ctx.display_id)

  write(ctx, { wl.BoundNewId(ctx.registry_id) }, ctx.display_id, ctx.get_registry_opcode)
  send(ctx) or_return

  roundtrip(ctx)
  send(ctx) or_return
  roundtrip(ctx)

  init_buffers(ctx) or_return
  buffer_write_swap(ctx, ctx.buffer, ctx.width, ctx.height) or_return
  send(ctx) or_return

  return true
}

deinit_wayland :: proc(ctx: ^WaylandContext) {
}

render :: proc(ctx: ^WaylandContext) -> bool {
  time.sleep(time.Millisecond * 60)

  roundtrip(ctx)

  buffer_write_swap(ctx, ctx.buffer, ctx.width, ctx.height) or_return

  send(ctx) or_return

  return true
}

@(private="file")
resize :: proc(ctx: ^WaylandContext, width: u32, height: u32) {
  ctx.width = width
  ctx.height = height

  f_width := f32(width)
  f_height := f32(height)
  far := f32(11)
  near := f32(1)

  scale := matrix[4, 4]f32 {
    2 / f_width, 0, 0, 0,
    0, -2 / f_height, 0, 0,
    0, 0, 1 / (far - near), 0,
    0, 0, 0, 1,
  }

  // z = n => z * k + w = 0
  // z = f => z * k + w = 1

  // n * k = f * k - 1
  // k (f - n) = 1
  // k = 1 / (f - n)

  // 2w = 1 - k (n + f)
  // w = 1/2 - k (n + f) / 2
  // w = (1 - (n + f) / (f - n)) / 2
  // w = (f - n - n - f) / (2 * (f - n))
  // w = -n / (f - n)

  translate := matrix[4, 4]f32 {
    1, 0, 0, - f_width / 2,
    0, 1, 0, f_height / 2,
    0, 0, 1, - near / (far - near),
    0, 0, 1, 0,
  }

  update_projection(ctx.vk, scale * translate)
}

@(private="file")
roundtrip :: proc(ctx: ^WaylandContext) {
  recv(ctx)
  for read(ctx) {}
}

@(private="file")
create_surface :: proc(ctx: ^WaylandContext) {
  ctx.surface_id = get_id(ctx, "wl_surface", { new_callback("enter", enter_callback), new_callback("leave", leave_callback), new_callback("preferred_buffer_scale", preferred_buffer_scale_callback), new_callback("preferred_buffer_transform", preferred_buffer_transform_callback) }, wl.WAYLAND_INTERFACES[:])
  ctx.surface_attach_opcode = get_request_opcode(ctx, "attach", ctx.surface_id)
  ctx.surface_commit_opcode = get_request_opcode(ctx, "commit", ctx.surface_id)
  ctx.surface_damage_opcode = get_request_opcode(ctx, "damage", ctx.surface_id)

  write(ctx, { wl.BoundNewId(ctx.surface_id) }, ctx.compositor_id, ctx.create_surface_opcode)
  create_dma(ctx)
}

@(private="file")
create_xdg_surface :: proc(ctx: ^WaylandContext) {
  ctx.xdg_surface_id = get_id(ctx, "xdg_surface", { new_callback("configure", configure_callback) }, wl.XDG_INTERFACES[:])
  ctx.get_toplevel_opcode = get_request_opcode(ctx, "get_toplevel", ctx.xdg_surface_id)
  ctx.ack_configure_opcode = get_request_opcode(ctx, "ack_configure", ctx.xdg_surface_id)
  ctx.xdg_toplevel_id = get_id(ctx, "xdg_toplevel", { new_callback("configure", toplevel_configure_callback), new_callback("close", toplevel_close_callback), new_callback("configure_bounds", toplevel_configure_bounds_callback), new_callback("wm_capabilities", toplevel_wm_capabilities_callback) }, wl.XDG_INTERFACES[:])

  write(ctx, { wl.BoundNewId(ctx.xdg_surface_id), wl.Object(ctx.surface_id) }, ctx.xdg_wm_base_id, ctx.get_xdg_surface_opcode)
  write(ctx, { wl.BoundNewId(ctx.xdg_toplevel_id) }, ctx.xdg_surface_id, ctx.get_toplevel_opcode)

  write(ctx, { }, ctx.surface_id, ctx.surface_commit_opcode)
}

@(private="file")
create_dma :: proc(ctx: ^WaylandContext) {
    ctx.dma_feedback_id = get_id(ctx, "zwp_linux_dmabuf_feedback_v1", { new_callback("done", dma_done_callback), new_callback("format_table", dma_format_table_callback), new_callback("main_device", dma_main_device_callback), new_callback("tranche_done", dma_tranche_done_callback), new_callback("tranche_target_device", dma_tranche_target_device_callback), new_callback("tranche_formats", dma_tranche_formats_callback), new_callback("tranche_flags", dma_tranche_flags_callback), }, wl.DMA_INTERFACES[:])
    ctx.dma_feedback_destroy_opcode = get_request_opcode(ctx, "destroy", ctx.dma_feedback_id)
    write(ctx, { wl.BoundNewId(ctx.dma_feedback_id), wl.Object(ctx.surface_id) }, ctx.dma_id, ctx.dma_surface_feedback_opcode)
}

@(private="file")
buffer_write_swap :: proc(ctx: ^WaylandContext, buffer: ^Buffer, width: u32, height: u32) -> bool {
  if !buffer.released {
    fmt.println("Buffer is not ready")
    return false
  }

  defer buffer.released = false

  if buffer.width != width || buffer.height != height {
    if buffer.bound do write(ctx, { }, buffer.id, ctx.destroy_buffer_opcode)

    resize_frame(ctx.vk, buffer.frame, width, height) or_return
    create_buffer(ctx, buffer, width, height)
  }

  draw(ctx.vk, buffer.frame, width, height) or_return

  write(ctx, { wl.Object(buffer.id), wl.Int(0), wl.Int(0) }, ctx.surface_id, ctx.surface_attach_opcode)
  write(ctx, { wl.Int(0), wl.Int(0), wl.Int(width), wl.Int(height) }, ctx.surface_id, ctx.surface_damage_opcode)
  write(ctx, { }, ctx.surface_id, ctx.surface_commit_opcode)

  ctx.buffer = buffer.next

  return true
}

@(private="file")
init_buffers :: proc(ctx: ^WaylandContext) -> bool {
  base_id := get_id(ctx, "wl_buffer", { new_callback("release", buffer_release_callback) }, wl.WAYLAND_INTERFACES[:])
  ctx.destroy_buffer_opcode = get_request_opcode(ctx, "destroy", base_id)

  ctx.buffers[0].id = base_id
  for i in 0..<len(ctx.buffers) {
    buffer := &ctx.buffers[i]

    if i != 0 do buffer.id = copy_id(ctx, ctx.buffer.id)

    buffer.frame = get_frame(ctx.vk, buffer.id - base_id)
    buffer.released = true
    buffer.bound = false
    buffer.width = 0
    buffer.height = 0
  }

  return true
}

@(private="file")
create_buffer :: proc(ctx: ^WaylandContext, buffer: ^Buffer, width: u32, height: u32) {
    buffer.bound = true

    write(ctx, { wl.BoundNewId(ctx.dma_params_id) }, ctx.dma_id, ctx.dma_create_param_opcode)

    for i in 0..<buffer.frame.modifier.drmFormatModifierPlaneCount {
      plane := &buffer.frame.planes[i]
      modifier_hi := (buffer.frame.modifier.drmFormatModifier & 0xFFFFFFFF00000000) >> 32
      modifier_lo := buffer.frame.modifier.drmFormatModifier & 0x00000000FFFFFFFF

      write(ctx, { wl.Fd(buffer.frame.fd), wl.Uint(i), wl.Uint(plane.offset), wl.Uint(plane.rowPitch), wl.Uint(modifier_hi), wl.Uint(modifier_lo) }, ctx.dma_params_id, ctx.dma_params_add_opcode)
    }

    buffer.width = width
    buffer.height = height

    format := drm_format(ctx.vk.format)

    write(ctx, { wl.BoundNewId(buffer.id), wl.Int(width), wl.Int(height), wl.Uint(format), wl.Uint(0) }, ctx.dma_params_id, ctx.dma_params_create_immed_opcode)
    write(ctx, { }, ctx.dma_params_id, ctx.dma_params_destroy_opcode)
}

@(private="file")
write :: proc(ctx: ^WaylandContext, arguments: []wl.Argument, object_id: u32, opcode: u32) {
  object := get_object(ctx, object_id)
  request := get_request(object, opcode)
  //fmt.println("->", object.interface.name, object_id, opcode, request.name, arguments)

  start: = ctx.output_buffer.len

  vec_append_generic(&ctx.output_buffer, u32, object_id)
  vec_append_generic(&ctx.output_buffer, u16, u16(opcode))

  total_len := vec_reserve(&ctx.output_buffer, u16)

  for kind, i in request.arguments {
    #partial switch kind {
    case .BoundNewId: vec_append_generic(&ctx.output_buffer, wl.BoundNewId, arguments[i].(wl.BoundNewId))
    case .Uint: vec_append_generic(&ctx.output_buffer, wl.Uint, arguments[i].(wl.Uint))
    case .Int: vec_append_generic(&ctx.output_buffer, wl.Int, arguments[i].(wl.Int))
    case .Fixed: vec_append_generic(&ctx.output_buffer, wl.Fixed, arguments[i].(wl.Fixed))
    case .Object: vec_append_generic(&ctx.output_buffer, wl.Object, arguments[i].(wl.Object))
    case .UnBoundNewId: 
      value := arguments[i].(wl.UnBoundNewId)
      l := len(value.interface)
      vec_append_generic(&ctx.output_buffer, u32, u32(l))
      vec_append_n(&ctx.output_buffer, ([]u8)(value.interface))
      vec_add_n(&ctx.output_buffer, u32(mem.align_formula(l, size_of(u32)) - l))
      vec_append_generic(&ctx.output_buffer, wl.Uint, value.version)
      vec_append_generic(&ctx.output_buffer, wl.BoundNewId, value.id)
    case .Fd: insert_fd(ctx, arguments[i].(wl.Fd))
    case:
    }
  }

  intrinsics.unaligned_store(total_len, u16(ctx.output_buffer.len - start))
}

@(private="file")
read :: proc(ctx: ^WaylandContext) -> bool {
  ctx.values.len = 0
  bytes_len: u32 = 0

  start := ctx.input_buffer.len
  object_id := vec_read(&ctx.input_buffer, u32) or_return
  opcode := vec_read(&ctx.input_buffer, u16) or_return
  size := vec_read(&ctx.input_buffer, u16) or_return

  object := get_object(ctx, object_id)
  event := get_event(object, u32(opcode))

  for kind in event.arguments {
    #partial switch kind {
      case .Object: if !read_and_write(ctx, wl.Object) do return false
      case .Uint: if !read_and_write(ctx, wl.Uint) do return false
      case .Int: if !read_and_write(ctx, wl.Int) do return false
      case .Fixed: if !read_and_write(ctx, wl.Fixed) do return false
      case .BoundNewId: if !read_and_write(ctx, wl.BoundNewId) do return false
      case .String: if !read_and_write_collection(ctx, wl.String, &bytes_len) do return false
      case .Array: if !read_and_write_collection(ctx, wl.Array, &bytes_len) do return false
      case .Fd: if !read_fd_and_write(ctx) do return false
      case: return false
    }
  }

  if ctx.input_buffer.len - start != u32(size) do return false

  values := ctx.values.data[0:ctx.values.len]
  //fmt.println("<-", object.interface.name, size, object_id, opcode, event.name, values)
  object.callbacks[opcode](ctx, object_id, values)

  return true
}

@(private="file")
read_and_write :: proc(ctx: ^WaylandContext, $T: typeid) -> bool {
  value := vec_read(&ctx.input_buffer, T) or_return
  vec_append(&ctx.values, value)

  return true
}

@(private="file")
read_fd_and_write :: proc(ctx: ^WaylandContext) -> bool {
  vec_append(&ctx.values, ctx.in_fds[ctx.in_fd_index])
  return true
}

@(private="file")
read_and_write_collection :: proc(ctx: ^WaylandContext, $T: typeid, length_ptr: ^u32) -> bool {
  start := length_ptr^

  length := vec_read(&ctx.input_buffer, u32) or_return
  bytes := vec_read_n(&ctx.input_buffer, u32(mem.align_formula(int(length), size_of(u32))))

  if bytes == nil {
    return false
  }

  copy(ctx.bytes[start:], bytes)
  vec_append(&ctx.values, T(ctx.bytes[start:length]))
  length_ptr^ += length

  return true
}

@(private="file")
recv :: proc(ctx: ^WaylandContext) {
  iovec := posix.iovec {
    iov_base = raw_data(ctx.input_buffer.data),
    iov_len = 4096,
  }

  t_size := size_of(posix.FD)
  t_align := mem.align_formula(t_size * 10, size_of(uint))
  cmsg_align := mem.align_formula(size_of(posix.cmsghdr), size_of(uint))

  buf := make([]u8, cmsg_align + t_align, ctx.tmp_allocator)

  msg := posix.msghdr {
    msg_iov = &iovec,
    msg_iovlen = 1,
    msg_control = raw_data(buf),
    msg_controllen = len(buf)
  }

  count := posix.recvmsg(ctx.socket, &msg, { })
  alig := u32(mem.align_formula(size_of(posix.cmsghdr), size_of(uint)))
  cmsg := (^posix.cmsghdr)(msg.msg_control)
  ctx.in_fd_index = 0

  if cmsg.cmsg_len > 0 {
    ctx.in_fds_len = (u32(cmsg.cmsg_len) - alig) / size_of(wl.Fd)
    for i in 0..<ctx.in_fds_len {
      ctx.in_fds[i] = intrinsics.unaligned_load((^wl.Fd)(raw_data(buf[alig + size_of(wl.Fd) * i:])))
    }
  }

  ctx.input_buffer.cap = u32(count)
  ctx.input_buffer.len = 0
}

@(private="file")
insert_fd :: proc(ctx: ^WaylandContext, fd: wl.Fd) {
  ctx.out_fds[ctx.out_fds_len] = fd
  ctx.out_fds_len += 1
}

@(private="file")
send :: proc(ctx: ^WaylandContext) -> bool {
  if ctx.output_buffer.len == 0 {
    return true
  }

  io := posix.iovec {
    iov_base = raw_data(ctx.output_buffer.data),
    iov_len = uint(ctx.output_buffer.len),
  }

  cmsg_align := mem.align_formula(size_of(posix.cmsghdr), size_of(uint))
  fd_size := ctx.out_fds_len * size_of(wl.Fd)

  socket_msg := posix.msghdr {
    msg_name = nil,
    msg_namelen = 0,
    msg_iov = &io,
    msg_iovlen = 1,
    msg_control = raw_data(ctx.header),
    msg_controllen = uint(cmsg_align + mem.align_formula(int(fd_size), size_of(uint))),
    msg_flags = {},
  }

  cmsg := (^posix.cmsghdr)(socket_msg.msg_control)
  cmsg.cmsg_len = uint(cmsg_align) + uint(fd_size)
  cmsg.cmsg_type = posix.SCM_RIGHTS
  cmsg.cmsg_level = posix.SOL_SOCKET

  if posix.sendmsg(ctx.socket, &socket_msg, { }) < 0 {
    return false
  }

  ctx.output_buffer.len = 0
  ctx.out_fds_len = 0

  return true
}

@(private="file")
ctx_append :: proc(ctx: ^WaylandContext, callbacks: []CallbackConfig, interface: ^wl.Interface) {
  if len(callbacks) != len(interface.events) {
    panic("Incorrect callback length")
  }

  object: InterfaceObject
  object.interface = interface
  object.callbacks = make([]Callback, len(callbacks), ctx.allocator)

  for callback in callbacks {
    opcode := get_event_opcode(interface, callback.name)
    object.callbacks[opcode] = callback.function
  }

  vec_append(&ctx.objects, object)
}

@(private="file")
get_object :: proc(ctx: ^WaylandContext, id: u32) -> InterfaceObject {
  if len(ctx.objects.data) < int(id) {
    panic("OBject out of bounds")
  }

  return ctx.objects.data[id - 1]
}

@(private="file")
get_id :: proc(ctx: ^WaylandContext, name: string, callbacks: []CallbackConfig, interfaces: []wl.Interface) -> u32 {
  for &inter in interfaces {
    if inter.name == name {
      defer ctx_append(ctx, callbacks, &inter)
      return ctx.objects.len + 1
    }
  }

  panic("interface id  not found")
}

@(private="file")
copy_id :: proc(ctx: ^WaylandContext, id: u32) -> u32 {
  defer vec_append(&ctx.objects, get_object(ctx, id))
  return ctx.objects.len + 1
}

@(private="file")
get_event :: proc(object: InterfaceObject, opcode: u32) -> ^wl.Event {
  if len(object.interface.events) <= int(opcode) {
    panic("Request out of bounds")
  }
  return &object.interface.events[opcode]
}

@(private="file")
get_request :: proc(object: InterfaceObject, opcode: u32) -> ^wl.Request {
  if len(object.interface.requests) <= int(opcode) {
    panic("Request out of bounds")
  }

  return &object.interface.requests[opcode]
}

@(private="file")
get_event_opcode :: proc(interface: ^wl.Interface, name: string) -> u32 {
  for event, i in interface.events {
    if event.name == name {
      return u32(i)
    }
  }

  panic("event  opcode not found")
}

@(private="file")
get_request_opcode :: proc(ctx: ^WaylandContext, name: string, object_id: u32) -> u32 {
  requests := get_object(ctx, object_id).interface.requests

  for request, i in requests {
    if request.name == name {
      return u32(i)
    }
  }
  
  panic("request opcode not found")
}

@(private="file")
new_callback :: proc(name: string, callback: Callback) -> CallbackConfig {
  return CallbackConfig {
    name = name,
    function = callback,
  }
}

@(private="file")
global_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  str := arguments[1].(wl.String)
  version := arguments[2].(wl.Uint)
  interface_name := string(str[0:len(str) - 1])

  switch interface_name {
  case "xdg_wm_base":
    ctx.xdg_wm_base_id = get_id(ctx, interface_name, { new_callback("ping", ping_callback) }, wl.XDG_INTERFACES[:])
    ctx.pong_opcode = get_request_opcode(ctx, "pong", ctx.xdg_wm_base_id)
    ctx.get_xdg_surface_opcode = get_request_opcode(ctx, "get_xdg_surface", ctx.xdg_wm_base_id)

    write(ctx, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(ctx.xdg_wm_base_id), interface = str, version = version }}, ctx.registry_id, ctx.registry_bind_opcode)
    create_xdg_surface(ctx)
  case "wl_compositor":
    ctx.compositor_id = get_id( ctx, interface_name, { } , wl.WAYLAND_INTERFACES[:])
    ctx.create_surface_opcode = get_request_opcode(ctx, "create_surface", ctx.compositor_id)

    write(ctx, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(ctx.compositor_id), interface = str, version = version }}, ctx.registry_id, ctx.registry_bind_opcode)
    create_surface(ctx)
  case "zwp_linux_dmabuf_v1":
    ctx.dma_id = get_id(ctx, interface_name, { new_callback("format", dma_format_callback), new_callback("modifier", dma_modifier_callback) }  , wl.DMA_INTERFACES[:])
    ctx.dma_destroy_opcode = get_request_opcode(ctx, "destroy", ctx.dma_id)
    ctx.dma_create_param_opcode = get_request_opcode(ctx, "create_params", ctx.dma_id)
    ctx.dma_surface_feedback_opcode = get_request_opcode(ctx, "get_surface_feedback", ctx.dma_id)

    write(ctx, { arguments[0], wl.UnBoundNewId{ id = wl.BoundNewId(ctx.dma_id), interface = str, version = version }}, ctx.registry_id, ctx.registry_bind_opcode)
  }
}

@(private="file")
global_remove_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {}

@(private="file")
dma_modifier_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {}
@(private="file")
dma_format_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {}

@(private="file")
configure_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  write(ctx, { arguments[0] }, id, ctx.ack_configure_opcode)
}

@(private="file")
ping_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  write(ctx, { arguments[0] }, ctx.xdg_wm_base_id, ctx.pong_opcode)
}

@(private="file")
toplevel_configure_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  width := u32(arguments[0].(wl.Int))
  height := u32(arguments[1].(wl.Int))

  if width == 0 || height == 0 do return
  if width == ctx.width && height == ctx.height do return

  resize(ctx, width, height)
}

@(private="file")
toplevel_close_callback :: proc(ctx: ^WaylandContext, id: u32, arugments: []wl.Argument) {
  ctx.running = false
}

@(private="file")
toplevel_configure_bounds_callback :: proc(ctx: ^WaylandContext, id: u32, arugments: []wl.Argument) {}
@(private="file")
toplevel_wm_capabilities_callback :: proc(ctx: ^WaylandContext, id: u32, arugments: []wl.Argument) {}

@(private="file")
buffer_release_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  ctx.buffers[id - ctx.buffers[0].id].released = true
}

@(private="file")
enter_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {}
@(private="file")
leave_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {}
@(private="file")
preferred_buffer_scale_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {}
@(private="file")
preferred_buffer_transform_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {}

@(private="file")
dma_format_table_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  fd := posix.FD(arguments[0].(wl.Fd))
  size := u32(arguments[1].(wl.Uint))

  buf := ([^]u8)(posix.mmap(nil, uint(size), { .READ }, { .PRIVATE }, fd, 0))[0:size]

  if buf == nil do return

  format_size: u32 = size_of(u32)
  modifier_size: u32 = size_of(u64)
  tuple_size := u32(mem.align_formula(int(format_size + modifier_size), int(modifier_size)))

  count := size / tuple_size
  for i in 0..<count {
    offset := u32(i) * tuple_size

    format := intrinsics.unaligned_load((^u32)(raw_data(buf[offset:][0:format_size])))
    modifier := intrinsics.unaligned_load((^u64)(raw_data(buf[offset + modifier_size:][0:modifier_size])))

    mod := Modifier {
      format = format,
      modifier = modifier
    }

    vec_append(&ctx.modifiers, mod)
  }
}

@(private="file")
dma_main_device_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  ctx.dma_main_device = intrinsics.unaligned_load((^u64)(raw_data(arguments[0].(wl.Array))))
}

@(private="file")
dma_done_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  write(ctx, {}, id, ctx.dma_feedback_destroy_opcode)
}

@(private="file")
dma_tranche_target_device_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {}
@(private="file")
dma_tranche_flags_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {}
@(private="file")
dma_tranche_formats_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  array := arguments[0].(wl.Array)
  indices := ([^]u16)(raw_data(array))[0:len(array) / 2]

  l: u32 = 0
  modifiers := ctx.modifiers
  ctx.modifiers.len = 0

  for i in indices {
    vec_append(&ctx.modifiers, modifiers.data[i])
  }
}

@(private="file")
dma_tranche_done_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  ctx.dma_params_id = get_id(ctx, "zwp_linux_buffer_params_v1", { new_callback("created", param_created_callback), new_callback("failed", param_failed_callback)}, wl.DMA_INTERFACES[:])
  ctx.dma_params_create_immed_opcode = get_request_opcode(ctx, "create_immed", ctx.dma_params_id)
  ctx.dma_params_add_opcode = get_request_opcode(ctx, "add", ctx.dma_params_id)
  ctx.dma_params_destroy_opcode = get_request_opcode(ctx, "destroy", ctx.dma_params_id)
}

@(private="file")
param_created_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) { }

@(private="file")
param_failed_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) { 
  panic("Failed to create dma buf server side")
}

@(private="file")
delete_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {}

@(private="file")
error_callback :: proc(ctx: ^WaylandContext, id: u32, arguments: []wl.Argument) {
  fmt.println("error:", string(arguments[2].(wl.String)))
}

@(private="file")
new_vec :: proc($T: typeid, cap: u32, allocator: runtime.Allocator) -> Vector(T) {
  vec: Vector(T)
  vec.data = make([]T, cap, allocator)
  vec.cap = cap
  vec.len = 0

  return vec
}

@(private="file")
vec_append :: proc(vec: ^Vector($T), item: T) {
  if vec.len >= vec.cap {
    panic("Out of bounds")
  }

  vec.data[vec.len] = item
  vec.len += 1
}

@(private="file")
vec_append_n :: proc(vec: ^Vector($T), items: []T) {
  if vec.len + u32(len(items)) > vec.cap {
    panic("Out of bounds")
  }

  defer vec.len += u32(len(items))

  copy(vec.data[vec.len:], items)
}

@(private="file")
vec_add_n :: proc(vec: ^Vector($T), count: u32) {
  if vec.len + count > vec.cap {
    panic("Out of bounds")
  }

  vec.len += count
}

@(private="file")
vec_read :: proc(vec: ^Vector(u8), $T: typeid) -> (T, bool) {
  value: T
  if vec.len + size_of(T) > vec.cap {
    return value, false
  }

  defer vec.len += size_of(T)
  value = intrinsics.unaligned_load((^T)(raw_data(vec.data[vec.len:])))
  return value, true
}

@(private="file")
vec_read_n :: proc(vec: ^Vector(u8), count: u32) -> []u8 {
  if vec.len + count > vec.cap {
    return nil
  }

  defer vec.len += count
  return vec.data[vec.len:vec.len + count]
}

@(private="file")
vec_append_generic :: proc(vec: ^Vector(u8), $T: typeid, item: T) {
  if vec.len + size_of(T) > vec.cap {
    panic("Out of bounds")
  }

  defer vec.len += size_of(T)
  intrinsics.unaligned_store((^T)(raw_data(vec.data[vec.len:])), item)
}

@(private="file")
vec_reserve :: proc(vec: ^Vector(u8), $T: typeid) -> ^T {
  if vec.len + size_of(T) > vec.cap {
    panic("Out of bounds")
  }

  defer vec.len += size_of(T)
  return (^T)(raw_data(vec.data[vec.len:]))
}

