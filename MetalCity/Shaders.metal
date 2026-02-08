//
//  Shaders.metal
//  MetalCity
//
//  Created by Steve Tibbett on 2026-02-08.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

struct TownVertex
{
    float3 position;
    float3 normal;
    float3 color;
};

typedef struct
{
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float3 color;
} ColorInOut;

vertex ColorInOut vertexShader(uint vertexID [[vertex_id]],
                               device const TownVertex* vertices [[ buffer(BufferIndexVertices) ]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    TownVertex in = vertices[vertexID];
    ColorInOut out;

    float4 worldPos = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPos;
    out.worldPosition = worldPos.xyz;
    out.normal = in.normal;
    out.color = in.color;

    return out;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    // Normalize interpolated normal
    float3 normal = normalize(in.normal);

    // Calculate diffuse lighting
    float3 lightDir = normalize(-uniforms.lightDirection);
    float diffuse = max(dot(normal, lightDir), 0.0);

    // Combine ambient and diffuse
    float3 ambient = in.color * uniforms.ambientIntensity;
    float3 diffuseColor = in.color * diffuse * (1.0 - uniforms.ambientIntensity);

    float3 finalColor = ambient + diffuseColor;

    return float4(finalColor, 1.0);
}
