//
//  ComputeKernel.metal
//  Filmroom for Mac
//
//  Created by 周建明 on 2017/11/6.
//  Copyright © 2017年 周建明. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

uint2 reposition(uint2 gid, uint width, uint len)
{
    uint ret = 0;
    uint id = gid.y * width + gid.x;
    
    for(uint i = 0; (1 << i) < len; i++)
    {
        ret <<= 1;
        if(id & (1 << i)) ret |= 1;
    }
    
    return uint2(ret % width, ret / width);
}

uint to1D(uint2 gid, int width){
    return gid.y * width + gid.x;
}

uint2 to2D(uint id, int width){
    return uint2(id % width, id / width);
}

kernel void threadTest(texture2d<float, access::read> inTexture [[texture(0)]], texture2d<float, access::write> outTexture [[texture(1)]], uint2 gid [[thread_position_in_grid]]){
   
    outTexture.write(float4(float3(0.6), 1.0), gid);
    outTexture.write(float4(float3(0.6), 1.0), gid + uint2(1, 0));
}

kernel void reposition(texture2d<float, access::read> inTexture [[texture(0)]], texture2d<float, access::write> outTexture [[texture(1)]], device uint *width[[buffer(0)]], device uint *length[[buffer(1)]], uint2 gid [[thread_position_in_grid]]){
    uint2 newIndex = reposition(gid, width[0], length[0]);
    outTexture.write(float2(inTexture.read(gid).r), 0.0), newIndex);
}

typedef struct{
    float real;
    float image;
} Complex;

Complex operator*(const Complex l, const Complex r){
    return {l.real * r.real - l.image * r.image, l.real * r.image + l.image * r.real};
}

Complex operator*(const Complex l, const float r){
    return l * Complex{r, 0};
}

Complex operator+(const Complex l, const Complex r){
    return {l.real + r.real, l.image + r.image};
}

Complex operator-(const Complex l, const Complex r){
    return {l.real - r.real, l.image - r.image};
}

kernel void fft_1Stage(texture2d<float, access::read_write> inTexture [[texture(0)]], device uint *width[[buffer(0)]], uint2 gid [[thread_position_in_grid]]){
    
    for(int s = 1; (1 << s) <= width[0]; s++){
        uint m = (1 << s);
        Complex wm = {cos(2*M_PI_F/m), sin(2*M_PI_F/m)};
        
        for(uint k = 0; k < width[0]; k += m){
            Complex w = {1, 0};
            for(uint j = 0; j < (m >> 1); j++){
                uint2 tid = gid + uint2(k + j + (m >> 1), 0);
                uint2 uid = gid + uint2(k + j, 0);
                Complex t = w * Complex{inTexture.read(tid).r, inTexture.read(tid).g};
                Complex u = {inTexture.read(uid).r, 0.0};
                
                Complex resultU = u + t;
                Complex resultT = u - t;
                inTexture.write(float4(resultU.real, resultU.image, float2(0.0)), uid);
                inTexture.write(float4(resultT.real, resultT.image, float2(0.0)), tid);
                w = w * wm;
            }
            
        }
    }
}

kernel void dft(texture2d<float, access::write> outTexture [[texture(0)]], texture2d<float, access::read> inTexture [[texture(1)]], device uint *width[[buffer(0)]], device uint *length[[buffer(1)]], uint2 gid [[thread_position_in_grid]]){
    uint k = to1D(gid, width[0]);
    Complex sum = {0, 0};
    for (uint j = 0; j < length[0]; j++) {
        Complex twidle = Complex{cos(2*M_PI_F*k*j/length[0]), sin(2*M_PI_F*k*j/length[0])};
        float pixel = inTexture.read(to2D(j, width[0])).r;
        sum = sum + twidle * pixel;
    }
    
}

kernel void fft_allStage(texture2d<float, access::read_write> inTexture [[texture(0)]], device uint *width[[buffer(0)]], device uint *length[[buffer(1)]], device uint *stage[[buffer((2))]], uint2 gid [[thread_position_in_grid]]){
    uint upper1D = to1D(gid, width[0]);
    uint N = pow(2, stage);

    if (location % N >= N / 2){
        return;
    }
    
    Complex upper = Complex{inTexture.read(gid).r, inTexture.read(gid).g};
    uint lower1D = to2D(upper1D + N / 2, width[0]);
    Complex lower = Complex{inTexture.read(gid).r, inTexture.read(gid).g};
    Complex twiddle = Complex{cos(2 * M_PI_F * upper1D / N), sin(2 * M_PI_F * upper1D / N)};
    Complex twiddled = twiddle * lower;

    upper = upper + twiddled;
    lower = upper - twiddled;
    
    inTexture.write(float2(upper.real, upper.image), gid);
    inTexture.write(float2(lower.real, lower.image), to2D(lower1D, width[0]));
}

