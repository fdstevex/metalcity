//
//  GameViewController.swift
//  MetalCity
//
//  Created by Steve Tibbett on 2026-02-08.
//

import Cocoa
import MetalKit

// Our macOS specific view controller
class GameViewController: NSViewController {

    var renderer: Renderer!
    var mtkView: MTKView!

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let mtkView = self.view as? MTKView else {
            print("View attached to GameViewController is not an MTKView")
            return
        }

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }

        // Check for Metal 4 support
        if !defaultDevice.supportsFamily(.metal4) {
            print("Metal 4 is not supported")
            return
        }

        mtkView.device = defaultDevice

        guard let newRenderer = Renderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Make sure the view can receive key events
        view.window?.makeFirstResponder(self)
    }

    // MARK: - Input Handling

    override func keyDown(with event: NSEvent) {
        renderer?.camera.handleKeyDown(event)
    }

    override func keyUp(with event: NSEvent) {
        renderer?.camera.handleKeyUp(event)
    }

    override func mouseDown(with event: NSEvent) {
        let locationInView = view.convert(event.locationInWindow, from: nil)
        renderer?.camera.handleMouseDown(at: locationInView)
    }

    override func mouseDragged(with event: NSEvent) {
        let locationInView = view.convert(event.locationInWindow, from: nil)
        renderer?.camera.handleMouseDrag(to: locationInView)
    }

    override func mouseUp(with event: NSEvent) {
        renderer?.camera.handleMouseUp()
    }

    override func scrollWheel(with event: NSEvent) {
        renderer?.camera.handleScroll(deltaY: event.deltaY)
    }

    override var acceptsFirstResponder: Bool {
        return true
    }
}
