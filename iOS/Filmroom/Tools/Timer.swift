//
//  Timer.swift
//  Filmroom
//
//  Created by 周建明.
//  Copyright © 2018年 Uncle Jerry. All rights reserved.
//

import Foundation

class Timer{
    var start: Date
    var end: Date?
    
    init() {
        // Mark current time
        start = Date()
        end = nil
    }
    
    func stop(){
        // Mark stop time
        end = Date()
    }
    
    func showTime() {
        let interval = Calendar.current.dateComponents([Calendar.Component.nanosecond], from: start, to: end!)
        
        print("Consuming \(String(describing: Double(interval.nanosecond!) * 0.000000001))s")
    }
}
