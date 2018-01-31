//
//  Enums.swift
//  Filmroom for Mac
//
//  Created by 周建明 on 2017/8/26.
//  Copyright © 2017年 周建明. All rights reserved.
//

import Cocoa
import CoreFoundation

enum AspectRadio: String{
    case w16h9 = "608 342"
    case w9h16 = "342 608"
    case w2h3 = "400 600"
    case w3h2 = "600 400"
    case cube = "500 500"
    
    // Unknow Radio
    case horizontal = "600 450"
    case vertical = "450 600"
}

enum Filter: String {
    case None
    case Guassian = "CIGaussianBlur"
    case Box = "CIBoxBlur"
    case Motion = "CIMotionBlur"
    case Sharpen = "CISharpenLuminance"
    case Pixelization = "CIPixellate"
    case Denoise = "CINoiseReduction"
    case Distortion = "CIPinchDistortion"
    
    func isBlur() -> Bool {
        switch self {
        case .Guassian, .Box, .Motion:
            return true
        default:
            return false
        }
    }
}
