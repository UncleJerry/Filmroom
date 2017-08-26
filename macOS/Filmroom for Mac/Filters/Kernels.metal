//
//  Kernels.metal
//  Filmroom for Mac
//
//  Created by 周建明 on 2017/8/14.
//  Copyright © 2017年 周建明. All rights reserved.
//

#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;


extern "C" { namespace coreimage {
    float4 exposure(sampler img, float unit){
        float3 pixel = sample(img, samplerCoord(img)).rgb;
        
        float3 newPixel = pixel * pow(2.0, unit);
        return float4(newPixel, 1.0);
    }
    
    float4 gamma(sampler img, float gamma){
        float3 pixel = sample(img, samplerCoord(img)).rgb;
        
        // a0 = 0.2
        float s = gamma / (0.2 * (gamma - 1) + pow(0.2, 1 - gamma));
        float d = 1 / (pow(0.2, gamma) * (gamma - 1) + 1) - 1;
        
        const float3 luminanceWeighting = float3(0.2126, 0.7152, 0.0722);
        float luminance = dot(pixel, luminanceWeighting);
        
        float3 newPixel = luminance <= 0.2 ? s * pixel : (1 + d) * pow(pixel, gamma) - d;
        
        return float4(newPixel, 1.0);
    }
}}
