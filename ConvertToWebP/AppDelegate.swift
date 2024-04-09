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

class UpdateManager {
    static let currentVersion = "1.3.1"  // Replace with your current app version
    static let SERVER_URL = URL(string: "https://webp.mts-studios.com:5001/current_version")!
    
    static func checkForUpdates(completion: @escaping (Bool, String?) -> Void) {
        var request = URLRequest(url: SERVER_URL)
        request.setValue("convertToWebPMac/1.0", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: String], let latestVersion = json["version"], let downloadUrl = json["download_url"] {
                DispatchQueue.main.async {
                    completion(latestVersion > currentVersion, downloadUrl)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, nil)
                }
            }
        }.resume()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var updateWindowController: UpdateWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("Application did finish launching.")
        setupMenu()
        // Register SDWebImageWebPCoder to support WebP
        let webPCoder = SDImageWebPCoder.shared
        SDImageCodersManager.shared.addCoder(webPCoder)
        
        // Check for updates
        UpdateManager.checkForUpdates { updateAvailable, downloadUrl in
            if updateAvailable, let downloadUrl = downloadUrl {
                print("Update available!")
                // Instantiate and show the update window
                self.updateWindowController = UpdateWindowController(windowNibName: "UpdateWindowController")
                self.updateWindowController?.showUpdateWindow(downloadUrl: downloadUrl)
            }
        }

        // Set up the "Check for Updates..." menu item in the Help menu
        
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    // Set up the menu item for manual update checks
    func setupMenu() {
        print("Setting up menu...")
        
        guard let mainMenu = NSApp.mainMenu else {
            print("Main menu not found.")
            return
        }

        // Create a new "Updates" menu
        let updatesMenu = NSMenu(title: "Updates")
        let checkForUpdatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdatesManually), keyEquivalent: "")
        checkForUpdatesItem.target = self
        updatesMenu.addItem(checkForUpdatesItem)
        
        let updatesMenuItem = NSMenuItem()
        updatesMenuItem.submenu = updatesMenu

        // Insert the "Updates" menu before the "Help" menu (assuming the "Help" menu is the last item)
        let insertionIndex = max(mainMenu.items.count - 1, 0)
        mainMenu.insertItem(updatesMenuItem, at: insertionIndex)
    }





    // Check for updates manually when the menu item is selected
    @objc func checkForUpdatesManually() {
        UpdateManager.checkForUpdates { updateAvailable, downloadUrl in
            if updateAvailable, let downloadUrl = downloadUrl {
                print("Update available!")
                // Instantiate and show the update window
                self.updateWindowController = UpdateWindowController(windowNibName: "UpdateWindowController")
                self.updateWindowController?.showUpdateWindow(downloadUrl: downloadUrl)
            } else {
                let alert = NSAlert()
                alert.messageText = "No Updates Available"
                alert.informativeText = "You are using the latest version."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
    
    // Any other delegate methods and properties you need...
}
