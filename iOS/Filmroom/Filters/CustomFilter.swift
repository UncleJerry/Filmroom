//
//  CustomFilter.swift
//  Filmroom
//
//  Created by 周建明.
//  Copyright © 2018年 Uncle Jerry. All rights reserved.
//

import Foundation
import CoreImage


class ExposureFilter: CIFilter {
    var inputImage: CIImage?
    var inputUnit: CGFloat = 0.0
    /*
    override public var outputImage: CIImage! {
        get {
            if let inputImage = self.inputImage {
                let args = [inputImage, inputUnit] as [Any]
                return CustomKernel().apply(withExtent: inputImage.extent, arguments: args)
            }else{
                return nil
            }
        }
    }*/
    
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
        inputUnit = 0.0
    }
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "Exposure Filter" as AnyObject,
            
            "inputImage": [kCIAttributeIdentity: 0,
                           kCIAttributeClass: "CIImage",
                           kCIAttributeDisplayName: "Image",
                           kCIAttributeType: kCIAttributeTypeImage],
            
            "inputUnit": [kCIAttributeIdentity: 0,
                            kCIAttributeClass: "NSNumber",
                            kCIAttributeDefault: 0.0,
                            kCIAttributeDisplayName: "Unit",
                            kCIAttributeMin: -1,
                            kCIAttributeMax: 1,
                            kCIAttributeSliderMin: -1,
                            kCIAttributeSliderMax: 1,
                            kCIAttributeType: kCIAttributeTypeScalar]
        ]
    }
    
    func CustomKernel() -> CIColorKernel {
        let kernel =
            "kernel vec4 exposureKernel(sampler image, float exposure){\n" +
                "  vec3 pixel = sample(image, samplerCoord(image)).rgb;" +
                "  vec3 newPixel = pixel * pow(2.0, exposure);" +
                "  return vec4(newPixel, 1.0);\n" +
            "}"
        return CIColorKernel(source: kernel)!
    }
    
}

class ShadowFilter: CIFilter {
    var inputImage: CIImage?
    var inputUnit: CGFloat = 0.0
    
    override var outputImage : CIImage!
    {
        if let inputImage = inputImage {
            let arguments = [inputImage, inputUnit] as [Any]
            let extent = inputImage.extent
            
            return CustomKernel().apply(extent: extent, arguments: arguments)
        }
        return nil
    }
    
    override func setDefaults() {
        inputUnit = 0.0
    }
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "Shadow Filter" as AnyObject,
            
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
    
    func CustomKernel() -> CIColorKernel {
        let kernel =
            "kernel vec4 shadowKernel(sampler image, float unit){\n" +
                "vec3 luminanceWeighting = vec3(0.2126, 0.7152, 0.0722);" +
                "vec3 pixel = sample(image, samplerCoord(image)).rgb;" +
                "float luminance = dot(pixel, luminanceWeighting);" +
                "float shadowGreyScale = clamp(luminance - 0.25, 0.0, 0.2);" +
                "float weight = clamp(1.0 - (pow(shadowGreyScale, 2.0) * 20.0 - 1.0 * shadowGreyScale), 0.0, 1.0);" +
                "vec3 newPixel = pixel * pow(2.0, unit * weight);" +
                "newPixel = clamp(newPixel, vec3(0.0), vec3(1.0));" +
                "return vec4(newPixel, 1.0);" +
        "}"
        return CIColorKernel(source: kernel)!
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
    
    override func setDefaults() {
        inputUnit = 0.0
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
    
    func CustomKernel() -> CIColorKernel {
        let kernel =
                "kernel vec4 highlightKernel(sampler image, float unit){\n" +
                "const vec3 luminanceWeighting = vec3(0.2126, 0.7152, 0.0722);" +
                "vec3 pixel = sample(image, samplerCoord(image)).rgb;" +
                "float luminance = dot(pixel, luminanceWeighting);" +
                "float shadowGreyScale = clamp(luminance - 0.55, 0.0, 0.2);" +
                "float weight = clamp((pow(shadowGreyScale, 2.0) * 20.0 + 1.0 * shadowGreyScale), 0.0, 1.0);" +
                "vec3 newPixel = pixel * pow(2.0, unit * weight);" +
                "newPixel = clamp(newPixel, vec3(0.0), vec3(1.0));" +
                "return vec4(newPixel, 1.0);" +
        "}"
        return CIColorKernel(source: kernel)!
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

class ContrastFilter: CIFilter {
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
            kCIAttributeFilterDisplayName: "Contrast Filter" as AnyObject,
            
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
            "kernel vec4 contrastKernel(sampler image, float contrast){\n" +
                "vec3 pixel = sample(image, samplerCoord(image)).rgb;" +
                "vec3 newPixel = (pixel - vec3(0.5)) * contrast + vec3(0.5);" +
                "return vec4(newPixel, 1.0);" +
            "}"
        return CIColorKernel(source: kernel)!
    }
    
}

class HSLFilter: CIFilter {
    var inputImage: CIImage?
    var inputShift0 = CIVector(x: 0, y: 1, z: 1)
    let inputShift1 = CIVector(x: 0, y: 1, z: 1)
    
    
    override public var outputImage: CIImage! {
        get {
            if let inputImage = self.inputImage {
                let args = [inputImage, inputShift0, inputShift1] as [Any]
                return CustomKernel().apply(extent: inputImage.extent, arguments: args)
            }else{
                return nil
            }
        }
    }
    
    override func setDefaults() {
        inputShift0 = CIVector(x: 0, y: 1, z: 1)
    }
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "HSL Orange Filter" as AnyObject,
            
            "inputImage": [kCIAttributeIdentity: 0,
                           kCIAttributeClass: "CIImage",
                           kCIAttributeDisplayName: "Image",
                           kCIAttributeType: kCIAttributeTypeImage],
            
            "inputShift0": [kCIAttributeIdentity: 0,
                          kCIAttributeClass: "CIVector",
                          kCIAttributeDefault: CIVector(x: 0, y: 1, z: 1),
                          kCIAttributeDisplayName: "Orange Shift",
                          kCIAttributeType: kCIAttributeTypePosition3],
            
            "inputShift1": [kCIAttributeIdentity: 0,
                            kCIAttributeClass: "CIVector",
                            kCIAttributeDefault: CIVector(x: 0, y: 1, z: 1),
                            kCIAttributeDisplayName: "Yellow Shift",
                            kCIAttributeType: kCIAttributeTypePosition3]
        ]
    }
    
    
    /*
     This kernel and the hue value is adopt from
     https://flexmonkey.blogspot.jp/2016/03/creating-selective-hsl-adjustment.html?view=mosaic with understanding and re-written
     https://gist.github.com/patriciogonzalezvivo/114c1653de9e3da6e1e3 with understanding
     */
    func CustomKernel() -> CIColorKernel {
        let kernel =
            "vec3 rgb2hsv(vec3 rgb){" +
                "vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);" +
                "vec4 p = mix(vec4(rgb.bg, K.wz), vec4(rgb.gb, K.xy), step(rgb.b, rgb.g));" +
                "vec4 q = mix(vec4(p.xyw, rgb.r), vec4(rgb.r, p.yzx), step(p.x, rgb.r));" +
                "float distance = q.x - min(q.w, q.y);" +
                "float e = 1.0e-10;" +
                "return vec3(abs(q.z + (q.w - q.y) / (6.0 * distance + e)), distance / (q.x + e), q.x);" +
            "}" +
    
            "vec3 hsv2rgb(vec3 c){" +
                "vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);" +
                "vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);" +
                "return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);" +
            "}" +
        
            "kernel vec4 enhanceSkin(sampler image, vec3 shift0, vec3 shift1){\n" +
                "vec3 hsv = rgb2hsv(sample(image, samplerCoord(image)).rgb);" +
                "if (hsv.x >= 0.0419254281277998 && hsv.x < 0.124741238538867) {" +
                    "float smoothedHue = smoothstep(0.0419254281277998, 0.124741238538867, hsv.x);" +
                    "float hue = hsv.x + (shift0.x + ((shift1.x - shift0.x) * smoothedHue));" +
                    "float sat = hsv.y * (shift0.y + ((shift1.y - shift0.y) * smoothedHue));" +
                    "float lum = hsv.z * (shift0.z + ((shift1.z - shift0.z) * smoothedHue));" +
                    "hsv = vec3(hue, sat, lum);" +
                "}" +
                "vec3 newPixel = clamp(hsv2rgb(hsv), vec3(0.0), vec3(1.0));" +
                "return vec4(newPixel, 1.0);" +
            "}"
        return CIColorKernel(source: kernel)!
    }
    
}

class GammaAdjust: CIFilter {
    var inputImage: CIImage?
    var inputUnit: CGFloat = 1.0
    
    func CustomKernel() -> CIKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")
        let data = try! Data(contentsOf: url!)
        let kernel = try! CIKernel(functionName: "gamma", fromMetalLibraryData: data)
        
        return kernel
    }
    
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
            kCIAttributeFilterDisplayName: "Gamma Filter" as AnyObject,
            
            "inputImage": [kCIAttributeIdentity: 0,
                           kCIAttributeClass: "CIImage",
                           kCIAttributeDisplayName: "Image",
                           kCIAttributeType: kCIAttributeTypeImage],
            
            "inputUnit": [kCIAttributeIdentity: 0,
                          kCIAttributeClass: "NSNumber",
                          kCIAttributeDefault: 1.0,
                          kCIAttributeDisplayName: "Unit",
                          kCIAttributeMin: 0,
                          kCIAttributeMax: 3,
                          kCIAttributeSliderMin: 0,
                          kCIAttributeSliderMax: 3,
                          kCIAttributeType: kCIAttributeTypeScalar]
        ]
    }
}
