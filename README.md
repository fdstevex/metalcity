# MetalCity

A simple Metal 4 sample macOS application demonstrating procedural city generation and rendering using Apple's latest Metal 4 Core API.

Created by Claude Code.

## Features

- **Metal 4 Core API** - Uses the latest Metal 4 command encoding, argument tables, and residency sets
- **Procedural Generation** - Runtime generation of buildings, roads, and terrain
- **Camera System** - WASD movement with mouse-look camera controls
- **Efficient Rendering** - Direct GPU buffer access with Metal 4's unified command encoders

## Prompts

This is a Claude Code project, and took a few prompts to get right. The key was starting with instructions to read and understand the Metal 4 API:

> Read the https://developer.apple.com/documentation/metal/understanding-the-metal-4-core-api and produce a CLAUDE.md that includes instructions and best practices for building an app using Metal.

Then:

> The MetalCity project is a Metal 4 macOS project.  Create a 3D procedural small town generator, with camera controls I can use to explore the down. Use Metal 4 best practices (look things up if you need to).

This produced something that mostly worked, but the geometry winding was incorrect (buildings were inside out) and the camera started inside a building.  I prompted it to fix that, and this project is the result.

When I had it all working, I asked it to update the CLAUDE.md again with what it learned along the way.

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
