//
//  TownGenerator.swift
//  MetalCity
//
//  Procedural town generation system
//

import Foundation
import simd
import Metal

// MARK: - Town Elements

struct Building {
    var position: SIMD3<Float>
    var size: SIMD3<Float>
    var color: SIMD3<Float>
    var type: BuildingType

    enum BuildingType {
        case residential
        case commercial
        case industrial
    }
}

struct Road {
    var start: SIMD2<Float>
    var end: SIMD2<Float>
    var width: Float
}

// MARK: - Town Configuration

struct TownConfig {
    var gridSize: Int = 5
    var blockSize: Float = 20.0
    var roadWidth: Float = 4.0
    var buildingDensity: Float = 0.7
    var seed: UInt64

    init(seed: UInt64 = 42) {
        self.seed = seed
    }
}

// MARK: - Town Generator

class TownGenerator {
    private var buildings: [Building] = []
    private var roads: [Road] = []
    private var config: TownConfig
    private var rng: SeededRandom

    init(config: TownConfig = TownConfig()) {
        self.config = config
        self.rng = SeededRandom(seed: config.seed)
        generateTown()
    }

    private func generateTown() {
        generateRoadGrid()
        generateBuildings()
    }

    // Generate a grid of roads
    private func generateRoadGrid() {
        let halfSize = Float(config.gridSize) * config.blockSize * 0.5

        // Horizontal roads
        for i in 0...config.gridSize {
            let z = Float(i) * config.blockSize - halfSize
            roads.append(Road(
                start: SIMD2<Float>(-halfSize, z),
                end: SIMD2<Float>(halfSize, z),
                width: config.roadWidth
            ))
        }

        // Vertical roads
        for i in 0...config.gridSize {
            let x = Float(i) * config.blockSize - halfSize
            roads.append(Road(
                start: SIMD2<Float>(x, -halfSize),
                end: SIMD2<Float>(x, halfSize),
                width: config.roadWidth
            ))
        }
    }

    // Generate buildings within city blocks
    private func generateBuildings() {
        let halfSize = Float(config.gridSize) * config.blockSize * 0.5

        for ix in 0..<config.gridSize {
            for iz in 0..<config.gridSize {
                if rng.nextFloat() < config.buildingDensity {
                    let blockX = Float(ix) * config.blockSize - halfSize + config.blockSize * 0.5
                    let blockZ = Float(iz) * config.blockSize - halfSize + config.blockSize * 0.5

                    // Random building dimensions
                    let buildingWidth = rng.nextFloat() * 8.0 + 4.0
                    let buildingDepth = rng.nextFloat() * 8.0 + 4.0
                    let buildingHeight = rng.nextFloat() * 15.0 + 5.0

                    // Small random offset within block
                    let offsetX = (rng.nextFloat() - 0.5) * 3.0
                    let offsetZ = (rng.nextFloat() - 0.5) * 3.0

                    let buildingType = Building.BuildingType.allCases[Int(rng.nextFloat() * Float(Building.BuildingType.allCases.count))]

                    buildings.append(Building(
                        position: SIMD3<Float>(blockX + offsetX, buildingHeight * 0.5, blockZ + offsetZ),
                        size: SIMD3<Float>(buildingWidth, buildingHeight, buildingDepth),
                        color: colorForBuildingType(buildingType),
                        type: buildingType
                    ))
                }
            }
        }
    }

    private func colorForBuildingType(_ type: Building.BuildingType) -> SIMD3<Float> {
        switch type {
        case .residential:
            return SIMD3<Float>(0.8 + rng.nextFloat() * 0.2, 0.7 + rng.nextFloat() * 0.2, 0.6 + rng.nextFloat() * 0.2)
        case .commercial:
            return SIMD3<Float>(0.6 + rng.nextFloat() * 0.2, 0.7 + rng.nextFloat() * 0.2, 0.8 + rng.nextFloat() * 0.2)
        case .industrial:
            return SIMD3<Float>(0.5 + rng.nextFloat() * 0.1, 0.5 + rng.nextFloat() * 0.1, 0.5 + rng.nextFloat() * 0.1)
        }
    }

    // MARK: - Geometry Generation

    func createGeometry(device: MTLDevice) -> TownGeometry {
        var vertices: [TownVertex] = []
        var indices: [UInt32] = []

        // Generate ground plane
        addGroundPlane(vertices: &vertices, indices: &indices)

        // Generate roads
        for road in roads {
            addRoad(road, vertices: &vertices, indices: &indices)
        }

        // Generate buildings
        for building in buildings {
            addBuilding(building, vertices: &vertices, indices: &indices)
        }

        // Create Metal buffers
        let vertexBuffer = device.makeBuffer(bytes: vertices,
                                             length: vertices.count * MemoryLayout<TownVertex>.stride,
                                             options: [.storageModeShared])!
        vertexBuffer.label = "Town Vertices"

        let indexBuffer = device.makeBuffer(bytes: indices,
                                            length: indices.count * MemoryLayout<UInt32>.stride,
                                            options: [.storageModeShared])!
        indexBuffer.label = "Town Indices"

        return TownGeometry(
            vertexBuffer: vertexBuffer,
            indexBuffer: indexBuffer,
            indexCount: indices.count
        )
    }

    private func addGroundPlane(vertices: inout [TownVertex], indices: inout [UInt32]) {
        let size = Float(config.gridSize + 1) * config.blockSize
        let baseIndex = UInt32(vertices.count)
        let groundColor = SIMD3<Float>(0.3, 0.4, 0.3)

        vertices.append(TownVertex(position: SIMD3<Float>(-size, 0, -size), normal: SIMD3<Float>(0, 1, 0), color: groundColor))
        vertices.append(TownVertex(position: SIMD3<Float>(size, 0, -size), normal: SIMD3<Float>(0, 1, 0), color: groundColor))
        vertices.append(TownVertex(position: SIMD3<Float>(size, 0, size), normal: SIMD3<Float>(0, 1, 0), color: groundColor))
        vertices.append(TownVertex(position: SIMD3<Float>(-size, 0, size), normal: SIMD3<Float>(0, 1, 0), color: groundColor))

        indices.append(contentsOf: [baseIndex, baseIndex + 2, baseIndex + 1, baseIndex, baseIndex + 3, baseIndex + 2])
    }

    private func addRoad(_ road: Road, vertices: inout [TownVertex], indices: inout [UInt32]) {
        let halfWidth = road.width * 0.5
        let roadColor = SIMD3<Float>(0.2, 0.2, 0.2)
        let roadHeight: Float = 0.2  // Raised to sit clearly above ground

        let dx = road.end.x - road.start.x
        let dz = road.end.y - road.start.y
        let length = sqrt(dx * dx + dz * dz)
        let perpX = -dz / length * halfWidth
        let perpZ = dx / length * halfWidth

        vertices.append(TownVertex(position: SIMD3<Float>(road.start.x - perpX, roadHeight, road.start.y - perpZ), normal: SIMD3<Float>(0, 1, 0), color: roadColor))
        vertices.append(TownVertex(position: SIMD3<Float>(road.start.x + perpX, roadHeight, road.start.y + perpZ), normal: SIMD3<Float>(0, 1, 0), color: roadColor))
        vertices.append(TownVertex(position: SIMD3<Float>(road.end.x + perpX, roadHeight, road.end.y + perpZ), normal: SIMD3<Float>(0, 1, 0), color: roadColor))
        vertices.append(TownVertex(position: SIMD3<Float>(road.end.x - perpX, roadHeight, road.end.y - perpZ), normal: SIMD3<Float>(0, 1, 0), color: roadColor))

        // Counter-clockwise when viewed from above
        let baseIndex = UInt32(vertices.count) - 4
        indices.append(contentsOf: [baseIndex, baseIndex + 1, baseIndex + 2, baseIndex, baseIndex + 2, baseIndex + 3])
    }

    private func addBuilding(_ building: Building, vertices: inout [TownVertex], indices: inout [UInt32]) {
        let pos = building.position
        let size = building.size
        let halfSize = size * 0.5
        let color = building.color

        // Define 8 corners of the box
        let corners: [SIMD3<Float>] = [
            pos + SIMD3<Float>(-halfSize.x, -halfSize.y, -halfSize.z), // 0
            pos + SIMD3<Float>(halfSize.x, -halfSize.y, -halfSize.z),  // 1
            pos + SIMD3<Float>(halfSize.x, -halfSize.y, halfSize.z),   // 2
            pos + SIMD3<Float>(-halfSize.x, -halfSize.y, halfSize.z),  // 3
            pos + SIMD3<Float>(-halfSize.x, halfSize.y, -halfSize.z),  // 4
            pos + SIMD3<Float>(halfSize.x, halfSize.y, -halfSize.z),   // 5
            pos + SIMD3<Float>(halfSize.x, halfSize.y, halfSize.z),    // 6
            pos + SIMD3<Float>(-halfSize.x, halfSize.y, halfSize.z)    // 7
        ]

        // Define faces with normals
        let faces: [(corners: [Int], normal: SIMD3<Float>)] = [
            ([0, 1, 2, 3], SIMD3<Float>(0, -1, 0)), // Bottom
            ([4, 5, 6, 7], SIMD3<Float>(0, 1, 0)),  // Top
            ([0, 1, 5, 4], SIMD3<Float>(0, 0, -1)), // Front
            ([2, 3, 7, 6], SIMD3<Float>(0, 0, 1)),  // Back
            ([1, 2, 6, 5], SIMD3<Float>(1, 0, 0)),  // Right
            ([3, 0, 4, 7], SIMD3<Float>(-1, 0, 0))  // Left
        ]

        for face in faces {
            let faceBaseIndex = UInt32(vertices.count)
            for cornerIndex in face.corners {
                vertices.append(TownVertex(position: corners[cornerIndex], normal: face.normal, color: color))
            }
            // Counter-clockwise winding for outward-facing triangles
            indices.append(contentsOf: [faceBaseIndex, faceBaseIndex + 2, faceBaseIndex + 1, faceBaseIndex, faceBaseIndex + 3, faceBaseIndex + 2])
        }
    }
}

// MARK: - Supporting Types

struct TownVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var color: SIMD3<Float>
}

struct TownGeometry {
    var vertexBuffer: MTLBuffer
    var indexBuffer: MTLBuffer
    var indexCount: Int
}

// MARK: - Simple Seeded Random Number Generator

class SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    func nextFloat() -> Float {
        return Float(next() >> 32) / Float(UInt32.max)
    }
}

// MARK: - Building Type Extension

extension Building.BuildingType: CaseIterable {}
