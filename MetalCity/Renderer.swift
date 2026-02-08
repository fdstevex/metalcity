//
//  Renderer.swift
//  MetalCity
//
//  Created by Steve Tibbett on 2026-02-08.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size + 0xFF) & -0x100

let maxBuffersInFlight = 3

nonisolated enum RendererError: Error {
    case badVertexDescriptor
}

class Renderer: NSObject, MTKViewDelegate {

    public let device: MTLDevice

    let commandQueue: MTL4CommandQueue
    let commandBuffer: MTL4CommandBuffer
    let commandAllocators: [MTL4CommandAllocator]
    let commandQueueResidencySet: MTLResidencySet
    let vertexArgumentTable: MTL4ArgumentTable
    let fragmentArgumentTable: MTL4ArgumentTable

    let endFrameEvent: MTLSharedEvent
    var frameIndex = 0

    var dynamicUniformBuffer: MTLBuffer
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState

    var uniformBufferOffset = 0
    var uniformBufferIndex = 0
    var uniforms: UnsafeMutablePointer<Uniforms>

    var projectionMatrix: matrix_float4x4 = matrix_float4x4()

    // Town and camera
    var camera: Camera
    var townGeometry: TownGeometry
    var lastFrameTime: CFTimeInterval = CACurrentMediaTime()
    
    @MainActor
    init?(metalKitView: MTKView) {
        let device = metalKitView.device!
        self.device = device

        // Initialize camera - position it high and far back to view the whole town
        self.camera = Camera(position: SIMD3<Float>(0, 50, 150))
        // Point camera towards town center: yaw=π to face -Z direction, pitch down to look at ground
        self.camera.yaw = Float.pi
        self.camera.pitch = -0.3

        // Generate town geometry
        let townGenerator = TownGenerator(config: TownConfig(seed: 42))
        self.townGeometry = townGenerator.createGeometry(device: device)

        self.commandQueue = device.makeMTL4CommandQueue()!
        self.commandBuffer = device.makeCommandBuffer()!
        self.commandAllocators = (0...maxBuffersInFlight).map { _ in device.makeCommandAllocator()! }

        let argTableDesc = MTL4ArgumentTableDescriptor()
        argTableDesc.maxBufferBindCount = 2
        self.vertexArgumentTable = try! device.makeArgumentTable(descriptor: argTableDesc)
        self.fragmentArgumentTable = try! device.makeArgumentTable(descriptor: argTableDesc)

        self.endFrameEvent = device.makeSharedEvent()!
        frameIndex = maxBuffersInFlight
        self.endFrameEvent.signaledValue = UInt64(frameIndex - 1)

        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight

        guard let buffer = self.device.makeBuffer(length:uniformBufferSize, options:[MTLResourceOptions.storageModeShared]) else { return nil }
        dynamicUniformBuffer = buffer

        self.dynamicUniformBuffer.label = "UniformBuffer"

        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)

        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1

        let mtlVertexDescriptor = Renderer.buildMetalVertexDescriptor()

        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }

        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled = true
        guard let state = device.makeDepthStencilState(descriptor:depthStateDescriptor) else { return nil }
        depthState = state

        // Create residency set for town geometry
        let residencySetDesc = MTLResidencySetDescriptor()
        residencySetDesc.initialCapacity = 3 // vertex buffer, index buffer, uniform buffer
        let residencySet = try! self.device.makeResidencySet(descriptor: residencySetDesc)
        residencySet.addAllocations([townGeometry.vertexBuffer, townGeometry.indexBuffer, dynamicUniformBuffer])
        residencySet.commit()
        commandQueue.addResidencySet(residencySet)
        commandQueueResidencySet = residencySet

        super.init()
    }
    
    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        // Create a Metal vertex descriptor for TownVertex structure
        let mtlVertexDescriptor = MTLVertexDescriptor()

        // Position attribute (float3)
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.vertices.rawValue

        // Normal attribute (float3)
        mtlVertexDescriptor.attributes[VertexAttribute.normal.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.normal.rawValue].offset = 12
        mtlVertexDescriptor.attributes[VertexAttribute.normal.rawValue].bufferIndex = BufferIndex.vertices.rawValue

        // Color attribute (float3)
        mtlVertexDescriptor.attributes[VertexAttribute.color.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.color.rawValue].offset = 24
        mtlVertexDescriptor.attributes[VertexAttribute.color.rawValue].bufferIndex = BufferIndex.vertices.rawValue

        // Layout for vertices buffer (position + normal + color = 36 bytes)
        mtlVertexDescriptor.layouts[BufferIndex.vertices.rawValue].stride = 36
        mtlVertexDescriptor.layouts[BufferIndex.vertices.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.vertices.rawValue].stepFunction = MTLVertexStepFunction.perVertex

        return mtlVertexDescriptor
    }
    
    @MainActor
    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        let compiler = try device.makeCompiler(descriptor: MTL4CompilerDescriptor())
        
        let vertexFunctionDescriptor = MTL4LibraryFunctionDescriptor()
        vertexFunctionDescriptor.library = library
        vertexFunctionDescriptor.name = "vertexShader"
        let fragmentFunctionDescriptor = MTL4LibraryFunctionDescriptor()
        fragmentFunctionDescriptor.library = library
        fragmentFunctionDescriptor.name = "fragmentShader"
        
        let pipelineDescriptor = MTL4RenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.rasterSampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunctionDescriptor = vertexFunctionDescriptor
        pipelineDescriptor.fragmentFunctionDescriptor = fragmentFunctionDescriptor
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor

        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat

        return try compiler.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    
    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering
        
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)
    }
    
    private func updateGameState() {
        /// Update any game state before rendering

        // Update delta time
        let currentTime = CACurrentMediaTime()
        let deltaTime = Float(currentTime - lastFrameTime)
        lastFrameTime = currentTime

        // Update camera
        camera.update(deltaTime: deltaTime)

        // Update uniforms
        uniforms[0].projectionMatrix = projectionMatrix
        uniforms[0].viewMatrix = camera.viewMatrix()
        uniforms[0].lightDirection = normalize(SIMD3<Float>(0.5, -1.0, 0.3))
        uniforms[0].ambientIntensity = 0.3
    }
    
    func draw(in view: MTKView) {
        /// Per frame updates here

        guard let drawable = view.currentDrawable else {
            print("❌ No drawable available")
            return
        }
        
        /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
        ///   holding onto the drawable and blocking the display pipeline any longer than necessary
        guard let mtlRenderPassDescriptor = view.currentRenderPassDescriptor else {
            print("❌ No render pass descriptor")
            return
        }

        // Convert to MTL4RenderPassDescriptor
        let renderPassDescriptor = MTL4RenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = mtlRenderPassDescriptor.colorAttachments[0].texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1.0)

        if let depthTexture = mtlRenderPassDescriptor.depthAttachment.texture {
            renderPassDescriptor.depthAttachment.texture = depthTexture
            renderPassDescriptor.depthAttachment.loadAction = .clear
            renderPassDescriptor.depthAttachment.storeAction = .dontCare
            renderPassDescriptor.depthAttachment.clearDepth = 1.0
        } else {
            print("⚠️ WARNING: No depth texture!")
        }

        if let stencilTexture = mtlRenderPassDescriptor.stencilAttachment.texture {
            renderPassDescriptor.stencilAttachment.texture = stencilTexture
            renderPassDescriptor.stencilAttachment.loadAction = .clear
            renderPassDescriptor.stencilAttachment.storeAction = .dontCare
        }

        let previousValueToWaitFor = self.frameIndex - maxBuffersInFlight
        self.endFrameEvent.wait(untilSignaledValue: UInt64(previousValueToWaitFor), timeoutMS: 10)
        let commandAllocator = self.commandAllocators[uniformBufferIndex]
        commandAllocator.reset()
        commandBuffer.beginCommandBuffer(allocator: commandAllocator)
        
        self.updateDynamicBufferState()
        
        self.updateGameState()
        
        guard let renderEncoder = self.commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            fatalError("Failed to create render command encoder")
        }
        
        /// Final pass rendering code here
        renderEncoder.label = "Primary Render Encoder"

        renderEncoder.pushDebugGroup("Draw Town")

        renderEncoder.setCullMode(MTLCullMode.back)
        renderEncoder.setFrontFacing(MTLWinding.counterClockwise)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)

        // Bind resources to argument tables BEFORE setting them on encoder
        // Bind vertex buffer for [[stage_in]] usage
        self.vertexArgumentTable.setAddress(townGeometry.vertexBuffer.gpuAddress, index: BufferIndex.vertices.rawValue)

        // Bind uniforms buffer to both vertex and fragment argument tables
        self.vertexArgumentTable.setAddress(dynamicUniformBuffer.gpuAddress + UInt64(uniformBufferOffset), index: BufferIndex.uniforms.rawValue)
        self.fragmentArgumentTable.setAddress(dynamicUniformBuffer.gpuAddress + UInt64(uniformBufferOffset), index: BufferIndex.uniforms.rawValue)

        // NOW set argument tables on the encoder
        renderEncoder.setArgumentTable(self.vertexArgumentTable, stages: MTLRenderStages.vertex)
        renderEncoder.setArgumentTable(self.fragmentArgumentTable, stages: MTLRenderStages.fragment)

        // Draw town geometry
        renderEncoder.drawIndexedPrimitives(
            primitiveType: MTLPrimitiveType.triangle,
            indexCount: townGeometry.indexCount,
            indexType: MTLIndexType.uint32,
            indexBuffer: townGeometry.indexBuffer.gpuAddress,
            indexBufferLength: townGeometry.indexBuffer.length
        )

        renderEncoder.popDebugGroup()
        
        renderEncoder.endEncoding()
        
        commandBuffer.useResidencySet((view.layer as! CAMetalLayer).residencySet);
        commandBuffer.endCommandBuffer()
        
        commandQueue.waitForDrawable(drawable);
        commandQueue.commit([commandBuffer])
        commandQueue.signalDrawable(drawable);
        commandQueue.signalEvent(self.endFrameEvent, value: UInt64(self.frameIndex))
        self.frameIndex += 1
        drawable.present();
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here

        let aspect = Float(size.width) / Float(size.height)
        projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(65), aspectRatio:aspect, nearZ: 0.1, farZ: 1000.0)
    }
}

// Generic matrix math utility functions
func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                         vector_float4(0, 1, 0, 0),
                                         vector_float4(0, 0, 1, 0),
                                         vector_float4(translationX, translationY, translationZ, 1)))
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, zs, -1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}
