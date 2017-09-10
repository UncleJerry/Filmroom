//
//  Extension.swift
//  Filmroom for Mac
//
//  Created by 周建明 on 2017/8/14.
//  Copyright © 2017年 周建明. All rights reserved.
//

import Cocoa
import MetalKit
import CoreGraphics
import Accelerate

extension NSImage {
    func writeJPG(toURL url: URL) {
        
        guard let data = tiffRepresentation,
            let rep = NSBitmapImageRep(data: data),
            let imgData = rep.representation(using: .jpeg, properties: [.compressionFactor : NSNumber(floatLiteral: 1.0)]) else {
                
                Swift.print("\(self.self) Error Function '\(#function)' Line: \(#line) No tiff rep found for image writing to \(url)")
                return
        }
        
        do {
            try imgData.write(to: url)
        }catch let error {
            Swift.print("\(self.self) Error Function '\(#function)' Line: \(#line) \(error.localizedDescription)")
        }
    }
    
    var toCIImage: CIImage {
        get{
            let imgData = self.tiffRepresentation
            return CIImage(data: imgData!)!
        }
    }
}


/**
 Reference to https://gist.github.com/codelynx/4e56758fb89e94d0d1a58b40ddaade45
 */

extension MTLTexture {
    
    var toCGImage: CGImage? {
        
        assert(self.pixelFormat == .bgra8Unorm)
        
        // read texture as byte array
        let rowBytes = self.width * 4
        let length = rowBytes * self.height
        let bgraBytes = [UInt8](repeating: 0, count: length)
        let region = MTLRegionMake2D(0, 0, self.width, self.height)
        self.getBytes(UnsafeMutableRawPointer(mutating: bgraBytes), bytesPerRow: rowBytes, from: region, mipmapLevel: 0)
        
        // use Accelerate framework to convert from BGRA to RGBA
        var bgraBuffer = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: bgraBytes),
                                       height: vImagePixelCount(self.height), width: vImagePixelCount(self.width), rowBytes: rowBytes)
        let rgbaBytes = [UInt8](repeating: 0, count: length)
        var rgbaBuffer = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: rgbaBytes),
                                       height: vImagePixelCount(self.height), width: vImagePixelCount(self.width), rowBytes: rowBytes)
        let map: [UInt8] = [2, 1, 0, 3]
        vImagePermuteChannels_ARGB8888(&bgraBuffer, &rgbaBuffer, map, 0)
        
        // create CGImage with RGBA
        let colorScape = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let data = CFDataCreate(nil, rgbaBytes, length) else { return nil }
        guard let dataProvider = CGDataProvider(data: data) else { return nil }
        let cgImage = CGImage(width: self.width, height: self.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: rowBytes, space: colorScape, bitmapInfo: bitmapInfo, provider: dataProvider,
                              decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        return cgImage
    }
    
    var toNSImage: NSImage? {
        guard let cgImage = self.toCGImage else { return nil }
        return NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
    }
    
    var aspectRadio: AspectRadio {
        let radio: Double = Double(self.width) / Double(self.height)
        
        if radio == 16.0 / 9.0 {
            return AspectRadio.w16h9
        }else if radio == 9.0 / 16.0 {
            return AspectRadio.w9h16
        }else if radio == 2.0 / 3{
            return AspectRadio.w2h3
        }else if radio == 3.0 / 2.0{
            return AspectRadio.w3h2
        }else if radio == 1.0 {
            return AspectRadio.cube
        }else if radio > 1.0 {
            return AspectRadio.horizontal
        }else if radio < 1.0 {
            return AspectRadio.vertical
        }
        
        return AspectRadio.cube
    }
    
}

extension AspectRadio {
    var FrameSize: NSSize {
        return NSSizeFromString(self.rawValue)
    }
}

extension CIImage{
    /**
     Reference to https://gist.github.com/chriseidhof/f6997b5b1d8e2e8ccc2b
 
    var toNSImage: NSImage {
        let rep = NSCIImageRep(CIImage: self.matchedFromWorkingSpace(to: ))
        let nsImage = NSImage(size: self.extent.size)
        nsImage.addRepresentation(rep)
        
        return nsImage
    }*/
}

