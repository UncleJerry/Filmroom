//
//  FilterVendor.swift
//  Filmroom
//
//  Created by 周建明 on 2017/7/18.
//  Copyright © 2017年 Uncle Jerry. All rights reserved.
//

import Foundation
import CoreImage

class FilterVendor: NSObject, CIFilterConstructor {
    
    func filter(withName name: String) -> CIFilter? {
        switch name
        {
        case "Exposure Filter":
            return ExposureFilter()
            
        default:
            return nil
        }
    }

}
