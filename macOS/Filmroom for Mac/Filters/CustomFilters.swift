//
//  CustomFilter.swift
//  Filmroom
//
//  Created by 周建明 on 2017/7/8.
//  Copyright © 2017年 Uncle Jerry. All rights reserved.
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
    
    func CustomKernel() -> CIKernel {
        let url = Bundle.main.url(forResource: "default", withExtension: "metallib")
        let data = try! Data(contentsOf: url!)
        let kernel = try! CIKernel(functionName: "exposure", fromMetalLibraryData: data)
        
        return kernel
    }
    
}

class GammaAdjust: CIFilter {
    var inputImage: CIImage?
    var inputUnit: CGFloat = 0.0
    
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
