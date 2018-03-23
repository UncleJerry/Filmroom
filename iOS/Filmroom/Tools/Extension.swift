//
//  Extension.swift
//  Filmroom
//
//  Created by 周建明.
//  Copyright © 2018年 Uncle Jerry. All rights reserved.
//

import UIKit
import Metal
import CoreGraphics
import Accelerate

extension UIViewController {
    
    func ErrorAlert(message: String) {
        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        
        let defaultAction = UIAlertAction(title: "Alright", style: .default, handler: nil)
        alertController.addAction(defaultAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
}


extension MTLTexture{
    
    /**
     Reference to https://gist.github.com/codelynx/4e56758fb89e94d0d1a58b40ddaade45
     */
    
    var toUIImage: UIImage {
        
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
        guard let data = CFDataCreate(nil, rgbaBytes, length) else { return UIImage() }
        guard let dataProvider = CGDataProvider(data: data) else { return UIImage() }
        let cgImage = CGImage(width: self.width, height: self.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: rowBytes, space: colorScape, bitmapInfo: bitmapInfo, provider: dataProvider,
                              decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        
        return UIImage(cgImage: cgImage!, scale: 0.0, orientation: UIImageOrientation.up)
    }
}



enum AspectRadio: String{
    case w16h9 = "304 171"
    case w9h16 = "171 304"
    case w2h3 = "200 300"
    case w3h2 = "300 200"
    case cube = "200 200"
    
    // Unknow Radio
    case horizontal = "300 225"
    case vertical = "225 300"
}

extension UIView{
    func changeSize(imageCase: AspectRadio) {
        let substr = imageCase.rawValue.split(separator: " ")
        let width = Int(substr[0])
        let height = Int(substr[1])
        self.frame = CGRect(x: 30, y: 50, width: width!, height: height!)
    }
}

extension UIImage{
    var aspectRadio: AspectRadio {
        let radio: Double = Double(self.size.width) / Double(self.size.height)
        
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

