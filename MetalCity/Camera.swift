//
//  Camera.swift
//  MetalCity
//
//  Camera controller with mouse look and keyboard movement
//

import Foundation
import simd
import Cocoa

class Camera {
    // Camera position and orientation
    var position: SIMD3<Float>
    var yaw: Float = 0.0      // Rotation around Y axis
    var pitch: Float = 0.0    // Rotation around X axis

    // Camera parameters
    var moveSpeed: Float = 20.0
    var lookSpeed: Float = 0.003
    var minPitch: Float = -Float.pi / 2.0 + 0.1
    var maxPitch: Float = Float.pi / 2.0 - 0.1

    // Input state
    private var keysPressed: Set<UInt16> = []
    private var lastMousePosition: CGPoint?
    private var isMouseDragging = false

    init(position: SIMD3<Float> = SIMD3<Float>(0, 10, 30)) {
        self.position = position
    }

    // MARK: - View Matrix

    func viewMatrix() -> matrix_float4x4 {
        // Calculate forward, right, and up vectors
        let forward = self.forward()
        let right = self.right()
        let up = self.up()

        // Create view matrix (inverse of camera transform)
        let rotation = matrix_float4x4(
            SIMD4<Float>(right.x, up.x, -forward.x, 0),
            SIMD4<Float>(right.y, up.y, -forward.y, 0),
            SIMD4<Float>(right.z, up.z, -forward.z, 0),
            SIMD4<Float>(0, 0, 0, 1)
        )
        let translation = matrix_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(-position.x, -position.y, -position.z, 1)
        )

        return rotation * translation
    }

    // MARK: - Direction Vectors

    func forward() -> SIMD3<Float> {
        return SIMD3<Float>(
            cos(pitch) * sin(yaw),
            sin(pitch),
            cos(pitch) * cos(yaw)
        )
    }

    func right() -> SIMD3<Float> {
        return normalize(cross(forward(), SIMD3<Float>(0, 1, 0)))
    }

    func up() -> SIMD3<Float> {
        return cross(right(), forward())
    }

    // MARK: - Update

    func update(deltaTime: Float) {
        var movement = SIMD3<Float>(0, 0, 0)

        // WASD movement
        if keysPressed.contains(13) { // W
            movement += forward()
        }
        if keysPressed.contains(1) { // S
            movement -= forward()
        }
        if keysPressed.contains(0) { // A
            movement -= right()
        }
        if keysPressed.contains(2) { // D
            movement += right()
        }

        // QE for vertical movement
        if keysPressed.contains(12) { // Q
            movement.y -= 1.0
        }
        if keysPressed.contains(14) { // E
            movement.y += 1.0
        }

        // Apply movement
        if length(movement) > 0.001 {
            position += normalize(movement) * moveSpeed * deltaTime
        }
    }

    // MARK: - Input Handling

    func handleKeyDown(_ event: NSEvent) {
        keysPressed.insert(event.keyCode)
    }

    func handleKeyUp(_ event: NSEvent) {
        keysPressed.remove(event.keyCode)
    }

    func handleMouseDown(at point: CGPoint) {
        isMouseDragging = true
        lastMousePosition = point
    }

    func handleMouseUp() {
        isMouseDragging = false
        lastMousePosition = nil
    }

    func handleMouseDrag(to point: CGPoint) {
        guard isMouseDragging, let lastPosition = lastMousePosition else { return }

        let deltaX = Float(point.x - lastPosition.x)
        let deltaY = Float(point.y - lastPosition.y)

        yaw += deltaX * lookSpeed
        pitch -= deltaY * lookSpeed

        // Clamp pitch to prevent camera flipping
        pitch = max(minPitch, min(maxPitch, pitch))

        // Normalize yaw to [0, 2π]
        if yaw > Float.pi * 2 {
            yaw -= Float.pi * 2
        } else if yaw < 0 {
            yaw += Float.pi * 2
        }

        lastMousePosition = point
    }

    func handleScroll(deltaY: CGFloat) {
        // Optional: adjust move speed with scroll wheel
        moveSpeed = max(5.0, min(100.0, moveSpeed + Float(deltaY) * 0.5))
    }
}
