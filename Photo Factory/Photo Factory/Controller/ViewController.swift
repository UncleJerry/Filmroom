//
//  ViewController.swift
//  Photo Factory
//
//  Created by 周建明 on 2017/11/28.
//  Copyright © 2017年 周建明. All rights reserved.
//

import Cocoa
import CoreGraphics
import Metal
import MetalKit
import AppKit

class ViewController: NSViewController, MTKViewDelegate, NSWindowDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    func draw(in view: MTKView) {
        var commandBuffer = commandQueue.makeCommandBuffer()
        
        if let currentDrawable = view.currentDrawable{
            // the local pointer to baseCIImage
            var inputImage: CIImage!
            
            // baseCIImage may be nil
            if let base = baseCIImage{
                inputImage = base
            }else{
                // if nil, load from sourceTexture
                inputImage = CIImage(mtlTexture: sourceTexture)!
            }
            
            // Execute complex filter or not
            if complexOperation != .None{
                metalview.isPaused = true
                let width = inputImage?.extent.width
                let height = inputImage?.extent.height
                
                // Preparation
                var filter = CIFilter()
                if complexOperation.isBlur() {
                    whiteFilter.inputImage = inputImage
                    
                    let combine = CIFilter(name: "CISourceOverCompositing")
                    
                    // Merge
                    let trans = inputImage?.transformed(by: CGAffineTransform(translationX: 100, y: 100))
                    combine?.setValue(trans, forKey: "inputImage")
                    combine?.setValue(whiteFilter.outputImage, forKey: "inputBackgroundImage")
                    
                    var blurFilter = CIFilter()
                    if complexOperation == .Guassian {
                        blurFilter = CIFilter(name: "CIGaussianBlur")!
                        blurFilter.setValue(combine?.outputImage, forKey: "inputImage")
                        blurFilter.setValue(12, forKey: "inputRadius")
                    }else if complexOperation == .Box{
                        blurFilter = CIFilter(name: "CIBoxBlur")!
                        blurFilter.setValue(combine?.outputImage, forKey: "inputImage")
                        blurFilter.setValue(12, forKey: "inputRadius")
                        
                    }else if complexOperation == .Motion {
                        blurFilter = CIFilter(name: "CIMotionBlur")!
                        blurFilter.setValue(combine?.outputImage, forKey: "inputImage")
                        blurFilter.setValue(12, forKey: "inputRadius")
                        blurFilter.setValue(0.0, forKey: "inputAngle")
                    }
                    
                    filter = CIFilter(name: "CICrop")!
                    filter.setValue(blurFilter.outputImage, forKey: "inputImage")
                    let size = CIVector(x: 100, y: 100, z: width!, w: height!)
                    filter.setValue(size, forKey: "inputRectangle")
                    metalview.drawableSize = CGSize(width: (filter.outputImage?.extent.width)!, height: (filter.outputImage?.extent.height)!)
                    
                }else if complexOperation == .Sharpen {
                    filter = CIFilter(name: "CISharpenLuminance")!
                    filter.setValue(inputImage, forKey: "inputImage")
                    filter.setValue(0.5, forKey: "inputSharpness")
                }else if complexOperation == .Denoise {
                    filter = CIFilter(name: "CINoiseReduction")!
                    filter.setValue(inputImage, forKey: "inputImage")
                    filter.setValue(0.5, forKey: "inputNoiseLevel")
                    filter.setValue(0.4, forKey: "inputSharpness")
                }else if complexOperation == .Distortion {
                    filter = CIFilter(name: "CIPinchDistortion")!
                    filter.setValue(inputImage, forKey: "inputImage")
                    filter.setValue(100, forKey: "inputRadius")
                    filter.setValue(0.5, forKey: "inputScale")
                    let center = CIVector(x: CGFloat(width! / 2), y: CGFloat(height! / 2))
                    filter.setValue(center, forKey: "inputCenter")
                    
                    metalview.drawableSize = CGSize(width: (filter.outputImage?.extent.width)!, height: (filter.outputImage?.extent.height)!)
                }else if complexOperation == .Pixelization {
                    filter = CIFilter(name: "CIPixellate")!
                    filter.setValue(inputImage, forKey: "inputImage")
                    let center = CIVector(x: CGFloat(inputImage.extent.width / 2), y: CGFloat(inputImage.extent.height / 2))
                    filter.setValue(center, forKey: "inputCenter")
                }
                
                
                inputImage = filter.outputImage
                baseCIImage = filter.outputImage
               //metalview.setFrameSize(NSSize(width: (baseCIImage?.extent.width)!, height: (baseCIImage?.extent.height)!))
                complexOperation = .None
                metalview.isPaused = false
            }
            // For the contrast factor scale from 0.25 to 4, 1 is the default
            let contrast = ContrastSlider.floatValue < 0 ? 1 + ContrastSlider.floatValue / 133.4 : 1 + ContrastSlider.floatValue / 34
            
            // From -2 to 2
            let highlight = HighlightSlider.floatValue / 50.0
            // From 0 to 2
            let saturation = (SatSlider.floatValue + 100) / 100.0
            // set input first
            
            exposureFilter?.setValue(inputImage, forKey: "inputImage")
            // From -2 to 2
            exposureFilter?.setValue(ExpoSlider.floatValue / 50.0, forKey: "inputEV")
            highshadowFilter?.setValue(exposureFilter?.outputImage, forKey: "inputImage")
            // Set for shadow, from -1 to 1
            highshadowFilter?.setValue(ShadowSlider.floatValue / 100.0, forKey: "inputShadowAmount")
            
            // Custom Highlight Filter
            let highlightFilter = HighlightFilter()
            highlightFilter.inputImage = highshadowFilter?.outputImage
            highlightFilter.inputUnit = CGFloat(highlight)
            
            // Set contrast
            conFilter?.setValue(highlightFilter.outputImage, forKey: "inputImage")
            conFilter?.setValue(contrast, forKey: "inputContrast")
            conFilter?.setValue(saturation, forKey: "inputSaturation")
            
            // Set saturation
            satFilter.inputImage = conFilter?.outputImage
            satFilter.inputUnit = CGFloat(saturation)
            hslFilter.inputImage = satFilter.outputImage
            
            // Set HSL Adjustment filter, and shift for each color
            // Each shift vector consist of three element, represent hue, saturation and luminance shift, from 0 to 2
            let redshift = CIVector(x: CGFloat((RedHueS.floatValue + 100) / 100), y: CGFloat((RedSatS.floatValue + 100) / 100), z: CGFloat((RedLumS.floatValue + 100) / 100))
            let orashift = CIVector(x: CGFloat((OraHueS.floatValue + 100) / 100), y: CGFloat((OraSatS.floatValue + 100) / 100), z: CGFloat((OraLumS.floatValue + 100) / 100))
            let yellshift = CIVector(x: CGFloat((YellHueS.floatValue + 100) / 100), y: CGFloat((YellSatS.floatValue + 100) / 100), z: CGFloat((YellLumS.floatValue + 100) / 100))
            let greshift = CIVector(x: CGFloat((GreHueS.floatValue + 100) / 100), y: CGFloat((GreSatS.floatValue + 100) / 100), z: CGFloat((GreLumS.floatValue + 100) / 100))
            let aqushift = CIVector(x: CGFloat((AquHueS.floatValue + 100) / 100), y: CGFloat((AquSatS.floatValue + 100) / 100), z: CGFloat((AquLumS.floatValue + 100) / 100))
            let blueshift = CIVector(x: CGFloat((BlueHueS.floatValue + 100) / 100), y: CGFloat((BlueSatS.floatValue + 100) / 100), z: CGFloat((BlueLumS.floatValue + 100) / 100))
            let purshift = CIVector(x: CGFloat((PurHueS.floatValue + 100) / 100), y: CGFloat((PurSatS.floatValue + 100) / 100), z: CGFloat((PurLumS.floatValue + 100) / 100))
            let magshift = CIVector(x: CGFloat((MagHueS.floatValue + 100) / 100), y: CGFloat((MagSatS.floatValue + 100) / 100), z: CGFloat((MagLumS.floatValue + 100) / 100))
            
            hslFilter.inputRedShift = redshift
            hslFilter.inputOrangeShift = orashift
            hslFilter.inputYellowShift = yellshift
            hslFilter.inputGreenShift = greshift
            hslFilter.inputAquaShift = aqushift
            hslFilter.inputBlueShift = blueshift
            hslFilter.inputPurpleShift = purshift
            hslFilter.inputMagentaShift = magshift
            
            
            context.render((hslFilter.outputImage)!, to: currentDrawable.texture, commandBuffer: commandBuffer, bounds: inputImage.extent, colorSpace: colorSpace!)
            commandBuffer?.present(currentDrawable)
            commandBuffer?.commit()
        }
    }
    
    
    
    func alertUser() {
        let alert = NSAlert()
        alert.messageText = "message 1"
        alert.informativeText = "info1"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func stylization() {
//        let color = CGColor(red: 0.33203125, green: 0.33203125, blue: 0.33203125, alpha: 1.0) // 0x55
//        self.view.layer?.backgroundColor = color
        
        NotificationCenter.default.addObserver(self, selector: #selector(NSWindowDelegate.windowDidResize(_:)), name: NSWindow.didResizeNotification, object: nil)
//        self.view.window?.contentMinSize = NSSize(width: 1100, height: 700)
        //self.view.wantsLayer = true
    }
    
    
    // Manage the window and view when resizing
    func windowDidResize(_ notification: Notification) {
        let height = self.view.window?.frame.height
        let mtlheight = Int(self.metalview.frame.height)
        let mtlwidth = Int(self.metalview.frame.width)
        var updateHeight: Int = 0
        if height != nil && Int(height!) > 720{
            updateHeight = (Int(height!) - mtlheight) / 2;
        }

        metalview.frame = NSRect(x: 60, y: Int(updateHeight), width: mtlwidth, height: mtlheight)
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
        dialog.allowedFileTypes        = ["jpg", "jpeg", "png", "tif"];
        
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file
            
            if (result != nil) {
                let path = result!.path
                let textureLoader = MTKTextureLoader(device: device)
                
                do {
                    try sourceTexture = textureLoader.newTexture(URL: URL(fileURLWithPath: path), options: [MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft])
                    
                    
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
    
    
    @IBAction func OpenRAW(sender: AnyObject) {
        
        let dialog = NSOpenPanel();
        
        dialog.title                   = "Choose a RAW file";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canChooseDirectories    = false;
        dialog.canCreateDirectories    = true;
        dialog.allowsMultipleSelection = false;
        dialog.allowedFileTypes        = ["NEF", "CD2", "ARW"];
        
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file
            
            if (result != nil) {
                let path = result!.path
                
                let rawImage = CIImage(contentsOf: URL(fileURLWithPath: path))
                
                baseCIImage = rawImage
                metalview.setFrameSize((rawImage?.aspectRadio.FrameSize)!)
                metalview.drawableSize = CGSize(width: (rawImage?.extent.width)!, height: (rawImage?.extent.height)!)
            }
        } else {
            // User clicked on "Cancel"
            return
        }
        
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()

        //print(satConFilter?.attributes)
        //alertUser()
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    override func loadView() {
        super.loadView()
        
        stylization()
        
        // Declare the Metal Object, and set to use system default GPU
        // If device have 1 GPU, then that is the default
        // If own 2, the default is the more powerful one.
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        
        textureLoader = MTKTextureLoader(device: device)
        // Link the cicontext
        context = CIContext(mtlDevice: device)
        
        
        // Load the start image
        do {
            try sourceTexture = textureLoader.newTexture(name: "Start", scaleFactor: 2.0, bundle: Bundle.main, options: [MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft])
            
        } catch  {
            print("fail to read")
        }
        
        
        // Set up metalview
        metalview = MTKView(frame: CGRect(x: 60, y: 60, width: 600, height: 400), device: self.device)
        // Re-calibrate the MTKView Size
        metalview.setFrameSize(sourceTexture.aspectRadio.FrameSize)
        metalview.delegate = self
        metalview.framebufferOnly = false
        // Save the depth drawable to lower memory increasing
        metalview.sampleCount = 1
        metalview.depthStencilPixelFormat = .invalid
        // FPS rate Control
        metalview.preferredFramesPerSecond = 24
        metalview.clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        // Tell the view about texture(image) size
        metalview.drawableSize = CGSize(width: sourceTexture.width, height: sourceTexture.height)
        //Put it into the window
        view.addSubview(metalview)
    }
    
    @IBOutlet weak var ExpoSlider: NSSlider!
    @IBOutlet weak var ContrastSlider: NSSlider!
    @IBOutlet weak var HighlightSlider: NSSlider!
    @IBOutlet weak var ShadowSlider: NSSlider!
    @IBOutlet weak var SatSlider: NSSlider!
  
    @IBOutlet weak var RedHueS: NSSlider!
    @IBOutlet weak var RedSatS: NSSlider!
    @IBOutlet weak var RedLumS: NSSlider!
    @IBOutlet weak var OraHueS: NSSlider!
    @IBOutlet weak var OraSatS: NSSlider!
    @IBOutlet weak var OraLumS: NSSlider!
    @IBOutlet weak var YellHueS: NSSlider!
    @IBOutlet weak var YellSatS: NSSlider!
    @IBOutlet weak var YellLumS: NSSlider!
    @IBOutlet weak var GreHueS: NSSlider!
    @IBOutlet weak var GreSatS: NSSlider!
    @IBOutlet weak var GreLumS: NSSlider!
    @IBOutlet weak var AquHueS: NSSlider!
    @IBOutlet weak var AquSatS: NSSlider!
    @IBOutlet weak var AquLumS: NSSlider!
    @IBOutlet weak var BlueHueS: NSSlider!
    @IBOutlet weak var BlueSatS: NSSlider!
    @IBOutlet weak var BlueLumS: NSSlider!
    @IBOutlet weak var PurHueS: NSSlider!
    @IBOutlet weak var PurSatS: NSSlider!
    @IBOutlet weak var PurLumS: NSSlider!
    @IBOutlet weak var MagHueS: NSSlider!
    @IBOutlet weak var MagSatS: NSSlider!
    @IBOutlet weak var MagLumS: NSSlider!
    
    
    @IBOutlet weak var HSLTab: NSTabView!
    
    @IBOutlet weak var ExpoNum: NSTextFieldCell!
    @IBOutlet weak var ContrastNum: NSTextFieldCell!
    @IBOutlet weak var HighNum: NSTextFieldCell!
    @IBOutlet weak var ShadowNum: NSTextFieldCell!
    @IBOutlet weak var SatNum: NSTextFieldCell!
    
    @IBOutlet weak var RedHue: NSTextFieldCell!
    @IBOutlet weak var RedSat: NSTextFieldCell!
    @IBOutlet weak var RedLum: NSTextFieldCell!
    @IBOutlet weak var OraHue: NSTextFieldCell!
    @IBOutlet weak var OraSat: NSTextFieldCell!
    @IBOutlet weak var OraLum: NSTextFieldCell!
    @IBOutlet weak var YellHue: NSTextFieldCell!
    @IBOutlet weak var YellSat: NSTextFieldCell!
    @IBOutlet weak var YellLum: NSTextFieldCell!
    @IBOutlet weak var GreHue: NSTextFieldCell!
    @IBOutlet weak var GreSat: NSTextFieldCell!
    @IBOutlet weak var GreLum: NSTextFieldCell!
    @IBOutlet weak var AquHue: NSTextFieldCell!
    @IBOutlet weak var AquSat: NSTextFieldCell!
    @IBOutlet weak var AquLum: NSTextFieldCell!
    @IBOutlet weak var BlueHue: NSTextFieldCell!
    @IBOutlet weak var BlueSat: NSTextFieldCell!
    @IBOutlet weak var BlueLum: NSTextFieldCell!
    @IBOutlet weak var PurHue: NSTextFieldCell!
    @IBOutlet weak var PurSat: NSTextFieldCell!
    @IBOutlet weak var PurLum: NSTextFieldCell!
    @IBOutlet weak var MagHue: NSTextFieldCell!
    @IBOutlet weak var MagSat: NSTextFieldCell!
    @IBOutlet weak var MagLum: NSTextFieldCell!
    
    
    @IBAction func AdjustHSL(_ sender: NSSlider) {
        let identity = sender.identifier!.rawValue
        let value = String(Int(sender.floatValue))
        switch identity {
        case "redhue":
            RedHue.title = value
        case "redsat":
            RedSat.title = value
        case "redlum":
            RedLum.title = value
        case "orahue":
            OraHue.title = value
        case "orasat":
            OraSat.title = value
        case "oralum":
            OraLum.title = value
        case "yellhue":
            YellHue.title = value
        case "yellsat":
            YellSat.title = value
        case "yelllum":
            YellLum.title = value
        case "grehue":
            GreHue.title = value
        case "gresat":
            GreSat.title = value
        case "grelum":
            GreLum.title = value
        case "aquhue":
            AquHue.title = value
        case "aqusat":
            AquSat.title = value
        case "aqulum":
            AquLum.title = value
        case "bluehue":
            BlueHue.title = value
        case "bluesat":
            BlueSat.title = value
        case "bluelum":
            BlueLum.title = value
        case "purhue":
            PurHue.title = value
        case "pursat":
            PurSat.title = value
        case "purlum":
            PurLum.title = value
        case "maghue":
            MagHue.title = value
        case "magsat":
            MagSat.title = value
        case "maglum":
            MagLum.title = value
        case "expo":
            ExpoNum.title = value
        case "contrast":
            ContrastNum.title = value
        case "highlight":
            HighNum.title = value
        case "shadow":
            ShadowNum.title = value
        case "sat":
            SatNum.title = value
            
        default:
            return
        }
    }
    
    @IBAction func SaveImage(_ sender: NSButton) {
        
        let resultImage = metalview.currentDrawable?.texture.toNSImage
        let dialog = NSSavePanel()
        
        dialog.title                   = "Save image to"
        dialog.showsResizeIndicator    = true
        dialog.showsHiddenFiles        = false
        dialog.canCreateDirectories    = true
        dialog.allowedFileTypes        = ["jpg"]

        
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file
            
            if (result != nil) {
                let path = result!.path

                resultImage?.writeJPG(toURL: URL(fileURLWithPath: path))
            }
        } else {
            // User clicked on "Cancel"
            return
        }
    }
    
    @IBAction func ResetLight(_ sender: NSButton) {
        ExpoSlider.floatValue = 0.0
        ContrastSlider.floatValue = 0.0
        HighlightSlider.floatValue = 0.0
        ShadowSlider.floatValue = 0.0
        SatSlider.floatValue = 0.0
        
        RedHueS.floatValue = 0.0
        RedSatS.floatValue = 0.0
        RedLumS.floatValue = 0.0
        OraHueS.floatValue = 0.0
        OraSatS.floatValue = 0.0
        OraLumS.floatValue = 0.0
        YellHueS.floatValue = 0.0
        YellSatS.floatValue = 0.0
        YellLumS.floatValue = 0.0
        GreHueS.floatValue = 0.0
        GreSatS.floatValue = 0.0
        GreLumS.floatValue = 0.0
        AquHueS.floatValue = 0.0
        AquSatS.floatValue = 0.0
        AquLumS.floatValue = 0.0
        BlueHueS.floatValue = 0.0
        BlueSatS.floatValue = 0.0
        BlueLumS.floatValue = 0.0
        PurHueS.floatValue = 0.0
        PurSatS.floatValue = 0.0
        PurLumS.floatValue = 0.0
        MagHueS.floatValue = 0.0
        MagSatS.floatValue = 0.0
        MagLumS.floatValue = 0.0
        
        ExpoNum.title = "0"
        ContrastNum.title = "0"
        HighNum.title = "0"
        ShadowNum.title = "0"
        SatNum.title = "0"
        
        RedHue.title = "0"
        RedSat.title = "0"
        RedLum.title = "0"
        OraHue.title = "0"
        OraSat.title = "0"
        OraLum.title = "0"
        YellHue.title = "0"
        YellSat.title = "0"
        YellLum.title = "0"
        GreHue.title = "0"
        GreSat.title = "0"
        GreLum.title = "0"
        AquHue.title = "0"
        AquSat.title = "0"
        AquLum.title = "0"
        BlueHue.title = "0"
        BlueSat.title = "0"
        BlueLum.title = "0"
        PurHue.title = "0"
        PurSat.title = "0"
        PurLum.title = "0"
        MagHue.title = "0"
        MagSat.title = "0"
        MagLum.title = "0"
    }
    
    
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var sourceTexture: MTLTexture!
    
    // Used among the whole controller
    var metalview: MTKView!
    
    
    // Core Image resources
    var context: CIContext!
    let colorSpace = CGColorSpace(name: CGColorSpace.displayP3)
    var textureLoader: MTKTextureLoader!
    var baseCIImage: CIImage?

    
    // Pre-load the filters
    let exposureFilter = CIFilter(name: "CIExposureAdjust")
    let highshadowFilter = CIFilter(name: "CIHighlightShadowAdjust")
    let conFilter = CIFilter(name: "CIColorControls")
    let satFilter = SaturationFilter()
    let hslFilter = MultiBandHSL()
    let whiteFilter = WhiteFilter()
}
