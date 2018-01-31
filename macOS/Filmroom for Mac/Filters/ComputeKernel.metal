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
    outTexture.write(float4(float2(inTexture.read(gid).r * 0.6), float2(0.0)), newIndex);
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



/*
void fft_2(texture2d<float, access::read_write> texture, uint2 gid){
    uint2 next = gid + uint2(1, 0);
    float value0 = texture.read(gid).r, value1 = texture.read(next).r;
    float tempValue = value0;
    value0 += value1;
    value1 = tempValue - value1;
    texture.write(float4(float3(value0), 1.0), gid);
    texture.write(float4(float3(value1), 1.0), next);
}

void fft_4(texture2d<float, access::read_write> texture, uint2 gid){
    uint2 next0 = gid + uint2(1, 0), next1 = gid + uint2(2, 0), next2 = gid + uint2(3, 0);
    float value0 = texture.read(gid).r, value1 = texture.read(next0).r, value2 = texture.read(next1).r, value3 = texture.read(next2).r;
    
    float temp0, temp1, temp2, temp3;
    temp0 = value0 + value2;
    temp2 = value0 - value2;
    temp1 = value1 + value3;
    temp3 = value1 - value3;
    
    value0 = temp0 + temp1;
    value2 = temp0 - temp1;
    value1 = temp2 + temp3;
    value3 = temp2 - temp3;
    
    texture.write(float4(float3(value0), 1.0), gid);
    texture.write(float4(float3(value1), 1.0), next0);
    texture.write(float4(float3(value2), 1.0), next1);
    texture.write(float4(float3(value3), 1.0), next2);
}


void fft_8(texture2d<float, access::read_write> texture, uint2 gid){
    uint2 next0 = gid + uint2(1, 0), next1 = gid + uint2(2, 0), next2 = gid + uint2(3, 0);
    uint2 next3 = gid + uint2(4, 0), next4 = gid + uint2(5, 0), next5 = gid + uint2(6, 0), next6 = gid + uint2(7, 0);
    
    float temp0, temp1, temp2, temp3;
    float temp4, temp5, temp6, temp7;
    
    float value0 = texture.read(gid).r, value1 = texture.read(next0).r;
    float value2 = texture.read(next1).r, value3 = texture.read(next2).r;
    float value4 = texture.read(next3).r, value5 = texture.read(next4).r;
    float value6 = texture.read(next5).r, value7 = texture.read(next6).r;
    
    temp0 = value0 + value4;
    temp4 = value0 - value4;
    temp2 = value2 + value6;
    temp6 = value2 - value6;
    temp1 = value1 + value5;
    temp5 = value1 - value5;
    temp3 = value3 + value7;
    temp7 = value3 - value7;
    
    value0 = temp0 + temp2;
    value4 = temp4 + temp6;
    value2 = temp0 - temp2;
    value6 = temp4 - temp6;
    value1 = temp1 + temp3;
    value5 = temp5 + temp7;
    value3 = temp1 - temp3;
    value7 = temp5 - temp7;
    
    temp0 = value0 + value1;
    temp1 = value4 + value5;
    temp2 = value2 + value3;
    temp3 = value6 + value7;
    temp4 = value0 - value1;
    temp5 = value4 - value5;
    temp6 = value2 - value3;
    temp7 = value6 - value7;
    
    texture.write(float4(float3(temp0), 1.0), gid);
    texture.write(float4(float3(temp1), 1.0), next0);
    texture.write(float4(float3(temp2), 1.0), next1);
    texture.write(float4(float3(temp3), 1.0), next2);
    texture.write(float4(float3(temp4), 1.0), next3);
    texture.write(float4(float3(temp5), 1.0), next4);
    texture.write(float4(float3(temp6), 1.0), next5);
    texture.write(float4(float3(temp7), 1.0), next6);
}
*/
