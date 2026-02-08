# MetalCity

A simple Metal 4 sample macOS application demonstrating procedural city generation and rendering using Apple's latest Metal 4 Core API.

Created by Claude Code.

## Features

- **Metal 4 Core API** - Uses the latest Metal 4 command encoding, argument tables, and residency sets
- **Procedural Generation** - Runtime generation of buildings, roads, and terrain
- **Camera System** - WASD movement with mouse-look camera controls
- **Efficient Rendering** - Direct GPU buffer access with Metal 4's unified command encoders

## Screenshot

![MetalCity Screenshot](screenshot.png)

## Requirements

- macOS with Apple Silicon (M1 or later)
- Xcode 16 or later
- Metal 4 support (automatically available on M1+ chips)

## Controls

- **WASD** - Move camera forward/back/left/right
- **Q/E** - Move camera down/up
- **Mouse Drag** - Look around
- **Scroll Wheel** - Adjust movement speed

## Architecture

The project demonstrates several Metal 4 Core API features:

- **MTL4CommandQueue** and **MTL4CommandBuffer** for command encoding
- **MTL4ArgumentTable** for efficient resource binding
- **MTL4RenderPassDescriptor** for render pass configuration
- **Residency Sets** for unified memory management
- Direct vertex buffer access without `[[stage_in]]` for Metal 4 compatibility

## Building

Open `MetalCity.xcodeproj` in Xcode and build for macOS. The project requires no external dependencies.

## Code Structure

- `AppDelegate.swift` - Application lifecycle
- `GameViewController.swift` - Main view controller and input handling
- `Renderer.swift` - Metal 4 rendering engine
- `Camera.swift` - First-person camera controller
- `TownGenerator.swift` - Procedural town generation
- `Shaders.metal` - Vertex and fragment shaders
- `ShaderTypes.h` - Shared types between Swift and Metal

## License

This is a sample project for learning purposes.
