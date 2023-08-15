//
//  AppDelegate.swift
//  ConvertToWebP
//
//  Created by Matthew Stevens on 8/15/23.
//

import Foundation
import Cocoa
import SDWebImage
import SDWebImageWebPCoder

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Register SDWebImageWebPCoder to support WebP
        let webPCoder = SDImageWebPCoder.shared
        SDImageCodersManager.shared.addCoder(webPCoder)
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    // Any other delegate methods and properties you need...
}
