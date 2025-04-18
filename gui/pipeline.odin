package main

import "base:runtime"
import "core:os"
import vk "vendor:vulkan"

create_pipeline :: proc(
	ctx: ^VulkanContext,
	device: vk.Device,
	layout: vk.PipelineLayout,
	render_pass: vk.RenderPass,
	width: u32,
	height: u32,
) -> (
	pipeline: vk.Pipeline,
	err: Error,
) {
	vert_module := create_shader_module(
		device,
		"assets/output/vert.spv",
		ctx.tmp_allocator,
	) or_return
	defer vk.DestroyShaderModule(device, vert_module, nil)

	frag_module := create_shader_module(
		device,
		"assets/output/frag.spv",
		ctx.tmp_allocator,
	) or_return
	defer vk.DestroyShaderModule(device, frag_module, nil)

	stages := [?]vk.PipelineShaderStageCreateInfo {
		{
			sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = {.VERTEX},
			module = vert_module,
			pName = cstring("main"),
		},
		{
			sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = {.FRAGMENT},
			module = frag_module,
			pName = cstring("main"),
		},
	}

	vertex_binding_descriptions := [?]vk.VertexInputBindingDescription {
		{binding = 0, stride = size_of(Vertex), inputRate = .VERTEX},
	}

	vertex_attribute_descriptions := [?]vk.VertexInputAttributeDescription {
		{location = 0, binding = 0, offset = 0, format = .R32G32B32_SFLOAT},
	}

	vert_input_state := vk.PipelineVertexInputStateCreateInfo {
		sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount   = u32(len(vertex_binding_descriptions)),
		pVertexBindingDescriptions      = &vertex_binding_descriptions[0],
		vertexAttributeDescriptionCount = u32(len(vertex_attribute_descriptions)),
		pVertexAttributeDescriptions    = &vertex_attribute_descriptions[0],
	}

	viewports := [?]vk.Viewport {
		{x = 0, y = 0, width = f32(width), height = f32(height), minDepth = 0, maxDepth = 1},
	}

	scissors := [?]vk.Rect2D {
		{
			offset = vk.Offset2D{x = 0, y = 0},
			extent = vk.Extent2D{width = height, height = height},
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
		frontFace               = .COUNTER_CLOCKWISE,
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
		renderPass          = render_pass,
		layout              = layout,
	}

	if vk.CreateGraphicsPipelines(device, 0, 1, &info, nil, &pipeline) != .SUCCESS do return pipeline, .CreatePipelineFailed

	return pipeline, nil
}

create_render_pass :: proc(ctx: ^VulkanContext) -> (vk.RenderPass, Error) {
	render_pass_attachments := [?]vk.AttachmentDescription {
		{
			format = ctx.format,
			samples = {._1},
			loadOp = .CLEAR,
			storeOp = .STORE,
			initialLayout = .UNDEFINED,
			finalLayout = .COLOR_ATTACHMENT_OPTIMAL,
			stencilLoadOp = .DONT_CARE,
			stencilStoreOp = .DONT_CARE,
		},
		{
			format = ctx.depth_format,
			samples = {._1},
			loadOp = .CLEAR,
			storeOp = .STORE,
			initialLayout = .UNDEFINED,
			finalLayout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
			stencilLoadOp = .DONT_CARE,
			stencilStoreOp = .DONT_CARE,
		},
	}

	subpass_color_attachments := [?]vk.AttachmentReference {
		{attachment = 0, layout = .COLOR_ATTACHMENT_OPTIMAL},
	}

	subpass_depth_attachments := [?]vk.AttachmentReference {
		{attachment = 1, layout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL},
	}

	render_pass_subpass := [?]vk.SubpassDescription {
		{
			pipelineBindPoint = .GRAPHICS,
			colorAttachmentCount = u32(len(subpass_color_attachments)),
			pColorAttachments = &subpass_color_attachments[0],
			pDepthStencilAttachment = &subpass_depth_attachments[0],
		},
	}

	render_pass_dependencies := [?]vk.SubpassDependency {
		{
			srcSubpass = vk.SUBPASS_EXTERNAL,
			dstSubpass = 0,
			srcStageMask = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS},
			srcAccessMask = {},
			dstStageMask = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS},
			dstAccessMask = {.COLOR_ATTACHMENT_WRITE, .DEPTH_STENCIL_ATTACHMENT_WRITE},
			dependencyFlags = {.BY_REGION},
		},
	}

	render_pass_info := vk.RenderPassCreateInfo {
		sType           = .RENDER_PASS_CREATE_INFO,
		attachmentCount = u32(len(render_pass_attachments)),
		pAttachments    = &render_pass_attachments[0],
		subpassCount    = u32(len(render_pass_subpass)),
		pSubpasses      = &render_pass_subpass[0],
		dependencyCount = u32(len(render_pass_dependencies)),
		pDependencies   = &render_pass_dependencies[0],
	}

	render_pass: vk.RenderPass
	if vk.CreateRenderPass(ctx.device, &render_pass_info, nil, &render_pass) != .SUCCESS do return render_pass, .CreateRenderPassFailed

	return render_pass, nil
}

create_shader_module :: proc(
	device: vk.Device,
	path: string,
	allocator: runtime.Allocator,
) -> (
	module: vk.ShaderModule,
	err: Error,
) {
	er: os.Error
	file: os.Handle
	size: i64

	if file, er = os.open(path); err != nil do return module, .FileNotFound
	defer os.close(file)

	if size, er = os.file_size(file); err != nil do return module, .FileNotFound

	buf := alloc([]u8, u32(size), allocator) or_return

	l: int
	if l, er = os.read(file, buf); err != nil do return module, .ReadFileFailed
	if int(size) != l do return module, .SizeNotMatch

	info := vk.ShaderModuleCreateInfo {
		sType    = .SHADER_MODULE_CREATE_INFO,
		codeSize = int(size),
		pCode    = cast([^]u32)(&buf[0]),
	}

	frag_module: vk.ShaderModule
	if vk.CreateShaderModule(device, &info, nil, &module) != .SUCCESS do return module, .CreateShaderModuleFailed

	return module, nil
}

create_set_layouts :: proc(
	ctx: ^VulkanContext,
	device: vk.Device,
) -> (
	set_layouts: []vk.DescriptorSetLayout,
	err: Error,
) {
	set_layout_bindings := [?]vk.DescriptorSetLayoutBinding {
		{
			binding = 0,
			stageFlags = {.VERTEX},
			descriptorType = .UNIFORM_BUFFER,
			descriptorCount = 1,
		},
		{
			binding = 1,
			stageFlags = {.VERTEX},
			descriptorType = .STORAGE_BUFFER,
			descriptorCount = 1,
		},
		{
			binding = 2,
			stageFlags = {.VERTEX},
			descriptorType = .STORAGE_BUFFER,
			descriptorCount = 1,
		},
	}

	set_layout_infos := [?]vk.DescriptorSetLayoutCreateInfo {
		{
			sType = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
			bindingCount = u32(len(set_layout_bindings)),
			pBindings = &set_layout_bindings[0],
		},
	}

	set_layouts = alloc([]vk.DescriptorSetLayout, 1, ctx.allocator) or_return
	for i in 0 ..< len(set_layouts) {
		if vk.CreateDescriptorSetLayout(device, &set_layout_infos[i], nil, &set_layouts[i]) != .SUCCESS do return set_layouts, .CreateDescriptorSetLayoutFailed
	}

	return set_layouts, nil
}

create_layout :: proc(
	device: vk.Device,
	set_layouts: []vk.DescriptorSetLayout,
) -> (
	vk.PipelineLayout,
	Error,
) {
	layout_info := vk.PipelineLayoutCreateInfo {
		sType          = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = u32(len(set_layouts)),
		pSetLayouts    = &set_layouts[0],
	}

	layout: vk.PipelineLayout
	if vk.CreatePipelineLayout(device, &layout_info, nil, &layout) != .SUCCESS do return layout, .CreatePipelineLayouFailed

	return layout, nil
}

create_descriptor_pool :: proc(device: vk.Device) -> (vk.DescriptorPool, Error) {
	sizes := [?]vk.DescriptorPoolSize {
		{type = .UNIFORM_BUFFER, descriptorCount = 10},
		{type = .STORAGE_BUFFER, descriptorCount = 10},
	}

	info := vk.DescriptorPoolCreateInfo {
		sType         = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = u32(len(sizes)),
		pPoolSizes    = &sizes[0],
		maxSets       = 2,
	}

	pool: vk.DescriptorPool
	if vk.CreateDescriptorPool(device, &info, nil, &pool) != nil do return pool, .CreateDescriptorPoolFailed

	return pool, nil
}

allocate_descriptor_sets :: proc(
	ctx: ^VulkanContext,
	device: vk.Device,
	layouts: []vk.DescriptorSetLayout,
	pool: vk.DescriptorPool,
) -> (
	sets: []vk.DescriptorSet,
	err: Error,
) {
	info := vk.DescriptorSetAllocateInfo {
		sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool     = pool,
		descriptorSetCount = u32(len(layouts)),
		pSetLayouts        = &layouts[0],
	}

	sets = alloc([]vk.DescriptorSet, u32(len(layouts)), ctx.allocator) or_return
	if vk.AllocateDescriptorSets(device, &info, &sets[0]) != .SUCCESS do return sets, .AllocateDescriptorSetFailed

	return sets, nil
}

update_descriptor_set :: proc(
	ctx: ^VulkanContext,
	set: vk.DescriptorSet,
	buffers: []vk.Buffer,
	bindings: []u32,
	kinds: []vk.DescriptorType,
	sizes: []vk.DeviceSize,
) -> Error {
	total := u32(len(buffers))

	writes := alloc([]vk.WriteDescriptorSet, total, ctx.tmp_allocator) or_return
	infos := alloc([]vk.DescriptorBufferInfo, total, ctx.tmp_allocator) or_return

	count := 0
	for i in 0 ..< total {
		if sizes[i] == 0 do continue

		infos[count].offset = 0
		infos[count].buffer = buffers[i]
		infos[count].range = sizes[i]

		writes[count].sType = .WRITE_DESCRIPTOR_SET
		writes[count].dstSet = set
		writes[count].dstBinding = bindings[i]
		writes[count].dstArrayElement = 0
		writes[count].descriptorCount = 1
		writes[count].pBufferInfo = &infos[count]
		writes[count].descriptorType = kinds[i]

		count += 1
	}

	vk.UpdateDescriptorSets(ctx.device, u32(count), &writes[0], 0, nil)

	return nil
}
