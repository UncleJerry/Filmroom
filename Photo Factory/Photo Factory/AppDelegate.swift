//
//  AppDelegate.swift
//  Photo Factory
//
//  Created by 周建明 on 2017/11/28.
//  Copyright © 2017年 周建明. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {



    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @IBAction func Open(_ sender: NSMenuItem) {
        
    }
    
    @IBAction func ApplyFilter(_ sender: NSMenuItem) {
        let identity = sender.identifier!.rawValue
        complexOperation = Filter(rawValue: identity)!
    }
}

