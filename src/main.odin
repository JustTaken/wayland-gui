package main

import vk "vendor:vulkan"
import "core:os"
import "core:fmt"
import "core:dynlib"

library: dynlib.Library

Context :: struct {
	instance: vk.Instance,
  device:   vk.Device,
	command_pool: vk.CommandPool,
	command_buffers: []vk.CommandBuffer,
}

DEVICE_EXTENSIONS := [?]cstring{
  "VK_EXT_image_drm_format_modifier",
  "VK_KHR_external_memory_fd",
  //"VK_EXT_external_memory_dma_buf",
}

VALIDATION_LAYERS := [?]cstring{
  "VK_LAYER_KHRONOS_validation",
}

main :: proc() {
	ctx: Context

  ok: bool
  if library, ok = dynlib.load_library("libvulkan.so"); !ok {
      fmt.println("Failed to load vulkan library")
      return
  }

  defer _ = dynlib.unload_library(library)
  vk.load_proc_addresses_custom(load_fn)

  init_vulkan(&ctx)
}

init_vulkan :: proc(ctx: ^Context) -> bool {
  instance := create_instance() or_return
	defer vk.DestroyInstance(instance, nil)

	physical_device := find_physical_device(instance, { check_physical_device_ext_support }) or_return
  queue_indices := find_queue_indices(physical_device) or_return

  device := create_device(physical_device, queue_indices) or_return
  defer vk.DestroyDevice(device, nil)

  queues := create_queues(device, queue_indices)

  modifiers_array := make([]u64, 20)
  modifiers := get_drm_modifiers(physical_device, .B8G8R8A8_SRGB, modifiers_array)

  image, memory := create_image(device, physical_device, .B8G8R8A8_SRGB, .D2, .DRM_FORMAT_MODIFIER_EXT, { .COLOR_ATTACHMENT }, {}, modifiers, 800, 600) or_return
  defer vk.DestroyImage(device, image, nil)
  defer vk.FreeMemory(device, memory, nil)

  //properties := vk.ImageDrmFormatModifierPropertiesEXT {
  //  sType = .IMAGE_DRM_FORMAT_MODIFIER_PROPERTIES_EXT,
  //}
  //vk.GetImageDrmFormatModifierPropertiesEXT(device, image, &properties)

  //fmt.println(properties)

  return true
}

create_instance :: proc() -> (vk.Instance, bool) {
  layer_count: u32
  vk.EnumerateInstanceLayerProperties(&layer_count, nil)
  layers := make([]vk.LayerProperties, layer_count)
  vk.EnumerateInstanceLayerProperties(&layer_count, raw_data(layers))

  check :: proc(v: cstring, availables: []vk.LayerProperties) -> bool {
    for &available in availables do if v == cstring(&available.layerName[0]) do return true

    return false
  }
  
  instance: vk.Instance
  for name in VALIDATION_LAYERS do if !check(name, layers) do return instance, false
  
	app_info := vk.ApplicationInfo {
    sType = .APPLICATION_INFO,
    pApplicationName = "Hello Triangle",
    applicationVersion = vk.MAKE_VERSION(0, 0, 1),
    pEngineName = "No Engine",
    engineVersion = vk.MAKE_VERSION(1, 0, 0),
    apiVersion = vk.API_VERSION_1_4,
  }

	create_info := vk.InstanceCreateInfo {
    sType = .INSTANCE_CREATE_INFO,
    pApplicationInfo = &app_info,
    ppEnabledLayerNames = &VALIDATION_LAYERS[0],
    enabledLayerCount = len(VALIDATION_LAYERS),
  }
	
	if vk.CreateInstance(&create_info, nil, &instance) != .SUCCESS do return instance, false
	
  fmt.println("Instance Created")
  vk.load_proc_addresses_instance(instance)

  return instance, true
}

get_drm_modifiers :: proc(physical_device: vk.PhysicalDevice, format: vk.Format, modifiers: []u64) -> []u64 {
  l: u32 = 0
  render_features: vk.FormatFeatureFlags = { .COLOR_ATTACHMENT, .COLOR_ATTACHMENT_BLEND }
  texture_features: vk.FormatFeatureFlags = { .SAMPLED_IMAGE, .SAMPLED_IMAGE_FILTER_LINEAR }

  modifier_properties_list := vk.DrmFormatModifierPropertiesListEXT {
    sType = .DRM_FORMAT_MODIFIER_PROPERTIES_LIST_EXT,
  }

  properties := vk.FormatProperties2 {
    sType = .FORMAT_PROPERTIES_2,
    pNext = &modifier_properties_list,
  }

  vk.GetPhysicalDeviceFormatProperties2(physical_device, format, &properties)
  count := modifier_properties_list.drmFormatModifierCount

  drmFormatModifierProperties := make([]vk.DrmFormatModifierPropertiesEXT, count)
  modifier_properties_list.pDrmFormatModifierProperties = &drmFormatModifierProperties[0]

  vk.GetPhysicalDeviceFormatProperties2(physical_device, format, &properties)

  image_modifier_info := vk.PhysicalDeviceImageDrmFormatModifierInfoEXT {
    sType = .PHYSICAL_DEVICE_IMAGE_DRM_FORMAT_MODIFIER_INFO_EXT,
    sharingMode = .EXCLUSIVE,
  }

  external_image_info := vk.PhysicalDeviceExternalImageFormatInfo {
    sType = .PHYSICAL_DEVICE_EXTERNAL_IMAGE_FORMAT_INFO,
    pNext = &image_modifier_info,
    handleType = { .DMA_BUF_EXT },
  }

  image_info := vk.PhysicalDeviceImageFormatInfo2 {
    sType = .PHYSICAL_DEVICE_IMAGE_FORMAT_INFO_2,
    pNext = &external_image_info,
    format = format,
    type = .D2,
    tiling = .DRM_FORMAT_MODIFIER_EXT,
  }

  external_image_properties := vk.ExternalImageFormatProperties {
    sType = .EXTERNAL_IMAGE_FORMAT_PROPERTIES,
  }

  image_properties := vk.ImageFormatProperties2 {
    sType = .IMAGE_FORMAT_PROPERTIES_2,
    pNext = &external_image_properties,
  }

  emp := &external_image_properties.externalMemoryProperties

  for i in 0..<count {
    modifier_properties := modifier_properties_list.pDrmFormatModifierProperties[i]
    image_modifier_info.drmFormatModifier = modifier_properties.drmFormatModifier

    if modifier_properties.drmFormatModifierTilingFeatures < render_features do continue
    if modifier_properties.drmFormatModifierTilingFeatures < texture_features do continue

    image_info.usage = { .COLOR_ATTACHMENT }

    if vk.GetPhysicalDeviceImageFormatProperties2(physical_device, &image_info, &image_properties) != .SUCCESS do continue
    if emp.externalMemoryFeatures < { .IMPORTABLE, .EXPORTABLE } do continue

    image_info.usage = { .SAMPLED }

    if vk.GetPhysicalDeviceImageFormatProperties2(physical_device, &image_info, &image_properties) != .SUCCESS do continue
    if emp.externalMemoryFeatures < { .IMPORTABLE, .EXPORTABLE } do continue

    modifiers[l] = modifier_properties.drmFormatModifier
    l += 1
  }

  return modifiers[0:l]
}

check_physical_device_ext_support :: proc(physical_device: vk.PhysicalDevice) -> bool {
	count: u32

	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &count, nil)
	available_extensions := make([]vk.ExtensionProperties, count)
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &count, &available_extensions[0])

  check :: proc(e: cstring, availables: []vk.ExtensionProperties) -> bool {
    for &available in availables do if e == cstring(&available.extensionName[0]) do return true

    fmt.println("extension", e, "not available")

    return false
  }

  for ext in DEVICE_EXTENSIONS do if !check(ext, available_extensions) do return false
  
	return true
}

find_physical_device :: proc(instance: vk.Instance, checks: []proc(vk.PhysicalDevice) -> bool) -> (vk.PhysicalDevice, bool) {
  physical_device: vk.PhysicalDevice
	device_count: u32
	
	vk.EnumeratePhysicalDevices(instance, &device_count, nil)

	if device_count == 0 do return physical_device, false

	devices := make([]vk.PhysicalDevice, device_count)
	vk.EnumeratePhysicalDevices(instance, &device_count, raw_data(devices))
	
	suitability :: proc(dev: vk.PhysicalDevice, checks: []proc(vk.PhysicalDevice) -> bool) -> u32 {
		props: vk.PhysicalDeviceProperties
		features: vk.PhysicalDeviceFeatures

		vk.GetPhysicalDeviceProperties(dev, &props)
		vk.GetPhysicalDeviceFeatures(dev, &features)
		
		score: u32 = 10
		if props.deviceType == .DISCRETE_GPU do score += 1000

    fmt.println(cstring(&props.deviceName[0]))

    for check in checks do if !check(dev) do return 0

		return score + props.limits.maxImageDimension2D
	}
	
	hiscore: u32 = 0
	for dev in devices {
		score := suitability(dev, checks)
		if score > hiscore {
			physical_device = dev
			hiscore = score
		}
	}
	
	if hiscore == 0 do return physical_device, false

  return physical_device, true
}

create_device :: proc(physical_device: vk.PhysicalDevice, indices: [2]u32) -> (vk.Device, bool) {
	
	queue_priority := f32(1.0)

	unique_indices: [10]u32 = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
	for i in indices do unique_indices[i] += 1

	queue_create_infos: [dynamic]vk.DeviceQueueCreateInfo
	defer delete(queue_create_infos)

	for k, i in unique_indices {
    if k == 0 do continue

		queue_create_info := vk.DeviceQueueCreateInfo {
      sType = .DEVICE_QUEUE_CREATE_INFO,
      queueFamilyIndex = u32(i),
      queueCount = 1,
      pQueuePriorities = &queue_priority,
    }

		append(&queue_create_infos, queue_create_info)
	}
	
	device_create_info := vk.DeviceCreateInfo {
    sType = .DEVICE_CREATE_INFO,
    enabledExtensionCount = u32(len(DEVICE_EXTENSIONS)),
    ppEnabledExtensionNames = &DEVICE_EXTENSIONS[0],
    pQueueCreateInfos = &queue_create_infos[0],
    queueCreateInfoCount = u32(len(queue_create_infos)),
    pEnabledFeatures = nil,
    enabledLayerCount = 0,
  }

  device: vk.Device
	if vk.CreateDevice(physical_device, &device_create_info, nil, &device) != .SUCCESS do return device, false

  fmt.println("Device Created")
  vk.load_proc_addresses_device(device)

  return device, true
}

create_queues :: proc(device: vk.Device, queue_indices: [2]u32) -> [2]vk.Queue {
  queues: [2]vk.Queue

	for &q, i in &queues {
		vk.GetDeviceQueue(device, u32(queue_indices[i]), 0, &q)
	}

  fmt.println("Queues Created")

  return queues
}

find_queue_indices :: proc(physical_device: vk.PhysicalDevice) -> ([2]u32, bool) {
	queue_count: u32

	vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_count, nil)
	available_queues := make([]vk.QueueFamilyProperties, queue_count)
	vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_count, raw_data(available_queues))

  MAX: u32 = 0xFF
  indices: [2]u32 = { MAX, MAX }
	
  for v, i in available_queues {
    if .GRAPHICS in v.queueFlags && indices[0] == MAX do indices[0] = u32(i)
    if .TRANSFER in v.queueFlags && indices[1] == MAX do indices[1] = u32(i)
  }

  for indice in indices {
    if indice == MAX do return indices, false
  }

  return indices, true
}

create_shader_module :: proc(device: vk.Device, code: []u8) -> (vk.ShaderModule, bool) {
	create_info := vk.ShaderModuleCreateInfo {
    sType = .SHADER_MODULE_CREATE_INFO,
    codeSize = len(code),
    pCode = cast(^u32)raw_data(code),
  }
	
	shader: vk.ShaderModule
	if res := vk.CreateShaderModule(device, &create_info, nil, &shader); res != .SUCCESS do return shader, false
	
	return shader, true
}

create_image :: proc(device: vk.Device, physical_device: vk.PhysicalDevice, format: vk.Format, type: vk.ImageType, tiling: vk.ImageTiling, usage: vk.ImageUsageFlags, flags: vk.ImageCreateFlags, modifiers: []u64, width: u32, height: u32) -> (image: vk.Image, memory: vk.DeviceMemory, ok: bool) {

  list_info := vk.ImageDrmFormatModifierListCreateInfoEXT {
    sType = .IMAGE_DRM_FORMAT_MODIFIER_LIST_CREATE_INFO_EXT,
    pNext = nil,
    drmFormatModifierCount = u32(len(modifiers)),
    pDrmFormatModifiers = &modifiers[0],
  }

  info := vk.ImageCreateInfo {
    sType = .IMAGE_CREATE_INFO,
    pNext = &list_info,
    flags = flags,
    imageType = type,
    format = format,
    mipLevels = 1,
    arrayLayers = 1,
    samples = { ._1 },
    tiling = tiling,
    usage = usage,
    sharingMode = .EXCLUSIVE,
    queueFamilyIndexCount = 0,
    pQueueFamilyIndices = nil,
    initialLayout = .UNDEFINED,
    extent = vk.Extent3D {
      width = width,
      height = height,
      depth = 1,
    },
  }

  if res := vk.CreateImage(device, &info, nil, &image); res != .SUCCESS {
    fmt.println(res)
    return image, memory, false
  }

  fmt.println("Image Created")

  requirements: vk.MemoryRequirements
  vk.GetImageMemoryRequirements(device, image, &requirements)

  import_info := vk.ExportMemoryAllocateInfo {
    sType = .EXPORT_MEMORY_ALLOCATE_INFO,
    pNext = nil,
    handleTypes = { .DMA_BUF_EXT },
  }

  memory = create_memory(device, physical_device, requirements, { .HOST_VISIBLE, .HOST_COHERENT }, nil) or_return

  vk.BindImageMemory(device, image, memory, vk.DeviceSize(0))

  fmt.println("Image Bound")

  return image, memory, true
}

create_command_pool :: proc(device: vk.Device, queue_index: u32) -> (vk.CommandPool, bool) {
	pool_info: vk.CommandPoolCreateInfo
	pool_info.sType = .COMMAND_POOL_CREATE_INFO
	pool_info.flags = {.RESET_COMMAND_BUFFER}
	pool_info.queueFamilyIndex = queue_index
	
  command_pool: vk.CommandPool
	if res := vk.CreateCommandPool(device, &pool_info, nil, &command_pool); res != .SUCCESS do return command_pool, false

  fmt.println("CommandPool created")

  return command_pool, true
}

allcate_command_buffers :: proc(device: vk.Device, command_pool: vk.CommandPool, count: u32) -> ([]vk.CommandBuffer, bool) {
	alloc_info: vk.CommandBufferAllocateInfo
	alloc_info.sType = .COMMAND_BUFFER_ALLOCATE_INFO
	alloc_info.commandPool = command_pool
	alloc_info.level = .PRIMARY
	alloc_info.commandBufferCount = count
	
  command_buffers := make([]vk.CommandBuffer, count)
	if res := vk.AllocateCommandBuffers(device, &alloc_info, &command_buffers[0]); res != .SUCCESS do return command_buffers, false

  return command_buffers, true
}

find_memory_type :: proc(physical_device: vk.PhysicalDevice, type_filter: u32, properties: vk.MemoryPropertyFlags) -> (u32, bool) {
	mem_properties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(physical_device, &mem_properties)

	for i in 0..<mem_properties.memoryTypeCount {
		if (type_filter & (1 << i) != 0) && (mem_properties.memoryTypes[i].propertyFlags & properties) == properties do return i, true
	}

  return 0, false
}

create_buffer :: proc(device: vk.Device, physical_device: vk.PhysicalDevice, size: vk.DeviceSize, usage: vk.BufferUsageFlags, properties: vk.MemoryPropertyFlags) -> (buffer: vk.Buffer, memory: vk.DeviceMemory, ok: bool) {
  buf_mem_info := vk.ExternalMemoryBufferCreateInfo {
    sType = .EXTERNAL_MEMORY_BUFFER_CREATE_INFO,
    pNext = nil,
    handleTypes = { .DMA_BUF_EXT },
  }

  buf_info := vk.BufferCreateInfo {
    sType = .BUFFER_CREATE_INFO,
    pNext = &buf_mem_info,
    size = size,
    usage = usage,
    flags = {},
    sharingMode = .EXCLUSIVE,
  }

  if vk.CreateBuffer(device, &buf_info, nil, &buffer) != .SUCCESS do return buffer, memory, false

  requirements: vk.MemoryRequirements
  vk.GetBufferMemoryRequirements(device, buffer, &requirements)

  ded_info := vk.MemoryDedicatedAllocateInfo {
    sType = .MEMORY_DEDICATED_ALLOCATE_INFO,
    buffer = buffer
  }

  export_info := vk.ExportMemoryAllocateInfo {
    sType = .EXPORT_MEMORY_ALLOCATE_INFO,
    pNext = &ded_info,
    handleTypes = { .DMA_BUF_EXT },
  }

  memory = create_memory(device, physical_device, requirements, properties, &export_info) or_return

  vk.BindBufferMemory(device, buffer, memory, 0)

  return buffer, memory, true
}

create_memory :: proc(device: vk.Device, physical_device: vk.PhysicalDevice, requirements: vk.MemoryRequirements, properties: vk.MemoryPropertyFlags, pNext: rawptr) -> (memory: vk.DeviceMemory, ok: bool) {
	alloc_info := vk.MemoryAllocateInfo{
		sType = .MEMORY_ALLOCATE_INFO,
    pNext = pNext,
		allocationSize = requirements.size,
		memoryTypeIndex = find_memory_type(physical_device, requirements.memoryTypeBits, properties) or_return
	}
	
	if res := vk.AllocateMemory(device, &alloc_info, nil, &memory); res != .SUCCESS do return memory, false

  fmt.println("Memory Created")
  return memory, true
}

load_fn :: proc(ptr: rawptr, name: cstring) {
    (cast(^rawptr)ptr)^ = dynlib.symbol_address(library, string(name))
}

