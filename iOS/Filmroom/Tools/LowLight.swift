//
//  LowLight.swift
//  Filmroom
//
//  Created by 周建明 on 10/4/2018.
//  Copyright © 2018年 Uncle Jerry. All rights reserved.
//

import Foundation
import UIKit
import Metal
import MetalKit

class LowLightImage{
    var input: MTLTexture
    var initIllMap: MTLTexture!
    var T: MTLTexture!
    var weight: MTLTexture!
    var derivativeT: MTLTexture!
    var G: MTLTexture!
    var Z: MTLTexture!
    var recoveryTexture: MTLTexture!
    var initialD: MTLTexture!
    var u: Float
    var p: Float
    var alpha: Float
    var width: UInt16
    var width_Int: Int
    var height: Int
    var length: UInt32

    init(input: MTLTexture, p: Float, alpha: Float){
        u = 0.5

        self.alpha = alpha
        self.p = p
        self.input = input
        width = UInt16(input.width)
        width_Int = input.width
        height = input.height
        length = UInt32(input.width * input.height)

        let TDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: width_Int, height: height, mipmapped: false)
        TDescriptor.usage = [MTLTextureUsage.shaderRead, MTLTextureUsage.shaderWrite]
        TDescriptor.storageMode = MTLStorageMode.private
        let GZDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg32Float, width: width_Int, height: height, mipmapped: false)
        GZDescriptor.usage = [MTLTextureUsage.shaderRead, MTLTextureUsage.shaderWrite]
        GZDescriptor.storageMode = MTLStorageMode.private
        let WeightDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg32Float, width: width_Int, height: height, mipmapped: false)
        WeightDescriptor.usage = [MTLTextureUsage.shaderRead, MTLTextureUsage.shaderWrite]
        WeightDescriptor.storageMode = MTLStorageMode.private
        let RecoveryDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgb10a2Unorm, width: width_Int, height: height, mipmapped: false)
        RecoveryDescriptor.storageMode = MTLStorageMode.private
        RecoveryDescriptor.usage = [MTLTextureUsage.shaderRead, MTLTextureUsage.shaderWrite]
        let IllMapDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: width_Int, height: height, mipmapped: false)
        IllMapDescriptor.storageMode = MTLStorageMode.private

        recoveryTexture = device.makeTexture(descriptor: RecoveryDescriptor)
        initIllMap = device.makeTexture(descriptor: IllMapDescriptor)
        derivativeT = device.makeTexture(descriptor: GZDescriptor)
        weight = device.makeTexture(descriptor: WeightDescriptor)
        T = device.makeTexture(descriptor: TDescriptor)
        G = device.makeTexture(descriptor: GZDescriptor)
        Z = device.makeTexture(descriptor: GZDescriptor)

        // Select library function
        let kernel = defaultLibrary.makeFunction(name: "illuminationMapForLIME")!
        // Set pipeline of Computation
        var pipelineState: MTLComputePipelineState!
        do{
            pipelineState = try device.makeComputePipelineState(function: kernel)
        }catch{
            fatalError("Set up failed")
        }


        let commandBuffer = commandQueue.makeCommandBuffer()

        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        let tw = pipelineState.threadExecutionWidth
        let th = pipelineState.maxTotalThreadsPerThreadgroup / tw

        let threadPerGroup = MTLSizeMake(tw, th, 1)
        let threadGroups: MTLSize = MTLSize(width: width_Int, height: height, depth: 1)

        commandEncoder?.setComputePipelineState(pipelineState)
        commandEncoder?.setTexture(input, index: 0)
        commandEncoder?.setTexture(initIllMap, index: 1)
        commandEncoder?.setTexture(recoveryTexture, index: 2)
        var referLength: Int32 = 5
        commandEncoder?.setBytes(&referLength, length: MemoryLayout<Int32>.stride, index: 0)

        commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
        commandEncoder?.endEncoding()

        // Push the assignment
        commandBuffer?.commit()
        generateWeight()
        initialD = initMatchedSizedD()
    }
    
    private func generateWeight() {
        let weightKernel = defaultLibrary.makeFunction(name: "weightAssignment")!

        // Set pipeline of Computation
        var pipelineState: MTLComputePipelineState!
        do{
            pipelineState = try device.makeComputePipelineState(function: weightKernel)
        }catch{
            fatalError("Set up failed")
        }

        let commandBuffer = commandQueue.makeCommandBuffer()

        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        let tw = pipelineState.threadExecutionWidth
        let th = pipelineState.maxTotalThreadsPerThreadgroup / tw

        let threadPerGroup = MTLSizeMake(tw, th, 1)
        let threadGroups: MTLSize = MTLSize(width: width_Int, height: height, depth: 1)

        commandEncoder?.setComputePipelineState(pipelineState)
        commandEncoder?.setTexture(T, index: 0)
        commandEncoder?.setTexture(weight, index: 1)
        commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
        commandEncoder?.endEncoding()

        // Push the assignment
        commandBuffer?.commit()
    }

    func updateT() {
        var kernel = defaultLibrary.makeFunction(name: "tUpperUpdate")!

        // Set pipeline of Computation
        var pipelineState: MTLComputePipelineState!
        do{
            pipelineState = try device.makeComputePipelineState(function: kernel)
        }catch{
            fatalError("Set up failed")
        }

        let upperDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float, width: width_Int, height: height, mipmapped: false)
        var upperTexture: MTLTexture! = device.makeTexture(descriptor: upperDescriptor)

        var commandBuffer = commandQueue.makeCommandBuffer()

        var commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        let tw = pipelineState.threadExecutionWidth
        let th = pipelineState.maxTotalThreadsPerThreadgroup / tw

        let threadPerGroup = MTLSizeMake(tw, th, 1)
        let threadGroups: MTLSize = MTLSize(width: width_Int, height: height, depth: 1)

        commandEncoder?.setComputePipelineState(pipelineState)
        commandEncoder?.setTexture(initIllMap, index: 0)
        commandEncoder?.setTexture(G, index: 1)
        commandEncoder?.setTexture(Z, index: 2)
        commandEncoder?.setTexture(upperTexture, index: 3)

        commandEncoder?.setBytes(&u, length: MemoryLayout<Float32>.stride, index: 0)
        commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
        commandEncoder?.endEncoding()

        // Push the assignment
        commandBuffer?.commit()


        upperTexture = FFT(inverseFactor: 1, conjugateFactor: 1, channel: 1, inputMap: upperTexture)


        kernel = defaultLibrary.makeFunction(name: "tUpdate")!

        // Set pipeline of Computation
        do{
            pipelineState = try device.makeComputePipelineState(function: kernel)
        }catch{
            fatalError("Set up failed")
        }

        commandBuffer = commandQueue.makeCommandBuffer()
        commandEncoder = commandBuffer?.makeComputeCommandEncoder()

        commandEncoder?.setComputePipelineState(pipelineState)
        commandEncoder?.setTexture(initialD, index: 0)
        commandEncoder?.setTexture(upperTexture, index: 1)

        commandEncoder?.setBytes(&u, length: MemoryLayout<Float32>.stride, index: 0)
        commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
        commandEncoder?.endEncoding()

        // Push the assignment
        commandBuffer?.commit()

        T = FFT(inverseFactor: -1, conjugateFactor: 1, channel: 2, inputMap: upperTexture)
        upperTexture = nil

        
        kernel = defaultLibrary.makeFunction(name: "getDerivativeT")!
        
        // Set pipeline of Computation
        do{
            pipelineState = try device.makeComputePipelineState(function: kernel)
        }catch{
            fatalError("Set up failed")
        }
        
        commandBuffer = commandQueue.makeCommandBuffer()
        commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        
        commandEncoder?.setComputePipelineState(pipelineState)
        commandEncoder?.setTexture(T, index: 0)
        commandEncoder?.setTexture(derivativeT, index: 1)
        
        commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
        commandEncoder?.endEncoding()
        
        // Push the assignment
        commandBuffer?.commit()
        
    }
    
    func updateG() {
        let gUpdateKernel = defaultLibrary.makeFunction(name: "gUpdate")!

        // Set pipeline of Computation
        var pipelineState: MTLComputePipelineState!
        do{
            pipelineState = try device.makeComputePipelineState(function: gUpdateKernel)
        }catch{
            fatalError("Set up failed")
        }

        let commandBuffer = commandQueue.makeCommandBuffer()

        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        let tw = pipelineState.threadExecutionWidth
        let th = pipelineState.maxTotalThreadsPerThreadgroup / tw

        let threadPerGroup = MTLSizeMake(tw, th, 1)
        let threadGroups: MTLSize = MTLSize(width: width_Int, height: height, depth: 1)

        commandEncoder?.setComputePipelineState(pipelineState)
        commandEncoder?.setTexture(Z, index: 0)
        commandEncoder?.setTexture(derivativeT, index: 1)
        commandEncoder?.setTexture(weight, index: 2)
        commandEncoder?.setTexture(G, index: 3)

        commandEncoder?.setBytes(&u, length: MemoryLayout<Float32>.stride, index: 0)
        commandEncoder?.setBytes(&alpha, length: MemoryLayout<Float32>.stride, index: 1)

        commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
        commandEncoder?.endEncoding()

        // Push the assignment
        commandBuffer?.commit()
    }
    
    func updateZu() {

        // Select library function
        let zuUpdateKernel = defaultLibrary.makeFunction(name: "zUpdate")!
        // Set pipeline of Computation
        var pipelineState: MTLComputePipelineState!
        do{
            pipelineState = try device.makeComputePipelineState(function: zuUpdateKernel)
        }catch{
            fatalError("Set up failed")
        }


        let commandBuffer = commandQueue.makeCommandBuffer()

        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        let tw = pipelineState.threadExecutionWidth
        let th = pipelineState.maxTotalThreadsPerThreadgroup / tw

        let threadPerGroup = MTLSizeMake(tw, th, 1)
        let threadGroups: MTLSize = MTLSize(width: width_Int, height: height, depth: 1)

        commandEncoder?.setComputePipelineState(pipelineState)
        commandEncoder?.setTexture(G, index: 0)
        commandEncoder?.setTexture(Z, index: 1)
        commandEncoder?.setTexture(derivativeT, index: 2)

        commandEncoder?.setBytes(&u, length: MemoryLayout<Float32>.stride, index: 0)

        commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
        commandEncoder?.endEncoding()

        // Push the assignment
        commandBuffer?.commit()
        commandBuffer?.waitUntilCompleted()

        self.u *= self.p
    }

    private func FFT(inverseFactor: Int8, conjugateFactor: Int8, channel: Int, inputMap: MTLTexture) -> MTLTexture{
        var repositionName: String!
        if channel == 2{
            repositionName = "reposition2Channel"
        }else{
            repositionName = "reposition"
        }
        // Select library function
        var kernel = defaultLibrary.makeFunction(name: repositionName)!

        // Set pipeline of Computation
        var pipelineState: MTLComputePipelineState!
        do{
            pipelineState = try device.makeComputePipelineState(function: kernel)
        }catch{
            fatalError("Set up failed")
        }

        /*
         * Create new texture for store the pixel data,
         * or say any data that requires to be processed by the FFT function
         */

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg32Float, width: width_Int, height: height, mipmapped: false)
        textureDescriptor.usage = [MTLTextureUsage.shaderRead, MTLTextureUsage.shaderWrite]
        var resultTexture: MTLTexture!
        resultTexture = device.makeTexture(descriptor: textureDescriptor)


        // config the group number and group size
        var commandBuffer = commandQueue.makeCommandBuffer()
        var commandEncoder = commandBuffer?.makeComputeCommandEncoder()

        /* Figure out the:

         * The number of threads that are scheduled to execute the same instruction
         in a compute function at a time.
         * The largest number of threads that can be in one threadgroup.

         */

        let tw = pipelineState.threadExecutionWidth
        let th = pipelineState.maxTotalThreadsPerThreadgroup / tw

        let threadPerGroup = MTLSizeMake(tw, th, 1)
        let threadGroups: MTLSize = MTLSize(width: width_Int, height: height, depth: 1)


        // Set texture in kernel
        commandEncoder?.setComputePipelineState(pipelineState)
        commandEncoder?.setTexture(inputMap, index: 0)
        commandEncoder?.setTexture(resultTexture, index: 1)
        
        let argumentEncoder = kernel.makeArgumentEncoder(bufferIndex: 0)
        let encodedLengthBuffer = device.makeBuffer(length:argumentEncoder.encodedLength, options: MTLResourceOptions.storageModeShared)
        
        // Set argument buffer and texture in kernel function
        commandEncoder?.setComputePipelineState(pipelineState)
        
        argumentEncoder.setArgumentBuffer(encodedLengthBuffer!, offset: 0)
        
        argumentEncoder.constantData(at: 2).storeBytes(of: width, toByteOffset: 0, as: UInt16.self)
        argumentEncoder.constantData(at: 1).storeBytes(of: length, toByteOffset: 0, as: UInt32.self)
        commandEncoder?.setBuffer(encodedLengthBuffer, offset: 0, index: 0)
        // Config the thread setting
        commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
        commandEncoder?.endEncoding()

        // Push the configuration and assignments to GPU
        commandBuffer?.commit()

        // Above, finished the rearrangment

        // Load function of FFT calculation
        kernel = defaultLibrary.makeFunction(name: "fft_earlyStage")!
        
        do{
            pipelineState = try device.makeComputePipelineState(function: kernel)
        }catch{
            fatalError("Set up failed")
        }
        
        commandBuffer = commandQueue.makeCommandBuffer()
        commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        
        // Set texture in kernel
        commandEncoder?.setComputePipelineState(pipelineState)
        commandEncoder?.setTexture(resultTexture, index: 0)
        // Adjust the FFT and complexConjugate to get inverse or complex conjugate
        let argumentEncoder2 = kernel.makeArgumentEncoder(bufferIndex: 0)
        let encodedLengthBuffer2 = device.makeBuffer(length:argumentEncoder2.encodedLength, options: MTLResourceOptions.storageModeShared)
        
        // Calculate the total stage and begining stage for next step
        let totalStage = Int(log2(Float(length)))
        let startStage = Int(log2(Float(width))) + 1
        
        // Set argument buffer and texture in kernel function
        commandEncoder?.setBuffer(encodedLengthBuffer2, offset: 0, index: 0)
        argumentEncoder2.setArgumentBuffer(encodedLengthBuffer2!, offset: 0)
        argumentEncoder2.constantData(at: 1).storeBytes(of: inverseFactor, toByteOffset: 0, as: Int8.self)
        argumentEncoder2.constantData(at: 2).storeBytes(of: conjugateFactor, toByteOffset: 0, as: Int8.self)
        argumentEncoder2.constantData(at: 3).storeBytes(of: Int32(startStage - 1), toByteOffset: 0, as: Int32.self)
        
        let narrowThreadPerGroup = MTLSizeMake(1, tw, 1)
        let narrowThreadGroups: MTLSize = MTLSize(width: 1, height: height, depth: 1)
        
        commandEncoder?.dispatchThreads(narrowThreadGroups, threadsPerThreadgroup: narrowThreadPerGroup)
        commandEncoder?.endEncoding()
        
        // Push the assignment
        commandBuffer?.commit()
        
        kernel = defaultLibrary.makeFunction(name: "fft_allStage")!
        // Set pipeline of Computation
        do{
            pipelineState = try device.makeComputePipelineState(function: kernel)
        }catch{
            fatalError("Set up failed")
        }


        // Adjust the FFT and complexConjugate to get inverse or complex conjugate
        let FFTFactor: Int8 = inverseFactor
        let complexConjugate: Int8 = conjugateFactor
        
        commandBuffer?.waitUntilCompleted()
        // Set texture in kernel
        for index in startStage...totalStage{
            // Start steps of FFT -- Calculate each row
            // Refresh the command buffer and encoder for each stage
            commandBuffer = commandQueue.makeCommandBuffer()
            commandEncoder = commandBuffer?.makeComputeCommandEncoder()
            commandEncoder?.setComputePipelineState(pipelineState)
            commandEncoder?.setTexture(resultTexture, index: 0)
            
            let argumentEncoder = kernel.makeArgumentEncoder(bufferIndex: 0)
            
            let encodedLengthBuffer = device.makeBuffer(length:argumentEncoder.encodedLength, options: MTLResourceOptions.storageModeShared)
            
            // Set argument buffer and texture in kernel function
            commandEncoder?.setBuffer(encodedLengthBuffer, offset: 0, index: 0)
            argumentEncoder.setArgumentBuffer(encodedLengthBuffer!, offset: 0)
            argumentEncoder.constantData(at: 1).storeBytes(of: width, toByteOffset: 0, as: UInt16.self)
            argumentEncoder.constantData(at: 2).storeBytes(of: UInt8(index), toByteOffset: 0, as: UInt8.self)
            argumentEncoder.constantData(at: 3).storeBytes(of: FFTFactor, toByteOffset: 0, as: Int8.self)
            argumentEncoder.constantData(at: 4).storeBytes(of: complexConjugate, toByteOffset: 0, as: Int8.self)

            commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
            commandEncoder?.endEncoding()

            // Push the assignment
            commandBuffer?.commit()
        }

        if inverseFactor == -1 {

            // Load function of FFT calculation
            kernel = defaultLibrary.makeFunction(name: "inverseCorrection")!
            // Set pipeline of Computation
            do{
            pipelineState = try device.makeComputePipelineState(function: kernel)
            }catch{
            fatalError("Set up failed")
            }

            commandBuffer = commandQueue.makeCommandBuffer()
            commandEncoder = commandBuffer?.makeComputeCommandEncoder()

            commandEncoder?.setComputePipelineState(pipelineState)
            commandEncoder?.setTexture(resultTexture, index: 0)

            commandEncoder?.setBytes(&length, length: MemoryLayout<uint>.stride, index: 0)

            commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
            commandEncoder?.endEncoding()

            // Push the assignment
            commandBuffer?.commit()
            commandBuffer?.waitUntilCompleted()
        }
        

        return resultTexture
    }

    private func initMatchedSizedD() -> MTLTexture{
        // Select library function
        let updateKernel = defaultLibrary.makeFunction(name: "initFullSizeD")!
        // Set pipeline of Computation
        var pipelineState: MTLComputePipelineState!
        do{
            pipelineState = try device.makeComputePipelineState(function: updateKernel)
        }catch{
            fatalError("Set up failed")
        }

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg32Uint, width: width_Int, height: height, mipmapped: false)
        textureDescriptor.usage = [MTLTextureUsage.shaderRead, MTLTextureUsage.shaderWrite]
        textureDescriptor.storageMode = MTLStorageMode.private
        var initialTexture: MTLTexture!
        initialTexture = device.makeTexture(descriptor: textureDescriptor)

        let commandBuffer = commandQueue.makeCommandBuffer()

        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        let tw = pipelineState.threadExecutionWidth
        let th = pipelineState.maxTotalThreadsPerThreadgroup / tw

        let threadPerGroup = MTLSizeMake(tw, th, 1)
        let threadGroups: MTLSize = MTLSize(width: width_Int, height: height, depth: 1)

        commandEncoder?.setComputePipelineState(pipelineState)
        commandEncoder?.setTexture(initialTexture, index: 0)
        commandEncoder?.setBytes(&length, length: MemoryLayout<uint>.stride, index: 0)
        commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
        commandEncoder?.endEncoding()

        // Push the assignment
        commandBuffer?.commit()

        return initialTexture
    }
    
    func gammaCorrection(inputGamma: Float) {
        let kernel = defaultLibrary.makeFunction(name: "findMaximumInThreadGroup")!
        var pipelineState: MTLComputePipelineState!
        do{
            pipelineState = try device.makeComputePipelineState(function: kernel)
        }catch{
            fatalError("Set up failed")
        }

        var commandBuffer = commandQueue.makeCommandBuffer()
        var commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        let tw = pipelineState.threadExecutionWidth
        let th = pipelineState.maxTotalThreadsPerThreadgroup / tw

        let threadPerGroup = MTLSizeMake(tw, th, 1)
        let threadGroups: MTLSize = MTLSize(width: width_Int, height: height, depth: 1)
        let groupNum = Int(ceil(Float(width_Int) / Float(threadPerGroup.width)) * ceil(Float(height) / Float(threadPerGroup.height)))
        var maxValuePerGroup = [UInt32](repeating: 0, count: groupNum)

        let bufferMax = device.makeBuffer(bytes: &maxValuePerGroup, length: MemoryLayout<uint>.size * groupNum, options: MTLResourceOptions.storageModeShared)

        commandEncoder?.setComputePipelineState(pipelineState)
        commandEncoder?.setTexture(T, index: 0)
        commandEncoder?.setBuffer(bufferMax, offset: 0, index: 0)

        commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
        commandEncoder?.endEncoding()
        
        // Push the assignment
        commandBuffer?.commit()
        commandBuffer?.waitUntilCompleted()
        let resultPointer = bufferMax?.contents().bindMemory(to: UInt32.self, capacity: groupNum)
        for index in 0..<groupNum {
            maxValuePerGroup[index] = resultPointer![index]
        }
        
        var maxValue: UInt32 = maxValuePerGroup.max()!
        
        print(maxValue)
        
        // Select library function
        let gammaKernel = defaultLibrary.makeFunction(name: "gammaCorrection")!
        // Set pipeline of Computation
        do{
            pipelineState = try device.makeComputePipelineState(function: gammaKernel)
        }catch{
            fatalError("Set up failed")
        }
        
        var gamma = inputGamma
        commandBuffer = commandQueue.makeCommandBuffer()
        commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        
        commandEncoder?.setComputePipelineState(pipelineState)
        commandEncoder?.setTexture(T, index: 0)
        commandEncoder?.setBytes(&gamma, length: MemoryLayout<Float>.stride, index: 0)
        commandEncoder?.setBytes(&maxValue, length: MemoryLayout<uint>.stride, index: 1)
        commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
        commandEncoder?.endEncoding()
        
        // Push the assignment
        commandBuffer?.commit()
    }
    
    func recoverImage() -> MTLTexture {
        // Select library function
        let updateKernel = defaultLibrary.makeFunction(name: "elementwiseMultiply")!
        // Set pipeline of Computation
        var pipelineState: MTLComputePipelineState!
        do{
            pipelineState = try device.makeComputePipelineState(function: updateKernel)
        }catch{
            fatalError("Set up failed")
        }
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width_Int, height: height, mipmapped: false)
        //textureDescriptor.usage = MTLTextureUsage.shaderRead
        var recoveredTexture: MTLTexture!
        recoveredTexture = device.makeTexture(descriptor: textureDescriptor)
        
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        let tw = pipelineState.threadExecutionWidth
        let th = pipelineState.maxTotalThreadsPerThreadgroup / tw
        
        let threadPerGroup = MTLSizeMake(tw, th, 1)
        let threadGroups: MTLSize = MTLSize(width: width_Int, height: height, depth: 1)
        
        commandEncoder?.setComputePipelineState(pipelineState)
        commandEncoder?.setTexture(recoveryTexture, index: 0)
        commandEncoder?.setTexture(T, index: 1)
        commandEncoder?.setTexture(recoveredTexture, index: 2)
        commandEncoder?.setTexture(initIllMap, index: 3)
        
        
        commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
        commandEncoder?.endEncoding()
        
        // Push the assignment
        commandBuffer?.commit()
        commandBuffer?.waitUntilCompleted()
        
        return recoveredTexture
    }
}
