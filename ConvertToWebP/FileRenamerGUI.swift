//
//  FileRenamerGUI.swift
//  ConvertToWebP
//
//  Created by Matthew Stevens on 8/15/23.
//

import SwiftUI
import Cocoa
import Foundation

struct FileRenamerView: View {
    @State private var folderPath: String = ""
    @State private var singleFilePath: String = ""
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Location Folder:")
                TextField("Folder Path", text: $folderPath)
                Button("Select Folder") {
                    self.folderPath = FileSelector.selectFolder() ?? ""
                }
            }

            HStack {
                Text("Single File:")
                TextField("File Path", text: $singleFilePath)
                Button("Select File") {
                    self.singleFilePath = FileSelector.selectFile() ?? ""
                }
            }

            Button("Rename Files") {
                renameFiles()
            }
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    func renameFiles() {
        if folderPath.isEmpty && singleFilePath.isEmpty {
            alertTitle = "Error"
            alertMessage = "Please select a source folder or a file."
            showAlert = true
            return
        }
        
        var files: [String] = []
        
        // If a folder is selected, get all files within that folder
        if !folderPath.isEmpty {
            let fileManager = FileManager.default
            if let fileURLs = try? fileManager.contentsOfDirectory(atPath: folderPath) {
                for fileURL in fileURLs {
                    files.append("\(folderPath)/\(fileURL)")
                }
            }
        }
        
        // If a single file is selected, use its path
        if !singleFilePath.isEmpty {
            files.append(singleFilePath)
        }
        
        // Rename each file
        for file in files {
            if let newPath = renameFile(path: file) {
                do {
                    try FileManager.default.moveItem(atPath: file, toPath: newPath)
                } catch {
                    print("Error renaming file: \(error)")
                }
            }
        }
        
        let alert = NSAlert()
        alert.messageText = "Success"
        alert.informativeText = "All files have been renamed."
        alert.runModal()
    }

    func renameFile(path: String) -> String? {
        let fileName = (path as NSString).lastPathComponent
        let fileExtension = (fileName as NSString).pathExtension
        let baseName = (fileName as NSString).deletingPathExtension
        
        // Use regular expressions to rename the file
        let pattern1 = "[^\\w\\s-]"
        let pattern2 = "[-_]+"
        let pattern3 = "^-|-$"
        
        var newName = baseName
        newName = newName.replacingOccurrences(of: pattern1, with: "", options: .regularExpression)
        newName = newName.lowercased()
        newName = newName.replacingOccurrences(of: " ", with: "-")
        newName = newName.replacingOccurrences(of: pattern2, with: "-", options: .regularExpression)
        newName = newName.replacingOccurrences(of: pattern3, with: "", options: .regularExpression)
        
        let newFilePath = "\((path as NSString).deletingLastPathComponent)/\(newName).\(fileExtension)"
        
        return newFilePath
    }
}

struct FileSelector {
    static func selectFolder() -> String? {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        if openPanel.runModal() == .OK {
            return openPanel.urls.first?.path
        }
        return nil
    }
    
    static func selectFile() -> String? {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        if openPanel.runModal() == .OK {
            return openPanel.urls.first?.path
        }
        return nil
    }
}
