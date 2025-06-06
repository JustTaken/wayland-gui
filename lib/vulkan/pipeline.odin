package vulk

import "base:runtime"
import "core:log"
import "core:math/linalg"
import "core:os"

import vk "vendor:vulkan"

import "lib:collection/vector"
import "lib:error"

@(private)
Pipeline_Instance_Group :: struct {
  geometry:  ^Geometry,
  instances: vector.Vector(Instance),
  offset:    u32,
}

@(private)
Pipeline_Layout :: struct {
  handle: vk.PipelineLayout,
  sets:   vector.Vector(^Descriptor_Set_Layout),
}

@(private)
Pipeline :: struct {
  handle:                        vk.Pipeline,
  layout:                        ^Pipeline_Layout,
  groups:                        vector.Vector(Pipeline_Instance_Group),
  vertex_shader:                 ^Shader_Module,
  fragment_shader:               ^Shader_Module,
  vertex_binding_descriptions:   vector.Vector(
    vk.VertexInputBindingDescription,
  ),
  vertex_attribute_descriptions: vector.Vector(
    vk.VertexInputAttributeDescription,
  ),
}

@(private)
Vertex_Attribute_Kind :: enum {
  Sfloat,
  Uint,
}

@(private)
Vertex_Attribute :: struct {
  kind:  Vertex_Attribute_Kind,
  count: u32,
}

@(private)
get_attribute_format :: proc(
  attribute: Vertex_Attribute,
) -> (
  format: vk.Format,
  size: u32,
  err: error.Error,
) {
  switch attribute.kind {
  case .Sfloat:
    size = size_of(f32)
  case .Uint:
    size = size_of(u32)
  }

  switch attribute.count {
  case 2:
    switch attribute.kind {
    case .Sfloat:
      format = .R32G32_SFLOAT
    case .Uint:
      format = .R32G32_UINT
    }
  case 3:
    switch attribute.kind {
    case .Sfloat:
      format = .R32G32B32_SFLOAT
    case .Uint:
      format = .R32G32B32_UINT
    }
  case 4:
    switch attribute.kind {
    case .Sfloat:
      format = .R32G32B32A32_SFLOAT
    case .Uint:
      format = .R32G32B32A32_UINT
    }
  case:
    return format, size, .InvalidFormat
  }

  size = size * attribute.count

  return format, size, nil
}

@(private)
pipeline_update :: proc(
  pipeline: ^Pipeline,
  ctx: ^Vulkan_Context,
  render_pass: ^Render_Pass,
) -> error.Error {
  stages := [?]vk.PipelineShaderStageCreateInfo {
    {
      sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
      stage = {.VERTEX},
      module = pipeline.vertex_shader.handle,
      pName = cstring("main"),
    },
    {
      sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
      stage = {.FRAGMENT},
      module = pipeline.fragment_shader.handle,
      pName = cstring("main"),
    },
  }

  vert_input_state := vk.PipelineVertexInputStateCreateInfo {
    sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    vertexBindingDescriptionCount   = pipeline.vertex_binding_descriptions.len,
    pVertexBindingDescriptions      = &pipeline.vertex_binding_descriptions.data[0],
    vertexAttributeDescriptionCount = pipeline.vertex_attribute_descriptions.len,
    pVertexAttributeDescriptions    = &pipeline.vertex_attribute_descriptions.data[0],
  }

  viewports := [?]vk.Viewport {
    {x = 0, y = 0, width = 0, height = 0, minDepth = 0, maxDepth = 1},
  }

  scissors := [?]vk.Rect2D {
    {
      offset = vk.Offset2D{x = 0, y = 0},
      extent = vk.Extent2D{width = 0, height = 0},
    },
  }

  viewport_state := vk.PipelineViewportStateCreateInfo {
    sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
    viewportCount = u32(len(viewports)),
    pViewports    = &viewports[0],
    scissorCount  = u32(len(scissors)),
    pScissors     = &scissors[0],
  }

  multisample_state := vk.PipelineMultisampleStateCreateInfo {
    sType                 = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
    rasterizationSamples  = {._1},
    sampleShadingEnable   = false,
    alphaToOneEnable      = false,
    alphaToCoverageEnable = false,
    minSampleShading      = 1.0,
  }

  depth_stencil_stage := vk.PipelineDepthStencilStateCreateInfo {
    sType                 = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
    depthTestEnable       = true,
    depthWriteEnable      = true,
    depthCompareOp        = .LESS,
    depthBoundsTestEnable = false,
    stencilTestEnable     = false,
    minDepthBounds        = 0.0,
    maxDepthBounds        = 1.0,
  }

  color_blend_attachments := [?]vk.PipelineColorBlendAttachmentState {
    {
      blendEnable = false,
      srcColorBlendFactor = .ONE,
      dstColorBlendFactor = .ZERO,
      colorBlendOp = .ADD,
      srcAlphaBlendFactor = .ONE,
      dstAlphaBlendFactor = .ZERO,
      alphaBlendOp = .ADD,
      colorWriteMask = {.R, .G, .B, .A},
    },
  }

  color_blend_state := vk.PipelineColorBlendStateCreateInfo {
    sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
    logicOpEnable   = false,
    attachmentCount = u32(len(color_blend_attachments)),
    pAttachments    = &color_blend_attachments[0],
    blendConstants  = {0, 0, 0, 0},
  }

  rasterization_state := vk.PipelineRasterizationStateCreateInfo {
    sType                   = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
    depthClampEnable        = false,
    rasterizerDiscardEnable = false,
    polygonMode             = .FILL,
    cullMode                = {.FRONT},
    frontFace               = .CLOCKWISE,
    depthBiasEnable         = false,
    depthBiasClamp          = 0.0,
    depthBiasConstantFactor = 0.0,
    depthBiasSlopeFactor    = 0.0,
    lineWidth               = 1,
  }

  input_assembly_state := vk.PipelineInputAssemblyStateCreateInfo {
    sType    = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
    topology = .TRIANGLE_LIST,
  }

  dynamic_states := [?]vk.DynamicState{.VIEWPORT, .SCISSOR}

  dynamic_state := vk.PipelineDynamicStateCreateInfo {
    sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
    dynamicStateCount = u32(len(dynamic_states)),
    pDynamicStates    = &dynamic_states[0],
  }

  info := vk.GraphicsPipelineCreateInfo {
    sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
    stageCount          = u32(len(stages)),
    pStages             = &stages[0],
    pViewportState      = &viewport_state,
    pVertexInputState   = &vert_input_state,
    pMultisampleState   = &multisample_state,
    pDepthStencilState  = &depth_stencil_stage,
    pColorBlendState    = &color_blend_state,
    pRasterizationState = &rasterization_state,
    pInputAssemblyState = &input_assembly_state,
    pDynamicState       = &dynamic_state,
    renderPass          = render_pass.handle,
    layout              = pipeline.layout.handle,
  }

  if vk.CreateGraphicsPipelines(
       ctx.device.handle,
       0,
       1,
       &info,
       nil,
       &pipeline.handle,
     ) !=
     .SUCCESS {
    return .CreatePipelineFailed
  }
  return nil
}

@(private)
pipeline_create :: proc(
  pipeline: ^Pipeline,
  ctx: ^Vulkan_Context,
  render_pass: ^Render_Pass,
  layout: ^Pipeline_Layout,
  vertex_shader: ^Shader_Module,
  fragment_shader: ^Shader_Module,
  vertex_attribute_bindings: [][]Vertex_Attribute,
) -> error.Error {
  pipeline.groups = vector.new(
    Pipeline_Instance_Group,
    10,
    ctx.allocator,
  ) or_return

  pipeline.layout = layout
  pipeline.vertex_shader = vertex_shader
  pipeline.fragment_shader = fragment_shader

  attribute_count: u32 = 0
  for i in 0 ..< len(vertex_attribute_bindings) {
    for j in 0 ..< len(vertex_attribute_bindings[i]) {
      attribute_count += 1
    }
  }

  pipeline.vertex_binding_descriptions = vector.new(
    vk.VertexInputBindingDescription,
    u32(len(vertex_attribute_bindings)),
    ctx.allocator,
  ) or_return

  pipeline.vertex_attribute_descriptions = vector.new(
    vk.VertexInputAttributeDescription,
    attribute_count,
    ctx.allocator,
  ) or_return

  for i in 0 ..< len(vertex_attribute_bindings) {
    offset: u32 = 0

    for j in 0 ..< len(vertex_attribute_bindings[i]) {
      format, size := get_attribute_format(
        vertex_attribute_bindings[i][j],
      ) or_return

      description := vector.one(
        &pipeline.vertex_attribute_descriptions,
      ) or_return

      description.binding = u32(i)
      description.location = u32(j)
      description.offset = offset
      description.format = format

      offset += size
    }

    binding := vector.one(&pipeline.vertex_binding_descriptions) or_return
    binding.binding = u32(i)
    binding.stride = offset
    binding.inputRate = .VERTEX
  }

  pipeline_update(pipeline, ctx, render_pass) or_return

  return nil
}

@(private)
pipeline_layout_create :: proc(
  layout: ^Pipeline_Layout,
  ctx: ^Vulkan_Context,
  set_layouts: []^Descriptor_Set_Layout,
) -> error.Error {
  layouts := vector.new(
    vk.DescriptorSetLayout,
    u32(len(set_layouts)),
    ctx.tmp_allocator,
  ) or_return

  layout.sets = vector.new(
    ^Descriptor_Set_Layout,
    u32(len(set_layouts)),
    ctx.allocator,
  ) or_return

  for i in 0 ..< len(set_layouts) {
    vector.append(&layout.sets, set_layouts[i]) or_return
    vector.append(&layouts, set_layouts[i].handle) or_return
  }

  layout_info := vk.PipelineLayoutCreateInfo {
    sType          = .PIPELINE_LAYOUT_CREATE_INFO,
    setLayoutCount = layouts.len,
    pSetLayouts    = &layouts.data[0],
  }

  if vk.CreatePipelineLayout(
       ctx.device.handle,
       &layout_info,
       nil,
       &layout.handle,
     ) !=
     .SUCCESS {
    return .CreatePipelineLayouFailed
  }

  return nil
}

@(private)
pipeline_add_instance :: proc(
  ctx: ^Vulkan_Context,
  pipeline: ^Pipeline,
  geometry_index: u32,
  model: Maybe(Instance_Model),
  transform_offset: u32,
) -> (
  instance: ^Instance,
  err: error.Error,
) {
  group: ^Pipeline_Instance_Group = nil

  geometry := &ctx.geometries.data[geometry_index]

  for i in 0 ..< pipeline.groups.len {
    if geometry == pipeline.groups.data[i].geometry {
      group = &pipeline.groups.data[i]
    }
  }

  if group == nil {
    group = vector.one(&pipeline.groups) or_return

    group.geometry = geometry
    group.offset = ctx.instance_index
    ctx.instance_index += 10

    group.instances = vector.new(Instance, 10, ctx.allocator) or_return
  }

  offset := group.offset + group.instances.len

  instance = vector.one(&group.instances) or_return
  instance.offset = offset
  instance.transform = geometry.transform

  m := model.? or_else linalg.MATRIX4F32_IDENTITY

  transform_offsets := [?]u32{ctx.transform_index + transform_offset}
  copy_data_to_buffer(
    u32,
    ctx,
    transform_offsets[:],
    ctx.transform_offset_buffer,
    instance.offset,
  ) or_return

  descriptor_set_update(
    u32,
    ctx,
    ctx.dynamic_set,
    ctx.transform_offset_buffer,
    TRANSFORM_OFFSETS,
  ) or_return

  material_offsets := [?]u32{geometry.material}
  copy_data_to_buffer(
    u32,
    ctx,
    material_offsets[:],
    ctx.material_offset_buffer,
    instance.offset,
  ) or_return

  descriptor_set_update(
    u32,
    ctx,
    ctx.dynamic_set,
    ctx.material_offset_buffer,
    MATERIAL_OFFSETS,
  ) or_return

  instance_update(ctx, instance, m) or_return

  return instance, nil
}
