//
//  MetalFilters.metal
//  Photo Factory
//
//  Created by 周建明 on 15/12/2017.
//  Copyright © 2017年 周建明. All rights reserved.
//

#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;


extern "C" { namespace coreimage {
    
    float4 highlight(sampler img, float unit){
        float2 coordinate = img.coord();
        float3 pixel = img.sample(coordinate).rgb;
        const float3 luminanceWeighting = float3(0.2126, 0.7152, 0.0722);
    
        float luminance = dot(pixel, luminanceWeighting);
        float shadowGreyScale = clamp(luminance - 0.55, 0.0, 0.2);

        // Compute new pixel value with 20 * x^2 + x transiting function
        // Add the function to adjust exposure instruction
        float3 newPixel = pixel * pow(2.0, unit * (pow(shadowGreyScale, 2.0) * 20.0 + 1.0 * shadowGreyScale));
        newPixel = clamp(newPixel, float3(0.0), float3(1.0));
        
        // Alpha for opacity of image
        return float4(newPixel, 1.0);
    }
    
}}
