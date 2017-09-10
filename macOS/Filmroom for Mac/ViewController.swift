//
//  ViewController.swift
//  Filmroom for Mac
//
//  Created by 周建明 on 2017/8/11.
//  Copyright © 2017年 周建明. All rights reserved.
//

import Cocoa
import CoreFoundation
import CoreImage
import Metal
import MetalKit


class ViewController: NSViewController, MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    // Implement MTKView draw()
    // Reference to WWDC 2015 Session 510
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        
        if let currentDrawable = view.currentDrawable{
            var inputImage: CIImage!
            if let base = baseCIImage{
                inputImage = base
            }else{
                inputImage = CIImage(mtlTexture: sourceTexture)!
            }
            gammaFilter.inputImage = inputImage
            
            if complexOperation{
                
                gaussianFiler.inputImage = inputImage
                gaussianFiler.sigma = 15
                
                /**
                 For fix the unstable condition with processing high pixel pictures
                 */
                let cgimage = context.createCGImage(gaussianFiler.outputImage, from: gaussianFiler.outputImage.extent)
                baseCIImage = CIImage(cgImage: cgimage!)
                
                gammaFilter.inputImage = baseCIImage
                complexOperation = false
            }
            
            gammaFilter.inputUnit = CGFloat(GammaSlider.floatValue)
            
            context.render(gammaFilter.outputImage, to: currentDrawable.texture, commandBuffer: commandBuffer, bounds: inputImage.extent, colorSpace: colorSpace!)
            commandBuffer?.present(currentDrawable)
            commandBuffer?.commit()
        }
        
        
    }
    
    /**
     * Reference to https://denbeke.be/blog/programming/swift-open-file-dialog-with-nsopenpanel/
     */
    @IBAction func OpenFile(sender: AnyObject) {
        
        let dialog = NSOpenPanel();
        
        dialog.title                   = "Choose a photo file";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canChooseDirectories    = false;
        dialog.canCreateDirectories    = true;
        dialog.allowsMultipleSelection = false;
        dialog.allowedFileTypes        = ["jpg", "jpeg", "png", "NEF", "CD2", "tif"];
        
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file
            
            if (result != nil) {
                let path = result!.path
                let textureLoader = MTKTextureLoader(device: device)
                
                do {
                    try sourceTexture = textureLoader.newTexture(URL: URL(fileURLWithPath: path), options: [MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft, MTKTextureLoader.Option.SRGB: true])
                    
                    
                    metalview.setFrameSize(sourceTexture.aspectRadio.FrameSize)
                    metalview.drawableSize = CGSize(width: sourceTexture.width, height: sourceTexture.height)
                    
                    baseCIImage = nil
                } catch  {
                    print("fail to read")
                }
                
                
            }
        } else {
            // User clicked on "Cancel"
            return
        }
        
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    @IBOutlet var GammaSlider: NSSlider!
    @IBOutlet var SigmaSlider: NSSlider!
    @IBOutlet weak var SelectBox: NSComboBoxCell!
    
    
    //var ciimage: CIImage?
    
    let gammaFilter = GammaAdjust()
    let gaussianFiler = GuassianBlur()
    //let queue = DispatchQueue(label: "Filmroom.queue", qos: DispatchQoS.userInteractive, attributes: .concurrent)
    
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var sourceTexture: MTLTexture!
    
    // Used among the whole controller
    var metalview: MTKView!
    
    // Core Image resources
    var context: CIContext!
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
    var textureLoader: MTKTextureLoader!
    var complexOperation = false
    var baseCIImage: CIImage?
    
    override func loadView() {
        super.loadView()
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        
//        let image = NSImage(byReferencingFile: "/Users/jerrychou/_JER6919_s.jpg")
//        ImageView.image = image
//        ImageView.isHidden = false
//        ImageView.isEditable = true
//
//        ciimage = self.ImageView.image?.toCIImage
        
        textureLoader = MTKTextureLoader(device: device)
        
        do {
            try sourceTexture = textureLoader.newTexture(URL: URL(fileURLWithPath: "/Users/jerrychou/_JER7018.jpg"), options: [MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft, MTKTextureLoader.Option.SRGB: true])
            //textureLoader.new

        } catch  {
            print("fail to read")
        }
        
//        sourceTexture.makeTextureView(pixelFormat: .bgra8Unorm)
        
        
        // Set up MTKView
        metalview = MTKView(frame: CGRect(x: 30, y: 50, width: 600, height: 400), device: self.device)
        metalview.setFrameSize(sourceTexture.aspectRadio.FrameSize)
        metalview.delegate = self
        metalview.framebufferOnly = false
        // Save the depth drawable to lower memory increasing
        metalview.sampleCount = 1
        metalview.depthStencilPixelFormat = .invalid
        metalview.preferredFramesPerSecond = 3
        
        // Set the correct draw size
        metalview.drawableSize = CGSize(width: sourceTexture.width, height: sourceTexture.height)
        view.addSubview(metalview)
        
        // Link the cicontext
        context = CIContext(mtlDevice: device)
        
        gammaFilter.setDefaults()
    }
    
    @IBAction func SavePhoto(_ sender: NSButton) {
        
        let resultImage = metalview.currentDrawable?.texture.toNSImage
        resultImage?.writeJPG(toURL: URL(fileURLWithPath: "/Users/jerrychou/output.jpg"))
        //metalview.releaseDrawables()
    }
    
    
    @IBAction func BeginLIME(_ sender: NSButton) {
        /**
         * Reference and modify from here https://gist.github.com/zhangao0086/5fafb1e1c0b5d629eb76
         * Thanks to zhangao0086
         */
//        var rect = NSRect(x: 0, y: 0, width: (ImageView.image?.size.width)!, height: (ImageView.image?.size.height)!)
//        let cgImage = ImageView.image?.cgImage(forProposedRect: &rect, context: nil, hints: nil)
//        let bitmapRep = NSBitmapImageRep(cgImage: cgImage!)
//        var illMap = [UInt8]()
//
//        let pixelsHigh = ImageView.image?.representations[0].pixelsHigh
//        let pixelsWide = ImageView.image?.representations[0].pixelsWide
//
//        if let imageData = bitmapRep.representation(using: NSBitmapImageRep.FileType.bmp, properties: [:]) {
//            let length = imageData.count// - 3342
//
//            var bytes = [UInt8](repeating: 0, count: length)
//            imageData.copyBytes(to: &bytes, count: length)
//
//            var lineCounter = 0
//            var counter = 54
//
//            while counter < length{
//                if lineCounter == pixelsWide{
//                    lineCounter = 0
//                    counter += pixelsWide!
//                    continue
//                }
//                illMap.append(max(bytes[counter], max(bytes[counter + 1], bytes[counter + 2])))
//
//                counter += 3
//                lineCounter += 1
//            }
//
//            for item in illMap.enumerated(){
//                print(item)
//            }
//
//            var T = [UInt8](repeating: 0, count: pixelsHigh! * pixelsWide!)
//            var G = [UInt8](repeating: 0, count: 2 * pixelsHigh! * pixelsWide!)
//            var Z = [UInt8](repeating: 0, count: 2 * pixelsHigh! * pixelsWide!)
//            var t = 0
//
//        }
//
    }
    
    @IBAction func ComplexProcess(_ sender: NSButton) {
        complexOperation = true
    }
    
    @IBAction func PauseRendering(_ sender: NSButton) {
        if metalview.isPaused {
            metalview.isPaused = false
        }else{
            metalview.isPaused = true
        }
    }
}

