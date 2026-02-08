# Metal 4 Development Guide

This document provides instructions and best practices for building applications using Apple's Metal 4 Core API.

## Overview

Metal 4 is Apple's modern, low-overhead graphics and compute API designed for Apple silicon. It enables direct GPU task control for maximizing graphics and compute efficiency, with native machine learning integration across Apple platforms.

### Supported Platforms
- **Mac**: Apple M1 and later
- **iPhone/iPad**: A14 Bionic and later
- **Apple TV**: Compatible models
- **Apple Vision Pro**: All models

## Metal 4 Core API Structure

### 1. Command Encoding

Metal 4 introduces a revolutionary command encoding system:

#### Key Types
- `MTL4CommandQueue` - New command queue type for Metal 4
- `MTL4CommandBuffer` - Enhanced command buffer supporting parallel encoding
- Unified command encoders (consolidates multiple encoder types)

#### Best Practices
- **Enable parallel encoding** - Metal 4 supports concurrent command encoding for improved performance
- **Use unified encoders** - Leverage the consolidated encoder types to simplify code
- Allow mixing traditional Metal and MTL4 command queues during migration

### 2. Resource Management

Metal 4 provides advanced resource management capabilities:

#### Key Features
- `MTL4ArgumentTable` - Flexible resource binding system for storing binding points
- **Residency Sets** - Unified memory management across resources
- **Placement Sparse Resources** - Dynamic memory control for efficient system memory usage

#### Best Practices
- Use `MTL4ArgumentTable` to manage large sets of resources efficiently
- Leverage placement sparse resources to maximize available system memory
- Plan resource residency carefully to optimize memory footprint

### 3. Synchronization

Metal 4 introduces low-overhead synchronization:

#### Barrier API
- Provides stage-to-stage synchronization
- Maps well to barriers in other graphics APIs
- Low overhead compared to traditional synchronization methods

#### Best Practices
- **Always synchronize resource updates** - Metal 4 focuses on concurrency by default
- Use the Barrier API to ensure correct order of writes and reads across pipeline stages
- Minimize synchronization points while maintaining correctness

### 4. Shader Compilation

Metal 4 offers faster and more explicit compilation:

#### Key Features
- `MTL4Compiler` interface with dedicated compilation contexts
- Flexible render pipeline states
- Optimized compilation with shared Metal IR
- Reduced run-time compilation overhead

#### Best Practices
- **Precompile shaders** when possible to minimize run-time overhead
- Use flexible render pipeline states to reduce compilation variants
- Share Metal IR across multiple pipeline states for better performance
- Leverage compilation contexts for better organization

### 5. Machine Learning Integration

Metal 4 integrates machine learning directly into the graphics pipeline:

#### Native Tensor Support
- Tensors are first-class types in Metal 4 API and Metal Shading Language
- Offloads complex multidimensional indexing
- Enables direct ML integration in rendering

#### Two Integration Approaches

**A. Machine Learning Command Encoder**
- Execute large-scale neural networks directly within Metal apps
- Encode inference networks at command level
- Best for standalone ML workloads

**B. Shader-Embedded ML**
- Integrate ML directly into shaders
- Use cases:
  - Advanced lighting computation
  - Procedural material rendering
  - Geometry generation
- Best for tightly coupled graphics + ML workflows

#### Best Practices
- Choose the right integration approach based on your use case
- Use tensors to simplify multidimensional data handling
- Combine graphics with ML inference for advanced effects

## Performance Optimization

### MetalFX
Metal 4 includes MetalFX for advanced rendering techniques:
- **Upscaling** - Render at lower resolution, upscale for display
- **Frame Interpolation** - Generate intermediate frames for smoother animation
- **Denoising** - Clean up ray-traced or path-traced images

#### Best Practices
- Use upscaling to achieve higher frame rates on demanding scenes
- Apply denoising for ray-traced rendering
- Leverage frame interpolation for cinematic experiences

### General Performance Guidelines
- Enable parallel command encoding to maximize CPU utilization
- Use placement sparse resources to reduce memory pressure
- Minimize barrier synchronization points
- Precompile shaders to reduce run-time overhead
- Profile using Metal's developer tools

## Developer Tools

Metal provides comprehensive debugging and profiling tools:

### Available Tools
1. **Metal Debugger** - Inspect the entire rendering pipeline
2. **Performance HUD** - Real-time performance monitoring
3. **API and Shader Validation** - Catch errors during development
4. **Metal System Trace** (Instruments) - Analyze CPU/GPU/memory usage
5. **Xcode 16** - Integrated Metal development environment

### Best Practices
- Enable API and shader validation during development
- Use Performance HUD to monitor frame rates and GPU utilization
- Profile with Metal System Trace to identify bottlenecks
- Debug rendering issues with Metal Debugger's capture feature
- Validate on target hardware early and often

## Migration Strategy

### Phased Adoption Approach
1. **Start small** - Begin with non-critical rendering paths
2. **Mix APIs** - Use both traditional Metal and MTL4 command queues during transition
3. **Migrate incrementally** - Convert systems one at a time
4. **Test thoroughly** - Validate each migration step

### Compatibility
- Metal 4 allows mixing traditional Metal and MTL4 command queues
- Gradual migration is supported and recommended
- No need for "big bang" rewrites

## Code Organization Best Practices

### Project Structure
```
YourApp/
├── Shaders/           # Metal shader files (.metal)
├── Pipelines/         # Pipeline state objects
├── Resources/         # Textures, models, buffers
├── Encoders/          # Command encoding logic
├── ML/                # Machine learning integration
└── Utilities/         # Helper functions
```

### Naming Conventions
- Use clear, descriptive names for resources and pipelines
- Prefix Metal 4 specific code with `MTL4` or similar
- Group related encoders and resources together

## Common Patterns

### Command Buffer Pattern
```
1. Create MTL4CommandBuffer from MTL4CommandQueue
2. Create unified encoder(s)
3. Set pipeline state and resources using MTL4ArgumentTable
4. Encode commands (can be done in parallel)
5. Add barriers for synchronization as needed
6. End encoding
7. Commit command buffer
```

### Resource Binding Pattern
```
1. Create MTL4ArgumentTable
2. Bind resources to argument table
3. Use residency sets for memory management
4. Reference argument table in encoders
5. Update bindings as needed
```

### ML Integration Pattern
```
1. Define tensors for input/output
2. Choose integration approach:
   - ML Command Encoder for standalone inference
   - Shader-embedded for graphics integration
3. Execute/encode ML operations
4. Use results in rendering pipeline
```

## Practical Implementation Lessons

### Vertex Buffer Binding with MTL4ArgumentTable

**CRITICAL**: `[[stage_in]]` vertex attributes are incompatible with `MTL4ArgumentTable` resource binding.

#### Problem
When using traditional vertex descriptors with `[[stage_in]]` in shaders:
```metal
vertex ColorInOut vertexShader(Vertex in [[stage_in]], ...)
```

And binding via argument tables, vertices won't be properly accessed, resulting in rendering artifacts.

#### Solution
Use direct buffer access with `[[vertex_id]]` instead:

```metal
struct MyVertex { float3 position; float3 normal; float3 color; };

vertex ColorInOut vertexShader(
    uint vertexID [[vertex_id]],
    device const MyVertex* vertices [[buffer(0)]],
    constant Uniforms& uniforms [[buffer(1)]]
) {
    MyVertex in = vertices[vertexID];
    // ... use in.position, in.normal, in.color
}
```

Then bind via argument table:
```swift
vertexArgumentTable.setAddress(vertexBuffer.gpuAddress, index: 0)
renderEncoder.setArgumentTable(vertexArgumentTable, stages: .vertex)
```

### MTL4RenderPassDescriptor Conversion

MTKView provides `MTLRenderPassDescriptor`, but Metal 4 encoders require `MTL4RenderPassDescriptor`.

#### Required Conversion
```swift
guard let mtlRenderPass = view.currentRenderPassDescriptor else { return }

let mtl4RenderPass = MTL4RenderPassDescriptor()
mtl4RenderPass.colorAttachments[0].texture = mtlRenderPass.colorAttachments[0].texture
mtl4RenderPass.colorAttachments[0].loadAction = .clear
mtl4RenderPass.colorAttachments[0].storeAction = .store
mtl4RenderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1.0)

if let depthTexture = mtlRenderPass.depthAttachment.texture {
    mtl4RenderPass.depthAttachment.texture = depthTexture
    mtl4RenderPass.depthAttachment.loadAction = .clear
    mtl4RenderPass.depthAttachment.storeAction = .dontCare
    mtl4RenderPass.depthAttachment.clearDepth = 1.0
}
```

### Explicit Type Qualifiers Required

Metal 4 requires fully qualified enum types (no implicit type inference):

```swift
// ❌ WRONG - will not compile
renderEncoder.setCullMode(.back)
renderEncoder.setFrontFacing(.counterClockwise)
renderEncoder.drawIndexedPrimitives(primitiveType: .triangle, ...)

// ✅ CORRECT
renderEncoder.setCullMode(MTLCullMode.back)
renderEncoder.setFrontFacing(MTLWinding.counterClockwise)
renderEncoder.drawIndexedPrimitives(primitiveType: MTLPrimitiveType.triangle, ...)
```

### Triangle Winding Order for Face Culling

Counter-clockwise winding is standard for front-facing triangles, but orientation matters.

#### Vertical Faces (Building Walls)
For outward-facing vertical quads, use alternating winding:
```swift
// Quad with corners [0, 1, 2, 3]
indices = [0, 2, 1,  0, 3, 2]  // Two triangles, counter-clockwise from outside
```

#### Horizontal Faces (Ground, Roofs, Roads)
For upward-facing horizontal quads viewed from above:
```swift
// Quad with corners [0, 1, 2, 3] laid out counter-clockwise on XZ plane
indices = [0, 1, 2,  0, 2, 3]  // Standard winding when Y-up
```

**Important**: Test winding by viewing from the intended camera angle. Surfaces that appear inside-out need reversed indices.

### Clipping Plane Configuration

Set far clipping plane based on scene extents, not arbitrary small values:

```swift
// ❌ Too close - will clip distant geometry
projectionMatrix = matrix_perspective(..., nearZ: 0.1, farZ: 100.0)

// ✅ Appropriate for large scenes (town size ~240 units, camera at 150 units)
projectionMatrix = matrix_perspective(..., nearZ: 0.1, farZ: 1000.0)
```

### Z-Fighting Prevention

Avoid coplanar geometry by adding small height offsets:

```swift
// ❌ Roads at same height as ground causes flickering
let roadHeight: Float = 0.0
let groundHeight: Float = 0.0

// ✅ Roads slightly above ground
let roadHeight: Float = 0.2
let groundHeight: Float = 0.0
```

### Camera Orientation Setup

Metal uses right-handed coordinate system (Y-up, Z-forward is negative):

```swift
// Camera at (0, 50, 150) looking toward origin
camera.position = SIMD3<Float>(0, 50, 150)
camera.yaw = Float.pi        // Rotate 180° to face -Z direction
camera.pitch = -0.3          // Tilt down ~17° to look at ground
```

### Argument Table Setup Order

Set resource addresses in argument tables BEFORE binding tables to encoder:

```swift
// ✅ CORRECT order
vertexArgumentTable.setAddress(vertexBuffer.gpuAddress, index: 0)
vertexArgumentTable.setAddress(uniformBuffer.gpuAddress, index: 1)
renderEncoder.setArgumentTable(vertexArgumentTable, stages: .vertex)

// ❌ WRONG - setting table first, then resources won't work
renderEncoder.setArgumentTable(vertexArgumentTable, stages: .vertex)
vertexArgumentTable.setAddress(vertexBuffer.gpuAddress, index: 0)  // Too late!
```

## Additional Resources

### Official Documentation
- [Metal Documentation](https://developer.apple.com/documentation/metal)
- [Metal Performance Shaders](https://developer.apple.com/documentation/metalperformanceshaders)
- [Metal Performance Shaders Graph](https://developer.apple.com/documentation/metalperformanceshadersgraph)
- [Metal Sample Code](https://developer.apple.com/metal/sample-code/)

### WWDC Sessions
- WWDC 2025: Discover Metal 4
- Metal developer workflows
- Using the Metal 4 compilation API

## Quick Start Checklist

- [ ] Verify target device compatibility (M1+, A14+)
- [ ] Set up Xcode 16 or later
- [ ] Enable Metal API validation during development
- [ ] Choose between MTL4CommandQueue or traditional Metal based on needs
- [ ] Plan resource management strategy (ArgumentTable, residency sets)
- [ ] Identify synchronization requirements
- [ ] Decide on shader compilation strategy (precompile vs. runtime)
- [ ] Consider ML integration opportunities
- [ ] Set up profiling and debugging workflow
- [ ] Test on target hardware regularly

## Key Takeaways

1. **Metal 4 enables parallel encoding** - Utilize concurrent command encoding for performance
2. **Synchronization is explicit** - Always use barriers to coordinate resource access
3. **ML is first-class** - Tensors and ML encoders are native to the API
4. **Compilation is faster** - Precompile and share Metal IR for best results
5. **Resources are flexible** - ArgumentTables and placement sparse resources provide fine control
6. **Tools are essential** - Use validation, debugging, and profiling throughout development
7. **Migration is gradual** - Mix Metal and Metal 4 APIs during transition

---

*This guide is based on Apple's Metal 4 Core API documentation and WWDC 2025 materials. Always refer to official Apple documentation for the most up-to-date information.*
