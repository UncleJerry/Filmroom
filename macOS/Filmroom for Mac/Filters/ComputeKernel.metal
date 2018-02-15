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


struct FFTInput_2D {
    device uint *width;
    device uint *length;
    device uint *stage;
    device uint *FFT;
};

typedef struct {
    texture2d<float, access::write> outTexture;
    float value;
} ReorderInput;


kernel void threadTest(device ReorderInput &input[[ buffer(0) ]], uint2 gid [[thread_position_in_grid]]){
    input.outTexture.write(float4(float3(input.value), 1.0), gid);
}

kernel void reposition(texture2d<float, access::read> inTexture [[texture(0)]], texture2d<float, access::write> outTexture [[texture(1)]], device uint *width[[buffer(0)]], device uint *length[[buffer(1)]], uint2 gid [[thread_position_in_grid]]){
    uint2 newIndex = reposition(gid, width[0], length[0]);
    outTexture.write(float4(float2(inTexture.read(gid).r, 0.0), float2(0.0)), newIndex);
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

kernel void dft(texture2d<float, access::write> outTexture [[texture(0)]], texture2d<float, access::read> inTexture [[texture(1)]], device uint *width[[buffer(0)]], device uint *length[[buffer(1)]], uint2 gid [[thread_position_in_grid]]){
    uint k = to1D(gid, width[0]);
    Complex sum = {0, 0};
    for (uint j = 0; j < length[0]; j++) {
        Complex twidle = Complex{cos(2*M_PI_F*k*j/length[0]), sin(2*M_PI_F*k*j/length[0])};
        float pixel = inTexture.read(to2D(j, width[0])).r;
        sum = sum + twidle * pixel;
    }
    
}


kernel void fft_allStage(texture2d<float, access::read_write> inTexture [[texture(0)]], device uint *width[[buffer(0)]], device uint *length[[buffer(1)]], device uint *stage[[buffer((2))]], device uint *FFT[[buffer((3))]], device uint *complexConjugate[[buffer(4)]], uint2 gid [[thread_position_in_grid]]){
    uint upper1D = to1D(gid, width[0]);
    uint N = pow(2.0, stage[0]);

    if (upper1D % N >= N / 2){
        return;
    }
    
    Complex upper = Complex{inTexture.read(gid).r, inTexture.read(gid).g};
    uint lower1D = upper1D + N / 2;
    uint2 lower2D = to2D(lower1D, width[0]);
    Complex lower = Complex{inTexture.read(gid).r, inTexture.read(gid).g};
    Complex twiddle = Complex{cos(FFT[0] * 2 * M_PI_F * upper1D / N), complexConjugate[0] * (FFT[0] * 2 * M_PI_F * upper1D / N)};
    Complex twiddled = twiddle * lower;

    upper = upper + twiddled;
    lower = upper - twiddled;
    
    inTexture.write(float4(float2(upper.real, upper.image), float2(0.0)), gid);
    inTexture.write(float4(float2(lower.real, lower.image), float2(0.0)), lower2D);
}

kernel void complexModulus(texture2d<float, access::read> inTexture [[texture(0)]], texture2d<float, access::write> outTexture [[texture(1)]], uint2 gid [[thread_position_in_grid]]){
    float modulus = sqrt(pow(inTexture.read(gid).r, 2) + pow(inTexture.read(gid).g, 2));
    
    outTexture.write(float4(float3(modulus), 1.0), gid);
}
