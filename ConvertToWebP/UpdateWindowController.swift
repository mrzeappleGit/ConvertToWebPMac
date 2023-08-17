//
//  UpdateWindowController.swift
//  ConvertToWebP
//
//  Created by Matthew Stevens on 8/17/23.
//

import Cocoa

class UpdateWindowController: NSWindowController {

    // Store the download URL to open when the user clicks the "Download Now" button.
    private var downloadUrl: String?

    override func windowDidLoad() {
        super.windowDidLoad()

        // Link the button's action to the downloadUpdate function
        // Assuming the button has a tag of 1 set in Interface Builder
        if let button = self.window?.contentView?.viewWithTag(1) as? NSButton {
            button.target = self
            button.action = #selector(downloadUpdate)
        }
    }
    
    func showUpdateWindow(downloadUrl: String) {
        self.downloadUrl = downloadUrl
        self.window?.makeKeyAndOrderFront(nil)
    }

    @objc @IBAction func downloadUpdate(_ sender: Any) {
        if let url = URL(string: self.downloadUrl ?? "") {
            NSWorkspace.shared.open(url)
        }
    }
}
