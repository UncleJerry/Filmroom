//
//  ViewController.swift
//  Filmroom
//
//  Created by 周建明.
//  Copyright © 2018年 Uncle Jerry. All rights reserved.
//

import UIKit
import Metal
import MetalKit


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MTKViewDelegate {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        if let currentDrawable = view.currentDrawable {
            
            if complexOperation != 0{
                var commandBuffer = commandQueue.makeCommandBuffer()
                metalview.isPaused = true
                                
                if complexOperation == 1{
                    let timer = Timer()
                    // Select library function
                    let reOrderKernel = defaultLibrary.makeFunction(name: "reposition4ColorImage")!
                    
                    // Set pipeline of Computation
                    var pipelineState: MTLComputePipelineState!
                    do{
                        pipelineState = try device.makeComputePipelineState(function: reOrderKernel)
                    }catch{
                        fatalError("Set up failed")
                    }
                    
                    /*
                     * Create new texture for store the pixel data,
                     * or say any data that requires to be processed by the FFT function
                     */
                    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg32Float, width: sourceTexture.width, height: sourceTexture.height, mipmapped: false)
                    var reorderedTexture: MTLTexture!
                    reorderedTexture = device.makeTexture(descriptor: textureDescriptor)
                    
                    
                    // config the group number and group size
                    var commandEncoder = commandBuffer?.makeComputeCommandEncoder()
                    
                    /* Figure out the:
                     
                     * The number of threads that are scheduled to execute the same instruction
                     in a compute function at a time.
                     * The largest number of threads that can be in one threadgroup.
                     
                     */
                    let tw = pipelineState.threadExecutionWidth
                    let th = pipelineState.maxTotalThreadsPerThreadgroup / tw
                    
                    let threadPerGroup = MTLSizeMake(tw, th, 1)
                    let threadGroups: MTLSize = MTLSize(width: self.sourceTexture.width, height: self.sourceTexture.height, depth: 1)
                    
                    
                    // Set texture in kernel
                    commandEncoder?.setComputePipelineState(pipelineState)
                    commandEncoder?.setTexture(metalview.currentDrawable?.texture, index: 0)
                    commandEncoder?.setTexture(reorderedTexture, index: 1)

                    // Pass width and length data to GPU
                    let width: UInt16 = UInt16(self.sourceTexture.width)
                    let length: UInt32 = UInt32(self.sourceTexture.width * self.sourceTexture.height)

                    let argumentEncoder = reOrderKernel.makeArgumentEncoder(bufferIndex: 0)
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

                    // Above, finished the re-arrangment
                    
                    // Adjust the FFT and complexConjugate to get inverse or complex conjugate
                    let FFTFactor: Int8 = 1
                    let complexConjugate: Int8 = 1
                    
                    // Load function of FFT calculation
                    let fftEarlyStageKernel = defaultLibrary.makeFunction(name: "fft_earlyStage")
                    
                    do{
                        pipelineState = try device.makeComputePipelineState(function: fftEarlyStageKernel!)
                    }catch{
                        fatalError("Set up failed")
                    }
                    
                    commandBuffer = commandQueue.makeCommandBuffer()
                    commandEncoder = commandBuffer?.makeComputeCommandEncoder()
                    
                    // Set texture in kernel
                    commandEncoder?.setComputePipelineState(pipelineState)
                    commandEncoder?.setTexture(reorderedTexture, index: 0)
                    // Adjust the FFT and complexConjugate to get inverse or complex conjugate
                    let argumentEncoder2 = fftEarlyStageKernel!.makeArgumentEncoder(bufferIndex: 0)
                    
                    let encodedLengthBuffer2 = device.makeBuffer(length:argumentEncoder2.encodedLength, options: MTLResourceOptions.storageModeShared)
                    
                    // Calculate the total stage and begining stage for next step
                    let totalStage = Int(log2(Float(length)))
                    let startStage = Int(log2(Float(width))) + 1
                    
                    // Set argument buffer and texture in kernel function
                    commandEncoder?.setBuffer(encodedLengthBuffer2, offset: 0, index: 0)
                    argumentEncoder2.setArgumentBuffer(encodedLengthBuffer2!, offset: 0)
                    argumentEncoder2.constantData(at: 1).storeBytes(of: FFTFactor, toByteOffset: 0, as: Int8.self)
                    argumentEncoder2.constantData(at: 2).storeBytes(of: complexConjugate, toByteOffset: 0, as: Int8.self)
                    argumentEncoder2.constantData(at: 3).storeBytes(of: Int32(startStage - 1), toByteOffset: 0, as: Int32.self)

                    
                    let narrowThreadPerGroup = MTLSizeMake(1, tw, 1)
                    let narrowThreadGroups: MTLSize = MTLSize(width: 1, height: self.sourceTexture.height, depth: 1)
                    
                    commandEncoder?.dispatchThreads(narrowThreadGroups, threadsPerThreadgroup: narrowThreadPerGroup)
                    commandEncoder?.endEncoding()
                    
                    // Push the assignment
                    commandBuffer?.commit()
                    
                    let fftStageKernel = defaultLibrary.makeFunction(name: "fft_allStage")
                    // Set pipeline of Computation
                    do{
                        pipelineState = try device.makeComputePipelineState(function: fftStageKernel!)
                    }catch{
                        fatalError("Set up failed")
                    }
                    
                    
                    
                    commandBuffer?.waitUntilCompleted()
                    // Set texture in kernel
                    for index in startStage...totalStage{
                        // Start steps of FFT -- Calculate each row
                        // Refresh the command buffer and encoder for each stage
                        commandBuffer = commandQueue.makeCommandBuffer()
                        commandEncoder = commandBuffer?.makeComputeCommandEncoder()
                        commandEncoder?.setComputePipelineState(pipelineState)
                        commandEncoder?.setTexture(reorderedTexture, index: 0)

                        // Adjust the FFT and complexConjugate to get inverse or complex conjugate
                        let argumentEncoder3 = fftStageKernel!.makeArgumentEncoder(bufferIndex: 0)

                        let encodedLengthBuffer3 = device.makeBuffer(length:argumentEncoder3.encodedLength, options: MTLResourceOptions.storageModeShared)

                        // Set argument buffer and texture in kernel function
                        commandEncoder?.setBuffer(encodedLengthBuffer3, offset: 0, index: 0)
                        argumentEncoder3.setArgumentBuffer(encodedLengthBuffer3!, offset: 0)
                        argumentEncoder3.constantData(at: 1).storeBytes(of: width, toByteOffset: 0, as: UInt16.self)
                        argumentEncoder3.constantData(at: 2).storeBytes(of: UInt8(index), toByteOffset: 0, as: UInt8.self)
                        argumentEncoder3.constantData(at: 3).storeBytes(of: FFTFactor, toByteOffset: 0, as: Int8.self)
                        argumentEncoder3.constantData(at: 4).storeBytes(of: complexConjugate, toByteOffset: 0, as: Int8.self)

                        commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
                        commandEncoder?.endEncoding()
                        
                        // Push the assignment
                        commandBuffer?.commit()
                        
                    }
                    
                    let findingMaxKernel = defaultLibrary.makeFunction(name: "findMaximumInThreadGroup")!
                    do{
                        pipelineState = try device.makeComputePipelineState(function: findingMaxKernel)
                    }catch{
                        fatalError("Set up failed")
                    }
                    
                    commandBuffer = commandQueue.makeCommandBuffer()
                    commandEncoder = commandBuffer?.makeComputeCommandEncoder()
                    
                    let groupheight = ceil(Float(self.sourceTexture.height) / Float(threadPerGroup.height))
                    let groupwidth = ceil(Float(self.sourceTexture.width) / Float(threadPerGroup.width))
                    let groupNum: Int = Int(groupwidth) * Int(groupheight)
                    var maxValuePerGroup = [UInt32](repeating: 0, count: groupNum)
                    
                    let bufferMax = device.makeBuffer(bytes: &maxValuePerGroup, length: MemoryLayout<uint>.size * groupNum, options: MTLResourceOptions.storageModeShared)
                    
                    commandEncoder?.setComputePipelineState(pipelineState)
                    commandEncoder?.setTexture(reorderedTexture, index: 0)
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
                    
                    var correctionFactor = maxValuePerGroup.max()! / 1000
                    
                    // Load function of FFT calculation
                    let modulusKernel = defaultLibrary.makeFunction(name: "complexModulus")
                    // Set pipeline of Computation
                    do{
                        pipelineState = try device.makeComputePipelineState(function: modulusKernel!)
                    }catch{
                        fatalError("Set up failed")
                    }
                    
                    let resultDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: sourceTexture.width, height: sourceTexture.height, mipmapped: false)
                    var resultTexture: MTLTexture!
                    resultTexture = device.makeTexture(descriptor: resultDescriptor)
                    
                    commandBuffer = commandQueue.makeCommandBuffer()
                    commandEncoder = commandBuffer?.makeComputeCommandEncoder()
                    
                    commandEncoder?.setComputePipelineState(pipelineState)
                    commandEncoder?.setTexture(reorderedTexture, index: 0)
                    commandEncoder?.setTexture(resultTexture, index: 1)
                    commandEncoder?.setBytes(&correctionFactor, length: MemoryLayout<uint>.stride, index: 0)
                    commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
                    commandEncoder?.endEncoding()
                    
                    // Push the assignment
                    commandBuffer?.commit()
                    commandBuffer?.waitUntilCompleted()
                    timer.stop()
                    timer.showTime()
                    sourceTexture = resultTexture
                    inputImage = CIImage(mtlTexture: resultTexture, options: nil)
                }else if complexOperation == 2{
                    // Select library function
                    let illMapKernel = defaultLibrary.makeFunction(name: "illuminationMap")!
                    
                    // Set pipeline of Computation
                    var pipelineState: MTLComputePipelineState!
                    do{
                        pipelineState = try device.makeComputePipelineState(function: illMapKernel)
                    }catch{
                        fatalError("Set up failed")
                    }
                    
                    commandBuffer = commandQueue.makeCommandBuffer()
                    let resultDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: sourceTexture.width, height: sourceTexture.height, mipmapped: false)
                    var resultTexture: MTLTexture!
                    resultTexture = device.makeTexture(descriptor: resultDescriptor)
                    
                    let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
                    let tw = pipelineState.threadExecutionWidth
                    let th = pipelineState.maxTotalThreadsPerThreadgroup / tw
                    
                    let threadPerGroup = MTLSizeMake(tw, th, 1)
                    let threadGroups: MTLSize = MTLSize(width: self.sourceTexture.width, height: self.sourceTexture.height, depth: 1)
                    
                    commandEncoder?.setComputePipelineState(pipelineState)
                    commandEncoder?.setTexture(self.sourceTexture, index: 0)
                    commandEncoder?.setTexture(resultTexture, index: 1)
                    
                    var referRadius: Int32 = 9
                    commandEncoder?.setBytes(&referRadius, length: MemoryLayout<Int32>.stride, index: 0)
                    
                    commandEncoder?.dispatchThreads(threadGroups, threadsPerThreadgroup: threadPerGroup)
                    commandEncoder?.endEncoding()
                    
                    // Push the assignment
                    commandBuffer?.commit()
                    commandBuffer?.waitUntilCompleted()
                    
                    sourceTexture = resultTexture
                    inputImage = CIImage(mtlTexture: resultTexture, options: nil)
                }else if complexOperation == 3 {
                    let limeObject = LowLightImage(input: self.sourceTexture, p: 1.2, alpha: 0.3)
                    let loopTime = 4
                    for _ in 0...loopTime{
                        limeObject.updateT()
                        limeObject.updateG()
                        limeObject.updateZu()
                    }

                    limeObject.gammaCorrection(inputGamma: 0.6)
                    let result = limeObject.recoverImage()
                    
                    if loopTime <= 5 {
                        sourceTexture = result
                        inputImage = CIImage(mtlTexture: result, options: nil)
                    }else{
                        let denoise = CIFilter(name: "CINoiseReduction")
                        denoise?.setDefaults()
                        let resultCIImage = CIImage(mtlTexture: result, options: nil)
                        denoise?.setValue(resultCIImage, forKey: kCIInputImageKey)
                        denoise?.setValue(0.02, forKey: "inputNoiseLevel")
                        
                        inputImage = denoise?.outputImage
                    }
                    
                }
                
                complexOperation = 0
                metalview.isPaused = false
            }
            
            let exposure = ExposureFilter()
            let expoUnit = ExpSlider.value
            
            let shadow = ShadowFilter()
            let shadowUnit = ShadowSlider.value
            
            let highlight = HighlightFilter()
            let hlUnit = HLSlider.value
 
            
            let hsv = HSLFilter()
            let shift = CIVector(x: CGFloat(HueSlider.value), y: CGFloat(SatSlider.value), z: CGFloat(LumSlider.value))
            
            let contrast = ContrastFilter()
            let contrastUnit = ContrastSlider.value
            
            let saturation = SaturationFilter()
            let satUnit = SaturationSlider.value
            
            exposure.inputImage = inputImage
            exposure.inputUnit = CGFloat(expoUnit)
            
            shadow.inputImage = exposure.outputImage
            shadow.inputUnit = CGFloat(shadowUnit)
            
            highlight.inputImage = shadow.outputImage
            highlight.inputUnit = CGFloat(hlUnit)
            
            contrast.inputImage = highlight.outputImage
            contrast.inputUnit = CGFloat(contrastUnit)
            
            saturation.inputImage = contrast.outputImage
            saturation.inputUnit = CGFloat(satUnit)
            
            hsv.inputImage = saturation.outputImage
            hsv.inputShift0 = shift
            
            
            resultImage = hsv.outputImage
            
            let commandBuffer = commandQueue.makeCommandBuffer()
            context.render(hsv.outputImage, to: currentDrawable.texture, commandBuffer: commandBuffer, bounds: inputImage.extent, colorSpace: colorSpace)
            
            commandBuffer?.present(currentDrawable)
            commandBuffer?.commit()
            
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        complexOperation = 0
        picker.delegate = self
        
        textureLoader = MTKTextureLoader(device: device)
        
        // Load the start image
        do {
            try sourceTexture = textureLoader.newTexture(name: "Welcome", scaleFactor: 2.0, bundle: Bundle.main, options: [MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft, MTKTextureLoader.Option.textureStorageMode: MTLStorageMode.shared.rawValue])
            
        } catch  {
            print("fail to read")
        }
        
        inputImage = CIImage(mtlTexture: sourceTexture)!
        // Set up MTKView
        metalview = MTKView(frame: CGRect(x: 30, y: 50, width: 200, height: 200), device: device)
        
        metalview.delegate = self
        metalview.framebufferOnly = false
        // Save the depth drawable to lower memory increasing
        metalview.sampleCount = 1
        metalview.depthStencilPixelFormat = .invalid
        metalview.preferredFramesPerSecond = 24
        metalview.clearColor = .init(red: 1, green: 1, blue: 1, alpha: 1)
        
        // Set the correct draw size
        metalview.drawableSize = CGSize(width: sourceTexture.width, height: sourceTexture.height)
        view.addSubview(metalview)
        
        // Link the cicontext
        context = CIContext(mtlDevice: device)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    @IBOutlet weak var SatSlider: UISlider!
    @IBOutlet weak var HueSlider: UISlider!
    @IBOutlet weak var SaturationSlider: UISlider!
    @IBOutlet weak var LumSlider: UISlider!
    @IBOutlet weak var ExpSlider: UISlider!
    @IBOutlet weak var ContrastSlider: UISlider!
    @IBOutlet weak var HLSlider: UISlider!
    @IBOutlet weak var ShadowSlider: UISlider!
    
    let picker = UIImagePickerController()
    var resultImage: CIImage?
    // Core Image resources
    var context: CIContext!
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    
    // Variable for light-weight filter input
    var baseCIImage: CIImage?
    var inputImage: CIImage!
    var complexOperation: Int!
    var metalview: MTKView!
    var textureLoader: MTKTextureLoader!
    var sourceTexture: MTLTexture!
    
    
    @IBAction func LoadImage(_ sender: UIButton) {
        
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary)!
        
        HueSlider.value = 0//0.0828158104110671
        SatSlider.value = 1
        LumSlider.value = 1
        ExpSlider.value = 0
        ContrastSlider.value = 1
        SatSlider.value = 1
        HLSlider.value = 0
        ShadowSlider.value = 0
        
        present(picker, animated: true, completion: nil)
    }
    
    @IBAction func SaveImage(_ sender: UIButton) {
        
        // Covert the MTLTexture to UIImage for IO Operation
        let toBeSaved = metalview.currentDrawable?.texture.toUIImage
        
        let vc = UIActivityViewController(activityItems: [toBeSaved!], applicationActivities: [])
        vc.excludedActivityTypes =  [
            //UIActivityTypePostToTwitter,
            UIActivity.ActivityType.postToFacebook,
            //UIActivityType.postToWeibo,
            UIActivity.ActivityType.message,
            //UIActivityTypeMail,
            UIActivity.ActivityType.print,
            UIActivity.ActivityType.copyToPasteboard,
            UIActivity.ActivityType.assignToContact,
            //UIActivityType.saveToCameraRoll,
            UIActivity.ActivityType.addToReadingList,
            UIActivity.ActivityType.postToFlickr,
            UIActivity.ActivityType.postToVimeo,
            UIActivity.ActivityType.postToTencentWeibo
        ]
        present(vc, animated: true, completion: nil)
        vc.popoverPresentationController?.sourceView = self.view
        vc.completionWithItemsHandler = {(activity, success, items, error) in }
    }
    
    
    /*
     * Functions for defining image picker behavior
     */
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
// Local variable inserted by Swift 4.2 migrator.
let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        let input = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage
        
        metalview.changeSize(imageCase: (input?.aspectRadio)!)
        inputImage = CIImage(image: input!)
        guard let cgImage = input?.cgImage else {
            fatalError("Can't open image")
        }
        
        textureLoader = MTKTextureLoader(device: device)
        do {
            sourceTexture = try textureLoader.newTexture(cgImage: cgImage, options: [MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft, MTKTextureLoader.Option.textureStorageMode:  MTLStorageMode.shared.rawValue])
        }
        catch {
            fatalError("Can't load texture")
        }
        metalview.drawableSize = CGSize(width: sourceTexture.width, height: sourceTexture.height)
        
        dismiss(animated:true, completion: nil)
    }
    
    
    @IBAction func FFT(_ sender: UIButton) {
        complexOperation = 1
    }
    
    @IBAction func illMap(_ sender: UIButton) {
        complexOperation = 2
    }
    
    @IBAction func LIMEEngage(_ sender: UIButton) {
        complexOperation = 3
    }
    
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
	return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
	return input.rawValue
}
