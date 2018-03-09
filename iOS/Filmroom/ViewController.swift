//
//  ViewController.swift
//  Filmroom
//
//  Created by 周建明 on 2017/7/8.
//  Copyright © 2017年 Uncle Jerry. All rights reserved.
//

import UIKit
import Metal
import MetalKit


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        picker.delegate = self
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        //CIFilter.registerName("Exposure Filter", constructor: FilterVendor(), classAttributes: [kCIAttributeFilterName: "Exposure Filter"])
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    @IBAction func Adjust(_ sender: UISlider) {
        if MyImageView.image == nil {
            ErrorAlert(message: "Please Load Image first")
            return
        }
        
        let input = processedImage
        
        let exposure = ExposureFilter()
        let expoUnit = ExpSlider.value
        /*
        let shadow = ShadowFilter()
        let shadowUnit = ShadowSlider.value
        
        let highlight = HighlightFilter()
        let hlUnit = HLSlider.value
        */
        
        let hsv = HSLFilter()
        let shift = CIVector(x: CGFloat(HueSlider.value), y: CGFloat(SatSlider.value), z: CGFloat(LumSlider.value))
        
        let contrast = ContrastFilter()
        let contrastUnit = ContrastSlider.value
        
        let saturation = SaturationFilter()
        let satUnit = SaturationSlider.value
 
        exposure.inputImage = input
        exposure.inputUnit = CGFloat(expoUnit)
        /*
        shadow.inputImage = exposure.outputImage
        shadow.inputUnit = CGFloat(shadowUnit)
        
        highlight.inputImage = shadow.outputImage
        highlight.inputUnit = CGFloat(hlUnit)
        */
        contrast.inputImage = exposure.outputImage
        contrast.inputUnit = CGFloat(contrastUnit)
        
        saturation.inputImage = contrast.outputImage
        saturation.inputUnit = CGFloat(satUnit)
 
        hsv.inputImage = saturation.outputImage
        hsv.inputShift0 = shift
        
        
        resultImage = hsv.outputImage
        
        MyImageView.image = UIImage(ciImage: hsv.outputImage)
    }

    @IBOutlet weak var SatSlider: UISlider!
    @IBOutlet weak var HueSlider: UISlider!
    @IBOutlet weak var SaturationSlider: UISlider!
    @IBOutlet weak var LumSlider: UISlider!
    @IBOutlet weak var ExpSlider: UISlider!
    @IBOutlet weak var ContrastSlider: UISlider!
//    @IBOutlet weak var HLSlider: UISlider!
//    @IBOutlet weak var ShadowSlider: UISlider!
    @IBOutlet weak var MyImageView: UIImageView!
    let picker = UIImagePickerController()
    var processedImage: CIImage?
    var resultImage: CIImage?
    let context = CIContext()
    
    @IBAction func LoadImage(_ sender: UIButton) {
        
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary)!
        
        HueSlider.value = 0.0828158104110671
        SatSlider.value = 1
        LumSlider.value = 1
        ExpSlider.value = 0
        ContrastSlider.value = 1
        SatSlider.value = 1
        
        present(picker, animated: true, completion: nil)
    }
    
    @IBAction func SaveImage(_ sender: UIButton) {
        if MyImageView.image == nil {
            ErrorAlert(message: "Please Load Image first")
            return
        }
        let cgimage = context.createCGImage(resultImage!, from: (resultImage?.extent)!)
        let toBeSaved = UIImage(cgImage: cgimage!)
        let vc = UIActivityViewController(activityItems: [toBeSaved], applicationActivities: [])
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
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        MyImageView.image = info[UIImagePickerControllerOriginalImage] as? UIImage
        processedImage = CIImage(image: MyImageView.image!)
        
        dismiss(animated:true, completion: nil)
    }
    
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var sourceTexture: MTLTexture!
    
    
    var textureLoader: MTKTextureLoader!
    
    @IBAction func FFT(_ sender: UIButton) {
        var commandBuffer = commandQueue.makeCommandBuffer()
        
        guard let cgImage = MyImageView.image?.cgImage else {
            fatalError("Can't open image")
        }
        
        textureLoader = MTKTextureLoader(device: self.device)
        do {
            sourceTexture = try textureLoader.newTexture(cgImage: cgImage, options: nil)
        }
        catch {
            fatalError("Can't load texture")
        }
        
        
        /// A Metal library
        var defaultLibrary: MTLLibrary!
        
        // Load library file
        do{
            try defaultLibrary = device.makeDefaultLibrary()
        }catch{
            fatalError("Load library error")
        }
        
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
        let totalPixel = Float(width * length)
        
        // Set texture in kernel
        for index in 1...Int(log2(totalPixel)){
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
        
        MyImageView.image = resultTexture.toUIImage
        processedImage = CIImage(image: MyImageView.image!)
        
    }
}

