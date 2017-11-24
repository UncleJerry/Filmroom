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


float guassian(int x, int y, float sigma){
    int top = -(x * x + y * y);
    float bottom = sigma * sigma * 2;
    
    return exp(top / bottom) / sqrt(bottom * 3.14159265);
}

array<array<float, 11>, 11> guassianKernel(float sigma){
    array<array<float, 11>, 11> guassianKernel;
    
    for(int i = 0; i < 11; ++i){
        for(int j = 0; j < 11; ++j){
            guassianKernel[i][j] = guassian(i - 11 / 2, j - 11 / 2, sigma);
        }
    }
    

    return guassianKernel;
}




extern "C" { namespace coreimage {
    float4 gamma(sampler img, float gamma){
        float3 pixel = sample(img, samplerCoord(img)).rgb;
        
        // a0 = 0.2
        float s = gamma / (0.2 * (gamma - 1.0) + pow(0.2, 1 - gamma));
        float d = 1.0 / (pow(0.2, gamma) * (gamma - 1.0) + 1.0) - 1.0;
        
        const float3 luminanceWeighting = float3(0.2126, 0.7152, 0.0722);
        float luminance = dot(pixel, luminanceWeighting);
        
        float3 newPixel = luminance <= 0.2 ? s * pixel : (1 + d) * pow(pixel, gamma) - d;
        
        return float4(newPixel, 1.0);
    }
    
    float4 guassianBlur(sampler img, float sigma){
        float2 coordinate = img.coord();
        array<array<float, 11>, 11> theKernel = guassianKernel(sigma);
        
        float2 center = float2(5.0);
        float3 currentPixel = float3(0.0);
        float weightCount = 0.0;
        
        for(int i = 0; i < 11; i++){
            for(int j = 0; j < 11; j++){
                float2 transform = coordinate - center + float2(i, j);
                float2 pixelCoord = img.transform(transform);
                
                weightCount += theKernel[i][j];
                currentPixel += (theKernel[i][j] * img.sample(pixelCoord).rgb);
            }
        }
        
        
        return float4(currentPixel / weightCount, 1.0);
    }
    

}}
