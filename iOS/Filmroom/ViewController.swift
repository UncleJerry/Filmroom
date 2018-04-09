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

                /// A Metal library
                var defaultLibrary: MTLLibrary!
                
                // Load library file
                defaultLibrary = device.makeDefaultLibrary()
                
                if complexOperation == 1{
                    let timer = Timer()
                    // Select library function
                    let reOrderKernel = defaultLibrary.makeFunction(name: "reposition")!
                    
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
                    reorderedTexture = self.device.makeTexture(descriptor: textureDescriptor)
                    
                    
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
                    let threadGroups: MTLSize = MTLSizeMake(Int(self.sourceTexture.width) / threadPerGroup.width, Int(self.sourceTexture.height) / threadPerGroup.height, 1)
                    
                    
                    // Set texture in kernel
                    commandEncoder?.setComputePipelineState(pipelineState)
                    commandEncoder?.setTexture(self.sourceTexture, index: 0)
                    commandEncoder?.setTexture(reorderedTexture, index: 1)
                    
                    // Pass width and length data to GPU
                    var width = self.sourceTexture.width
                    var length = width * self.sourceTexture.height
                    
                    // Set data buffer
                    let bufferW = device.makeBuffer(bytes: &width, length: MemoryLayout<uint>.size, options: MTLResourceOptions.storageModeShared)
                    let bufferL = device.makeBuffer(bytes: &length, length: MemoryLayout<uint>.size, options: MTLResourceOptions.storageModeShared)
                    
                    commandEncoder?.setBuffer(bufferW, offset: 0, index: 0)
                    commandEncoder?.setBuffer(bufferL, offset: 0, index: 1)
                    
                    // Config the thread setting
                    commandEncoder?.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadPerGroup)
                    commandEncoder?.endEncoding()
                    
                    // Push the configuration and assignments to GPU
                    commandBuffer?.commit()
                    commandBuffer?.waitUntilCompleted()
                    // Above, finished the re-arrangment
                    
                    // Load function of FFT calculation
                    let fftStageKernel = defaultLibrary.makeFunction(name: "fft_allStage")
                    // Set pipeline of Computation
                    do{
                        pipelineState = try device.makeComputePipelineState(function: fftStageKernel!)
                    }catch{
                        fatalError("Set up failed")
                    }
                    
                    // Calculate the total pixel amount
                    let totalPixel = Int(log2(Float(length)))
                    
                    // Set texture in kernel
                    for index in 1...totalPixel{
                        // Start steps of FFT -- Calculate each row
                        // Refresh the command buffer and encoder for each stage
                        commandBuffer = commandQueue.makeCommandBuffer()
                        commandEncoder = commandBuffer?.makeComputeCommandEncoder()
                        
                        
                        commandEncoder?.setComputePipelineState(pipelineState)
                        commandEncoder?.setTexture(reorderedTexture, index: 0)
                        var stage = UInt(index)
                        
                        // Adjust the FFT and complexConjugate to get inverse or complex conjugate
                        var FFT: Int = 1
                        var complexConjugate: Int = 1
                        
                        let bufferS = device.makeBuffer(bytes: &stage, length: MemoryLayout<uint>.size, options: MTLResourceOptions.storageModeShared)
                        let bufferFFT = device.makeBuffer(bytes: &FFT, length: MemoryLayout<Int>.size, options: MTLResourceOptions.storageModeShared)
                        let bufferComplexConjugate = device.makeBuffer(bytes: &complexConjugate, length: MemoryLayout<Int>.size, options: MTLResourceOptions.storageModeShared)
                        
                        commandEncoder?.setBuffer(bufferW, offset: 0, index: 0)
                        commandEncoder?.setBuffer(bufferL, offset: 0, index: 1)
                        commandEncoder?.setBuffer(bufferS, offset: 0, index: 2)
                        commandEncoder?.setBuffer(bufferFFT, offset: 0, index: 3)
                        commandEncoder?.setBuffer(bufferComplexConjugate, offset: 0, index: 4)
                        
                        commandEncoder?.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadPerGroup)
                        commandEncoder?.endEncoding()
                        
                        // Push the assignment
                        commandBuffer?.commit()
                        
                    }
                    
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
                    resultTexture = self.device.makeTexture(descriptor: resultDescriptor)
                    
                    commandBuffer = commandQueue.makeCommandBuffer()
                    commandEncoder = commandBuffer?.makeComputeCommandEncoder()
                    
                    commandEncoder?.setComputePipelineState(pipelineState)
                    commandEncoder?.setTexture(reorderedTexture, index: 0)
                    commandEncoder?.setTexture(resultTexture, index: 1)
                    
                    commandEncoder?.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadPerGroup)
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
                    resultTexture = self.device.makeTexture(descriptor: resultDescriptor)
                    
                    let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
                    let tw = pipelineState.threadExecutionWidth
                    let th = pipelineState.maxTotalThreadsPerThreadgroup / tw
                    
                    let threadPerGroup = MTLSizeMake(tw, th, 1)
                    let threadGroups: MTLSize = MTLSizeMake(Int(self.sourceTexture.width) / threadPerGroup.width, Int(self.sourceTexture.height) / threadPerGroup.height, 1)
                    
                    
                    
                    commandEncoder?.setComputePipelineState(pipelineState)
                    commandEncoder?.setTexture(self.sourceTexture, index: 0)
                    commandEncoder?.setTexture(resultTexture, index: 1)
                    
                    var referRadius: UInt = 10
                    commandEncoder?.setBytes(&referRadius, length: MemoryLayout<uint>.stride, index: 0)
                    
                    commandEncoder?.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadPerGroup)
                    commandEncoder?.endEncoding()
                    
                    // Push the assignment
                    commandBuffer?.commit()
                    commandBuffer?.waitUntilCompleted()
                    
                    sourceTexture = resultTexture
                    inputImage = CIImage(mtlTexture: resultTexture, options: nil)
                }
                
                complexOperation = 0
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
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        
        textureLoader = MTKTextureLoader(device: device)
        
        // Load the start image
        do {
            try sourceTexture = textureLoader.newTexture(name: "Welcome", scaleFactor: 2.0, bundle: Bundle.main, options: [MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft])
            
        } catch  {
            print("fail to read")
        }
        
        inputImage = CIImage(mtlTexture: sourceTexture)!
        // Set up MTKView
        metalview = MTKView(frame: CGRect(x: 30, y: 50, width: 200, height: 200), device: self.device)
        
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
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var sourceTexture: MTLTexture!
    var textureLoader: MTKTextureLoader!
    var complexOperation: Int!
    var metalview: MTKView!
    
    
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
            UIActivityType.postToFacebook,
            //UIActivityType.postToWeibo,
            UIActivityType.message,
            //UIActivityTypeMail,
            UIActivityType.print,
            UIActivityType.copyToPasteboard,
            UIActivityType.assignToContact,
            //UIActivityType.saveToCameraRoll,
            UIActivityType.addToReadingList,
            UIActivityType.postToFlickr,
            UIActivityType.postToVimeo,
            UIActivityType.postToTencentWeibo
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
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let input = info[UIImagePickerControllerOriginalImage] as? UIImage
        metalview.changeSize(imageCase: (input?.aspectRadio)!)
        inputImage = CIImage(image: input!)
        guard let cgImage = input?.cgImage else {
            fatalError("Can't open image")
        }
        
        textureLoader = MTKTextureLoader(device: self.device)
        do {
            sourceTexture = try textureLoader.newTexture(cgImage: cgImage, options: [MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft])
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
    
    
}

