//
//  ComputeKernel.metal
//  Filmroom
//
//  Created by 周建明.
//  Copyright © 2018年 Uncle Jerry. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

uint to1D(uint2 gid, uint width){
    return gid.y * width + gid.x;
}

uint2 to2D(uint id, uint width){
    return uint2(id % width, id / width);
}

uint2 reposition(uint2 gid, uint width, int len){
    int ret = 0;
    int id = to1D(gid, width);
    // By this looping, program is able to operate on binary level,
    // invert the binary represent then get the new and proper order.
    for(int i = 0; (1 << i) < len; i++){
        ret <<= 1;
        if(id & (1 << i)){
            ret |= 1;
        }
    }
    
    return to2D(ret, width);
}


typedef struct {
    uint pixelAmount[[id(1)]];
    ushort width[[id(2)]];
} ReorderInput;

kernel void reposition(texture2d<float, access::read> inTexture [[texture(0)]], texture2d<float, access::write> outTexture [[texture(1)]], constant ReorderInput &input[[buffer(0)]], uint2 gid [[thread_position_in_grid]]){
    uint2 newIndex = reposition(gid, input.width, input.pixelAmount);
    outTexture.write(float4(inTexture.read(gid).r, float3(0.0)), newIndex);
}

kernel void reposition4ColorImage(texture2d<float, access::read> inTexture [[texture(0)]], texture2d<float, access::write> outTexture [[texture(1)]], constant ReorderInput &input[[buffer(0)]], uint2 gid [[thread_position_in_grid]]){
    uint2 newIndex = reposition(gid, input.width, input.pixelAmount);
    float3 luminanceWeighting = float3(0.2125, 0.7154, 0.0721);
    
    outTexture.write(float4(dot(luminanceWeighting, inTexture.read(gid).rgb), float3(0.0)), newIndex);
}

kernel void reposition2Channel(texture2d<float, access::read> inTexture [[texture(0)]], texture2d<float, access::write> outTexture [[texture(1)]], constant ReorderInput &input[[buffer(0)]], uint2 gid [[thread_position_in_grid]]){
    uint2 newIndex = reposition(gid, input.width, input.pixelAmount);
    outTexture.write(float4(inTexture.read(gid).r, inTexture.read(gid).g, float2(0.0)), newIndex);
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

typedef struct {
    char FFT[[id((1))]];
    char conjugate [[id((2))]];
    int lastStage [[id(3)]];
} FFTEarlyInput;

typedef struct {
    ushort width[[id(1)]];
    uchar stage[[id(2)]];
    char FFT[[id((3))]];
    char conjugate [[id((4))]];
} FFTInput;

kernel void fft_earlyStage(texture2d<float, access::read_write> inTexture [[texture(0)]], constant FFTEarlyInput &input[[buffer(0)]], uint2 gid [[thread_position_in_grid]]){
    int len = int(inTexture.get_width());
    
    for (int j = 0; j < input.lastStage; ++j) {
        int N = 2 << j;
        int navigator = 0;
        
        while (navigator < len){ // Size
            int b = navigator % N;
            if (b >= N / 2){
                navigator += N / 2;
                continue;
            }
            Complex twiddle = Complex{cos(input.FFT * 2 * M_PI_F * b / N), input.conjugate * sin(input.FFT * 2 * M_PI_F * b / N)};
            uint2 lowerGID = gid + uint2(navigator + N / 2, 0);
            uint2 upperGID = gid + uint2(navigator, 0);
            Complex upper = Complex{inTexture.read(upperGID).x, inTexture.read(upperGID).y};
            Complex lower = Complex{inTexture.read(lowerGID).x, inTexture.read(lowerGID).y};
            Complex twiddled = twiddle * lower;
            
            lower = upper - twiddled;
            upper = upper + twiddled;
            
            inTexture.write(float4(upper.real, upper.image, float2(0.0)), upperGID);
            inTexture.write(float4(lower.real, lower.image, float2(0.0)), lowerGID);
            navigator += 1;
        }
        
    }
    
}

kernel void testing(texture2d<float, access::read_write> texture [[texture(0)]], uint2 gid [[thread_position_in_grid]]){
    for(int i = 0; i < 36; i++ ){
        texture.write(float4(float3(0.7), 1.0), gid + uint2(i, 0));
    }
    
}

kernel void fft_allStage(texture2d<float, access::read_write> inTexture [[texture(0)]], constant FFTInput &input[[buffer(0)]], uint2 gid [[thread_position_in_grid]]){
    uint upper1D = to1D(gid, input.width);
    uint N = pow(2.0, input.stage);
    uint b = upper1D % N;
    
    // To judge if this thread is on upper side or lower side
    if (b >= N / 2){
        return;
    }
    
    Complex upper = Complex{inTexture.read(gid).x, inTexture.read(gid).y};
    uint lower1D = upper1D + N / 2;
    uint2 lower2D = to2D(lower1D, input.width);
    Complex lower = Complex{inTexture.read(lower2D).x, inTexture.read(lower2D).y};
    Complex twiddle = Complex{cos(input.FFT * 2 * M_PI_F * b / N), input.conjugate * sin(input.FFT * 2 * M_PI_F * b / N)};
    
    Complex twiddled = twiddle * lower;
    
    lower = upper - twiddled;
    upper = upper + twiddled;
    
    inTexture.write(float4(upper.real, upper.image, float2(0.0)), gid);
    inTexture.write(float4(lower.real, lower.image, float2(0.0)), lower2D);
}

uint2 shiftCood(float maxWidth, float maxHeight, uint2 gid){
    float halfWidth = maxWidth / 2.0;
    float halfHeight = maxWidth / 2.0;
    float quarterWidth = maxWidth / 4.0;
    float quarterHeight = maxHeight / 4.0;

    if (gid.x <= halfWidth){
        float2 distance, reference;
        if (gid.y <= halfHeight){
            reference = float2(quarterWidth, quarterHeight);
            distance = float2(reference.y - gid.y, reference.x - gid.x);
        }else{
            reference = float2(quarterWidth, maxHeight - quarterHeight);
            distance = float2(gid.y - reference.y, gid.x - reference.x);
        }
        return uint2(distance + reference);
    }else{
        float2 distance, reference;
        if (gid.y <= halfHeight){
            reference = float2(maxWidth - quarterWidth, quarterHeight);
            distance = float2(gid.y - reference.y, gid.x - reference.x);
        }else{
            reference = float2(maxWidth - quarterWidth, maxHeight - quarterHeight);
            distance = float2(reference.y - gid.y, reference.x - gid.x);
        }
        return uint2(distance + reference);
    }

    return uint2(0);
}

kernel void complexModulus(texture2d<float, access::read_write> inTexture [[texture(0)]], texture2d<float, access::read_write> outTexture [[texture(1)]], device uint *maxValue[[buffer(0)]], uint2 gid [[thread_position_in_grid]]){
    float modulus = sqrt(pow(inTexture.read(gid).x, 2) + pow(inTexture.read(gid).y, 2));
    uint2 newGID = shiftCood(float(inTexture.get_width() - 1), float(inTexture.get_width() - 1), gid);
    
    outTexture.write(float4(float3(modulus / float(maxValue[0])), 1.0), newGID);
}

// For LIME function

kernel void inverseCorrection(texture2d<float, access::read_write> inTexture [[texture(0)]], device uint *length[[buffer(0)]], uint2 gid [[thread_position_in_grid]]){
    float modulus = sqrt(pow(inTexture.read(gid).x / float(length[0]), 2) + pow(inTexture.read(gid).y / float(length[0]), 2));
    inTexture.write(float4(modulus, float3(0.0)), gid);
}

kernel void elementwiseMultiply(texture2d<float, access::read_write> recoveryTexture, texture2d<float, access::read_write> optimalMap, texture2d<float, access::read_write> result [[texture(2)]], texture2d<float, access::read_write> initialMap [[texture(3)]], uint2 gid [[thread_position_in_grid]]){
    float3 luminanceWeighting = float3(0.2125, 0.7154, 0.0721);
    float initialIll = initialMap.read(gid).x;
    float optimalIll = optimalMap.read(gid).x;
    
    float originalLuminance = dot(luminanceWeighting, recoveryTexture.read(gid).rgb * initialIll);
    float greyScale = clamp(originalLuminance - 0.62, 0.0, 0.33);
    float weight = clamp((1 - pow(greyScale, 3.0) * 28.0), 0.0, 1.0);
    float3 recovery = mix(initialIll, optimalIll, weight);
    result.write(float4(float3(recoveryTexture.read(gid).rgb * recovery), 1.0), gid);
}

kernel void illuminationMap(texture2d<float, access::read_write> inTexture [[texture(0)]], texture2d<float, access::read_write> outTexture [[texture(1)]], device int *referLength[[buffer(0)]], uint2 gid [[thread_position_in_grid]]){
    float illValues = 0.0;
    int2 signedGID = int2(gid);
    
    if(signedGID.x - referLength[0] / 2 < 0 || signedGID.y - referLength[0] / 2 < 0 || signedGID.x + referLength[0] / 2 > int(inTexture.get_width()) - 1 || signedGID.y + referLength[0] / 2 > int(inTexture.get_height()) - 1){
        float3 pixel = inTexture.read(gid).rgb;
        illValues = max(pixel.r, max(pixel.g, pixel.b));
    }else{
        for(int i = -(referLength[0] / 2); i <= referLength[0] / 2; i++){
            for(int j = -(referLength[0] / 2); j <= referLength[0] / 2; j++){
                uint2 cid = uint2(signedGID.x + i, signedGID.y + j); // current navigated position
                float3 neighbor = inTexture.read(cid).rgb;
                
                illValues += max(neighbor.r, max(neighbor.g, neighbor.b));
            }
        }
        illValues /= pow(referLength[0], 2.0);
    }

    outTexture.write(float4(float3(illValues), 1.0), gid);
}

kernel void illuminationMapForLIME(texture2d<float, access::read_write> inTexture [[texture(0)]], texture2d<float, access::read_write> outTexture [[texture(1)]], texture2d<float, access::read_write> recoveryTexture [[texture(2)]], device int *referLength[[buffer(0)]], uint2 gid [[thread_position_in_grid]]){
    float illValues = 0.0;
    int2 signedGID = int2(gid);
    float3 pixel = inTexture.read(gid).rgb;
    
    if(signedGID.x - referLength[0] / 2 < 0 || signedGID.y - referLength[0] / 2 < 0 || signedGID.x + referLength[0] / 2 > int(inTexture.get_width()) - 1 || signedGID.y + referLength[0] / 2 > int(inTexture.get_height()) - 1){
        illValues = max(pixel.r, max(pixel.g, pixel.b));
    }else{
        for(int i = -(referLength[0] / 2); i <= referLength[0] / 2; i++){
            for(int j = -(referLength[0] / 2); j <= referLength[0] / 2; j++){
                uint2 cid = uint2(signedGID.x + i, signedGID.y + j); // current navigated position
                float3 neighbor = inTexture.read(cid).rgb;
                
                illValues += max(neighbor.r, max(neighbor.g, neighbor.b));
            }
        }
        illValues /= pow(referLength[0], 2.0);
    }
    
    float3 recovery = pixel / illValues;
    outTexture.write(float4(illValues, float3(0.0)), gid);
    recoveryTexture.write(float4(recovery, 0.0), gid);
}

kernel void zUpdate(texture2d<float, access::read_write> G [[texture(0)]], texture2d<float, access::read_write> Z [[texture(1)]], texture2d<float, access::read_write> derivativeT [[texture(2)]], device float *u[[buffer(0)]], uint2 gid [[thread_position_in_grid]]){
    float2 zValue = Z.read(gid).xy;
    float2 minusValue = derivativeT.read(gid).xy - G.read(gid).xy;

    Z.write(float4(zValue + u[0] * minusValue, float2(0.0)), gid);
}
kernel void initGZ(texture2d<float, access::read_write> Z [[texture(0)]], texture2d<float, access::read_write> G [[texture(1)]], uint2 gid [[thread_position_in_grid]]){
    G.write(float4(0.0), gid);
    Z.write(float4(0.0), gid);
}

float4 neighborDetect(texture2d<float, access::read_write> inTexture, uint2 gid){
    float4 neighborMatrix;

    if (gid.x == 0){
        neighborMatrix.x = 0; //lowerHorizontalNeighbor
    }else{
        neighborMatrix.x = inTexture.read(gid - uint2(1, 0)).x;
    }

    if (gid.x >= inTexture.get_width() - 1){
        neighborMatrix.y = 0; // higherHorizontalNeighbor
    }else{
        neighborMatrix.y = inTexture.read(gid + uint2(1, 0)).x;
    }
    
    if (gid.y == 0){
        neighborMatrix.z = 0; //lowerVerticalNeighbor
    }else{
        neighborMatrix.z = inTexture.read(gid - uint2(0, 1)).x;
    }

    if (gid.y >= inTexture.get_height() - 1){
        neighborMatrix.w = 0; // higherVerticalNeighbor
    }else{
        neighborMatrix.w = inTexture.read(gid + uint2(0, 1)).x;
    }
    
    return neighborMatrix;
}

float4 twoChannelNeighborDetect(texture2d<float, access::read_write> inTexture, uint2 gid){
    float4 neighborMatrix;

    if (gid.x == 0){
        neighborMatrix.x = 0; //lowerHorizontalNeighbor
    }else{
        neighborMatrix.x = inTexture.read(gid - uint2(1, 0)).x;
    }

    if (gid.x >= inTexture.get_width() - 1){
        neighborMatrix.y = 0; // higherHorizontalNeighbor
    }else{
        neighborMatrix.y = inTexture.read(gid + uint2(1, 0)).x;
    }
    
    if (gid.y == 0){
        neighborMatrix.z = 0; //lowerVerticalNeighbor
    }else{
        neighborMatrix.z = inTexture.read(gid - uint2(0, 1)).y;
    }

    if (gid.y >= inTexture.get_height() - 1){
        neighborMatrix.w = 0; // higherVerticalNeighbor
    }else{
        neighborMatrix.w = inTexture.read(gid + uint2(0, 1)).y;
    }
    
    return neighborMatrix;
}

float firstDerivatives(float lower, float higher){
    return (higher - lower) / 2.0;
}

kernel void weightAssignment(texture2d<float, access::read_write> inTexture [[texture(0)]], texture2d<float, access::read_write> outTexture [[texture(1)]], uint2 gid [[thread_position_in_grid]]){
    
    float4 neighborValue = neighborDetect(inTexture, gid);
    float horizontalWeight = 1.0 / (abs(firstDerivatives(neighborValue.x, neighborValue.y)) + 10);
    float verticalWeight = 1.0 / (abs(firstDerivatives(neighborValue.z, neighborValue.w)) + 10);

    outTexture.write(float4(horizontalWeight, verticalWeight, float2(0.0)), gid);
}

kernel void getDerivativeT(texture2d<float, access::read_write> inTexture [[texture(0)]], texture2d<float, access::write> outTexture [[texture(1)]], uint2 gid [[thread_position_in_grid]]){
    float4 neighbor = neighborDetect(inTexture, gid);
    
    float horizontal = firstDerivatives(neighbor.x, neighbor.y);
    float vertical = firstDerivatives(neighbor.z, neighbor.w);
    
    outTexture.write(float4(horizontal, vertical, float2(0.0)), gid);
}

float2 shrinkage(float2 x, float2 epsilon){
    float xChannel = sign(x.x) * max(abs(x.x) - epsilon.x, 0.0);
    float yChannel = sign(x.y) * max(abs(x.y) - epsilon.y, 0.0);
    
    return float2(xChannel, yChannel);
}

kernel void gUpdate(texture2d<float, access::read_write> Z [[texture(0)]], texture2d<float, access::read_write> derivativeT [[texture(1)]], texture2d<float, access::read_write> weightMap [[texture(2)]], device float *u[[buffer(0)]], device float *alpha[[buffer(1)]],texture2d<float, access::read_write> G [[texture(3)]], uint2 gid [[thread_position_in_grid]]){
    float2 derivative = derivativeT.read(gid).xy;
    float2 zValue = Z.read(gid).xy;
    float2 floatU = float2(u[0]);
    float2 x = derivative + zValue / floatU;
    float2 weight = weightMap.read(gid).xy;

    G.write(float4(shrinkage(x, alpha[0] * weight / floatU), float2(0.0)), gid);
}

kernel void tUpperUpdate(texture2d<float, access::read_write> illT [[texture(0)]], texture2d<float, access::read_write> G [[texture(1)]], texture2d<float, access::read_write> Z [[texture(2)]], device float *u[[buffer(0)]], texture2d<float, access::write> outTexture [[texture(3)]], uint2 gid [[thread_position_in_grid]]){
    float valueT = illT.read(gid).x * 2;
    
    float4 gNeighbor = twoChannelNeighborDetect(G, gid);
    float4 zNeighbor = twoChannelNeighborDetect(Z, gid);
    
    float4 rightSide = gNeighbor - zNeighbor / float4(u[0]);
    float horizontal = rightSide.x - rightSide.y;
    float vertical = rightSide.z - rightSide.w;
    
    float result = valueT + u[0] * sqrt(pow(horizontal, 2) + pow(vertical, 2));
    outTexture.write(float4(result, float3(0.0)), gid);
}

kernel void tUpdate(device float *u[[buffer(0)]], texture2d<uint, access::read_write> largerD [[texture(0)]], texture2d<float, access::read_write> upperTexture [[texture(1)]], uint2 gid [[thread_position_in_grid]]){
    float2 value = upperTexture.read(gid).xy / (float2(largerD.read(gid).xy) * float2(u[0]) + float2(2));
    upperTexture.write(float4(value, float2(0.0)), gid);
}

kernel void initFullSizeD(texture2d<uint, access::read_write> outTexture [[texture(0)]], device uint *length[[buffer(0)]], uint2 gid [[thread_position_in_grid]]){
    
    uint2 central = uint2((outTexture.get_width() - 1) / 2, (outTexture.get_height() - 1) / 2);
    uint mark;
    if (gid.x == central.x ^ gid.y == central.y){
        mark = length[0];
    }else{
        mark = 0;
    }
    
    outTexture.write(uint4(uint2(mark), uint2(0)), gid);
}

kernel void gammaCorrection(texture2d<float, access::read_write> T [[texture(0)]], device float *gamma[[buffer(0)]], device uint *maxTValue[[buffer(1)]], uint2 gid [[thread_position_in_grid]]){
    float valueT = T.read(gid).x / float(maxTValue[0]);
    float powered = pow(valueT, gamma[0]);

    T.write(float4(powered * maxTValue[0], float3(0.0)), gid);
}

void atomicFindMaximum(volatile device atomic_uint *current, uint candidate){
    device uint *valuePtr = (device uint *)current;
    uint value = valuePtr[0];
    while (candidate > value && !atomic_compare_exchange_weak_explicit(current, &value, candidate, memory_order_relaxed, memory_order_relaxed)){
        
    }
}

kernel void findMaximumInThreadGroup(texture2d<float, access::read> inTexture [[texture(0)]], device uint *mapBuffer [[buffer(0)]], uint2 gid [[thread_position_in_grid]], uint2 tggid [[threadgroup_position_in_grid]], uint2 tgsize [[threadgroups_per_grid]]){
    uint value = uint(inTexture.read(gid).r);
    device atomic_uint *atomicBuffer = (device atomic_uint *)mapBuffer;

    atomicFindMaximum(atomicBuffer + (tggid[1] * tgsize[0] + tggid[0]), value);
}
