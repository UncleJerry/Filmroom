//
//  LaunchConfiguration.swift
//  Filmroom
//
//  Created by 周建明 on 10/4/2018.
//  Copyright © 2018年 Uncle Jerry. All rights reserved.
//

import Foundation
import Metal
import MetalKit

var device: MTLDevice = MTLCreateSystemDefaultDevice()!
var commandQueue: MTLCommandQueue! = device.makeCommandQueue()

/// A Metal library
var defaultLibrary:MTLLibrary! = device.makeDefaultLibrary()

