//
//  CustomFilter.swift
//  Photo Factory
//
//  Created by 周建明 on 11/12/2017.
//  Copyright © 2017年 周建明. All rights reserved.
//

import Foundation
import CoreImage
import Cocoa

/*
 * Reference to http://flexmonkey.blogspot.com/2016/03/creating-selective-hsl-adjustment.html
 */
class MultiBandHSL: CIFilter{
    let multiBandHSVKernel: CIKernel = {
        let red = CGFloat(0) // UIColor(red: 0.901961, green: 0.270588, blue: 0.270588, alpha: 1).hue()
        let orange = NSColor(red: 0.901961, green: 0.584314, blue: 0.270588, alpha: 1).hue()
        let yellow = NSColor(red: 0.901961, green: 0.901961, blue: 0.270588, alpha: 1).hue()
        let green = NSColor(red: 0.270588, green: 0.901961, blue: 0.270588, alpha: 1).hue()
        let aqua = NSColor(red: 0.270588, green: 0.901961, blue: 0.901961, alpha: 1).hue()
        let blue = NSColor(red: 0.270588, green: 0.270588, blue: 0.901961, alpha: 1).hue()
        let purple = NSColor(red: 0.584314, green: 0.270588, blue: 0.901961, alpha: 1).hue()
        let magenta = NSColor(red: 0.901961, green: 0.270588, blue: 0.901961, alpha: 1).hue()
        
        var shaderString = ""
        
        shaderString += "#define red \(red) \n"
        shaderString += "#define orange \(orange) \n"
        shaderString += "#define yellow \(yellow) \n"
        shaderString += "#define green \(green) \n"
        shaderString += "#define aqua \(aqua) \n"
        shaderString += "#define blue \(blue) \n"
        shaderString += "#define purple \(purple) \n"
        shaderString += "#define magenta \(magenta) \n"
        
        shaderString += "vec3 rgb2hsv(vec3 c)"
        shaderString += "{"
        shaderString += "    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);"
        shaderString += "    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));"
        shaderString += "    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));"
        
        shaderString += "    float d = q.x - min(q.w, q.y);"
        shaderString += "    float e = 1.0e-10;"
        shaderString += "    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);"
        shaderString += "}"
        
        shaderString += "vec3 hsv2rgb(vec3 c)"
        shaderString += "{"
        shaderString += "    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);"
        shaderString += "    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);"
        shaderString += "    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);"
        shaderString += "}"
        
        shaderString += "vec3 smoothTreatment(vec3 hsv, float hueEdge0, float hueEdge1, vec3 shiftEdge0, vec3 shiftEdge1)"
        shaderString += "{"
        shaderString += " float smoothedHue = smoothstep(hueEdge0, hueEdge1, hsv.x);"
        shaderString += " float hue = hsv.x + (shiftEdge0.x + ((shiftEdge1.x - shiftEdge0.x) * smoothedHue));"
        shaderString += " float sat = hsv.y * (shiftEdge0.y + ((shiftEdge1.y - shiftEdge0.y) * smoothedHue));"
        shaderString += " float lum = hsv.z * (shiftEdge0.z + ((shiftEdge1.z - shiftEdge0.z) * smoothedHue));"
        shaderString += " return vec3(hue, sat, lum);"
        shaderString += "}"
        
        shaderString += "kernel vec4 kernelFunc(__sample pixel,"
        shaderString += "  vec3 redShift, vec3 orangeShift, vec3 yellowShift, vec3 greenShift,"
        shaderString += "  vec3 aquaShift, vec3 blueShift, vec3 purpleShift, vec3 magentaShift)"
        
        shaderString += "{"
        shaderString += " vec3 hsv = rgb2hsv(pixel.rgb); \n"
        
        shaderString += " if (hsv.x < orange){                          hsv = smoothTreatment(hsv, 0.0, orange, redShift, orangeShift);} \n"
        shaderString += " else if (hsv.x >= orange && hsv.x < yellow){  hsv = smoothTreatment(hsv, orange, yellow, orangeShift, yellowShift); } \n"
        shaderString += " else if (hsv.x >= yellow && hsv.x < green){   hsv = smoothTreatment(hsv, yellow, green, yellowShift, greenShift);  } \n"
        shaderString += " else if (hsv.x >= green && hsv.x < aqua){     hsv = smoothTreatment(hsv, green, aqua, greenShift, aquaShift);} \n"
        shaderString += " else if (hsv.x >= aqua && hsv.x < blue){      hsv = smoothTreatment(hsv, aqua, blue, aquaShift, blueShift);} \n"
        shaderString += " else if (hsv.x >= blue && hsv.x < purple){    hsv = smoothTreatment(hsv, blue, purple, blueShift, purpleShift);} \n"
        shaderString += " else if (hsv.x >= purple && hsv.x < magenta){ hsv = smoothTreatment(hsv, purple, magenta, purpleShift, magentaShift);} \n"
        shaderString += " else {                                        hsv = smoothTreatment(hsv, magenta, 1.0, magentaShift, redShift); }; \n"
        
        shaderString += "return vec4(hsv2rgb(hsv), 1.0);"
        shaderString += "}"
        
        return CIKernel(source: shaderString)!
    }()
    
    var inputImage: CIImage?
    
    var inputRedShift = CIVector(x: 0, y: 1, z: 1)
    var inputOrangeShift = CIVector(x: 0, y: 1, z: 1)
    var inputYellowShift = CIVector(x: 0, y: 1, z: 1)
    var inputGreenShift = CIVector(x: 0, y: 1, z: 1)
    var inputAquaShift = CIVector(x: 0, y: 1, z: 1)
    var inputBlueShift = CIVector(x: 0, y: 1, z: 1)
    var inputPurpleShift = CIVector(x: 0, y: 1, z: 1)
    var inputMagentaShift = CIVector(x: 0, y: 1, z: 1)
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "MultiBandHSV",
            
            "inputImage": [kCIAttributeIdentity: 0,
                           kCIAttributeClass: "CIImage",
                           kCIAttributeDisplayName: "Image",
                           kCIAttributeType: kCIAttributeTypeImage],
            
            "inputRedShift": [kCIAttributeIdentity: 0,
                              kCIAttributeClass: "CIVector",
                              kCIAttributeDisplayName: "Red Shift (HSL)",
                              kCIAttributeDescription: "Set the hue, saturation and lightness for this color band.",
                              kCIAttributeDefault: CIVector(x: 0, y: 1, z: 1),
                              kCIAttributeType: kCIAttributeTypePosition3],
            
            "inputOrangeShift": [kCIAttributeIdentity: 0,
                                 kCIAttributeClass: "CIVector",
                                 kCIAttributeDisplayName: "Orange Shift (HSL)",
                                 kCIAttributeDescription: "Set the hue, saturation and lightness for this color band.",
                                 kCIAttributeDefault: CIVector(x: 0, y: 1, z: 1),
                                 kCIAttributeType: kCIAttributeTypePosition3],
            
            "inputYellowShift": [kCIAttributeIdentity: 0,
                                 kCIAttributeClass: "CIVector",
                                 kCIAttributeDisplayName: "Yellow Shift (HSL)",
                                 kCIAttributeDescription: "Set the hue, saturation and lightness for this color band.",
                                 kCIAttributeDefault: CIVector(x: 0, y: 1, z: 1),
                                 kCIAttributeType: kCIAttributeTypePosition3],
            
            "inputGreenShift": [kCIAttributeIdentity: 0,
                                kCIAttributeClass: "CIVector",
                                kCIAttributeDisplayName: "Green Shift (HSL)",
                                kCIAttributeDescription: "Set the hue, saturation and lightness for this color band.",
                                kCIAttributeDefault: CIVector(x: 0, y: 1, z: 1),
                                kCIAttributeType: kCIAttributeTypePosition3],
            
            "inputAquaShift": [kCIAttributeIdentity: 0,
                               kCIAttributeClass: "CIVector",
                               kCIAttributeDisplayName: "Aqua Shift (HSL)",
                               kCIAttributeDescription: "Set the hue, saturation and lightness for this color band.",
                               kCIAttributeDefault: CIVector(x: 0, y: 1, z: 1),
                               kCIAttributeType: kCIAttributeTypePosition3],
            
            "inputBlueShift": [kCIAttributeIdentity: 0,
                               kCIAttributeClass: "CIVector",
                               kCIAttributeDisplayName: "Blue Shift (HSL)",
                               kCIAttributeDescription: "Set the hue, saturation and lightness for this color band.",
                               kCIAttributeDefault: CIVector(x: 0, y: 1, z: 1),
                               kCIAttributeType: kCIAttributeTypePosition3],
            
            "inputPurpleShift": [kCIAttributeIdentity: 0,
                                 kCIAttributeClass: "CIVector",
                                 kCIAttributeDisplayName: "Purple Shift (HSL)",
                                 kCIAttributeDescription: "Set the hue, saturation and lightness for this color band.",
                                 kCIAttributeDefault: CIVector(x: 0, y: 1, z: 1),
                                 kCIAttributeType: kCIAttributeTypePosition3],
            
            "inputMagentaShift": [kCIAttributeIdentity: 0,
                                  kCIAttributeClass: "CIVector",
                                  kCIAttributeDisplayName: "Magenta Shift (HSL)",
                                  kCIAttributeDescription: "Set the hue, saturation and lightness for this color band.",
                                  kCIAttributeDefault: CIVector(x: 0, y: 1, z: 1),
                                  kCIAttributeType: kCIAttributeTypePosition3],
        ]
    }
    
    override var outputImage: CIImage? {
        guard let inputImage = inputImage else {
            return nil
        }
        
        return multiBandHSVKernel.apply(extent: inputImage.extent, roiCallback: {
                                                                    (index, rect) in
                                                                    return rect
                                                  },
                                                  arguments: [inputImage,
                                                              inputRedShift,
                                                              inputOrangeShift,
                                                              inputYellowShift,
                                                              inputGreenShift,
                                                              inputAquaShift,
                                                              inputBlueShift,
                                                              inputPurpleShift,
                                                              inputMagentaShift])
    }
}

class WhiteFilter: CIFilter {
    var inputImage: CIImage?
    
    override var outputImage : CIImage!
    {
        if let inputImage = inputImage {
            let arguments = [inputImage] as [Any]
            let extent = inputImage.extent.expand(size: 200)
            
            return CustomKernel().apply(extent: extent,
                                        roiCallback:
                {
                    (index, rect) in
                    return rect
            }, arguments: arguments)
        }
        return nil
    }
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "White" as AnyObject,
            
            "inputImage": [kCIAttributeIdentity: 0,
                           kCIAttributeClass: "CIImage",
                           kCIAttributeDisplayName: "Image",
                           kCIAttributeType: kCIAttributeTypeImage]
        ]
    }
    
    func CustomKernel() -> CIKernel {
        let kernel =
            "kernel vec4 white(sampler image){\n" +
                "  return vec4(1.0);\n" +
            "}"
        return CIKernel(source: kernel)!
    }
    
}

class HighlightFilter: CIFilter {
    var inputImage: CIImage?
    var inputUnit: CGFloat = 0.0
    
    override var outputImage : CIImage!
    {
        if let inputImage = inputImage {
            let arguments = [inputImage, inputUnit] as [Any]
            let extent = inputImage.extent
            
            return CustomKernel().apply(extent: extent,
                                        roiCallback:
                {
                    (index, rect) in
                    return rect
            }, arguments: arguments)
        }
        return nil
    }
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "Highlight Filter" as AnyObject,
            
            "inputImage": [kCIAttributeIdentity: 0,
                           kCIAttributeClass: "CIImage",
                           kCIAttributeDisplayName: "Image",
                           kCIAttributeType: kCIAttributeTypeImage],
            
            "inputUnit": [kCIAttributeIdentity: 0,
                          kCIAttributeClass: "NSNumber",
                          kCIAttributeDefault: 0.0,
                          kCIAttributeDisplayName: "Unit",
                          kCIAttributeMin: -2,
                          kCIAttributeMax: 2,
                          kCIAttributeSliderMin: -2,
                          kCIAttributeSliderMax: 2,
                          kCIAttributeType: kCIAttributeTypeScalar]
        ]
    }
    
    func CustomKernel() -> CIKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")
        let data = try! Data(contentsOf: url!)
        let kernel = try! CIKernel(functionName: "highlight", fromMetalLibraryData: data)
        
        return kernel
    }
    
}

class SaturationFilter: CIFilter {
    var inputImage: CIImage?
    var inputUnit: CGFloat = 1.0
    
    override var outputImage : CIImage!
    {
        if let inputImage = inputImage {
            let arguments = [inputImage, inputUnit] as [Any]
            let extent = inputImage.extent
            
            return CustomKernel().apply(extent: extent,
                                        roiCallback:
                {
                    (index, rect) in
                    return rect
            }, arguments: arguments)
        }
        return nil
    }
    
    override func setDefaults() {
        inputUnit = 1.0
    }
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "Saturation Filter" as AnyObject,
            
            "inputImage": [kCIAttributeIdentity: 0,
                           kCIAttributeClass: "CIImage",
                           kCIAttributeDisplayName: "Image",
                           kCIAttributeType: kCIAttributeTypeImage],
            
            "inputUnit": [kCIAttributeIdentity: 0,
                          kCIAttributeClass: "NSNumber",
                          kCIAttributeDefault: 1.0,
                          kCIAttributeDisplayName: "Unit",
                          kCIAttributeMin: 0,
                          kCIAttributeMax: 2,
                          kCIAttributeSliderMin: 0,
                          kCIAttributeSliderMax: 2,
                          kCIAttributeType: kCIAttributeTypeScalar]
        ]
    }
    
    func CustomKernel() -> CIColorKernel {
        let kernel =
            "kernel vec4 saturationKernel(sampler image, float saturation){\n" +
                "const vec3 luminanceWeighting = vec3(0.2126, 0.7152, 0.0722);" +
                "vec3 pixel = sample(image, samplerCoord(image)).rgb;" +
                "float luminance = dot(pixel, luminanceWeighting);" +
                "vec3 greyScaleColor = vec3(luminance);" +
                "vec3 newPixel = clamp(mix(greyScaleColor, pixel, saturation), vec3(0.0), vec3(1.0));" +
                "return vec4(newPixel, 1.0);" +
            "}"
        return CIColorKernel(source: kernel)!
    }
    
}
