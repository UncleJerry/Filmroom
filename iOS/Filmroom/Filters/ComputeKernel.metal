//
//  ComputeKernel.metal
//  Filmroom for Mac
//
//  Created by 周建明 on 2017/11/6.
//  Copyright © 2017年 周建明. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

uint to1D(uint2 gid, uint width){
    return gid.y * width + gid.x;
}

uint2 to2D(uint id, uint width){
    return uint2(id % width, id / width);
}

uint2 reposition(uint2 gid, uint width, int len)
{
    int ret = 0;
    int id = to1D(gid, width);
    
    for(int i = 0; (1 << i) < len; i++)
    {
        ret <<= 1;
        if(id & (1 << i)){
            ret |= 1;
        }
    }
    
    return to2D(ret, width);
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


//kernel void threadTest(device ReorderInput &input[[ buffer(0) ]], uint2 gid [[thread_position_in_grid]]){
//    input.outTexture.write(float4(float3(input.value), 1.0), gid);
//}

kernel void reposition(texture2d<float, access::read> inTexture [[texture(0)]], texture2d<float, access::write> outTexture [[texture(1)]], device uint *width[[buffer(0)]], device uint *length[[buffer(1)]], uint2 gid [[thread_position_in_grid]]){
    uint2 newIndex = reposition(gid, width[0], length[0]);
    outTexture.write(float4(inTexture.read(gid).r, float3(0.0)), newIndex);
}

kernel void repeat(texture2d<float, access::read> inTexture [[texture(0)]], texture2d<float, access::write> outTexture [[texture(1)]], device uint *width[[buffer(0)]], device uint *length[[buffer(1)]], uint2 gid [[thread_position_in_grid]]){
    
    outTexture.write(inTexture.read(gid), gid);
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
    
    float modulus = sqrt(pow(sum.real, 2) + pow(sum.image, 2));
    outTexture.write(float4(modulus, float3(0.0)), gid);
}


kernel void fft_allStage(texture2d<float, access::read_write> inTexture [[texture(0)]], device uint *width[[buffer(0)]], device uint *length[[buffer(1)]], device uint *stage[[buffer((2))]], device int *FFT[[buffer((3))]], device int *complexConjugate[[buffer(4)]], uint2 gid [[thread_position_in_grid]]){
    uint upper1D = to1D(gid, width[0]);
    uint N = pow(2.0, stage[0]);
    
    if (upper1D % N >= N / 2){
        return;
    }
    
    Complex upper = Complex{inTexture.read(gid).x, inTexture.read(gid).y};
    uint lower1D = upper1D + N / 2;
    uint2 lower2D = to2D(lower1D, width[0]);
    Complex lower = Complex{inTexture.read(lower2D).x, inTexture.read(lower2D).y};
    Complex twiddle = Complex{cos(FFT[0] * 2 * M_PI_F * upper1D / N), complexConjugate[0] * sin(FFT[0] * 2 * M_PI_F * upper1D / N)};
    Complex twiddled = twiddle * lower;
    
    lower = upper - twiddled;
    upper = upper + twiddled;
    
    
    inTexture.write(float4(float2(upper.real, upper.image), float2(0.0)), gid);
    inTexture.write(float4(float2(lower.real, lower.image), float2(0.0)), lower2D);
}

kernel void complexModulus(texture2d<float, access::read> inTexture [[texture(0)]], texture2d<float, access::write> outTexture [[texture(1)]], uint2 gid [[thread_position_in_grid]]){
    float modulus = sqrt(pow(inTexture.read(gid).x, 2) + pow(inTexture.read(gid).y, 2));
    
    outTexture.write(float4(float3(modulus / 1000), 1.0), gid);
}

float shrinkage(float x, float epsilon){
    return sign(x) * max(abs(x) - epsilon, 0.0);
}

kernel void illuminationMap(texture2d<float, access::read> inTexture [[texture(0)]], texture2d<float, access::write> outTexture [[texture(1)]], device int *referRadius[[buffer(0)]], uint2 gid [[thread_position_in_grid]]){
    
    if(gid.x - referRadius[0] <= 0 || gid.y - referRadius[0] <= 0){
        return;
    }
    if(gid.x + referRadius[0] >= inTexture.get_width() || gid.y + referRadius[0] >= inTexture.get_height()){
        return;
    }
    
    float illValues = 0.0;
    for(int i = -(referRadius[0] / 2); i <= referRadius[0] / 2; i++){
        for(int j = -(referRadius[0] / 2); j <= referRadius[0] / 2; j++){
            uint2 cid = gid - uint2(i, j); // current navigated position
            float3 neighbor = float3(0.0);
            
            neighbor = inTexture.read(cid).rgb;
            illValues += max(neighbor.r, max(neighbor.g, neighbor.b));
        }
    }
    illValues /= pow(referRadius[0], 2.0);
    
    outTexture.write(float4(float(illValues), float3(0.0)), gid);
}

