//
//  ImageConverterGUI.swift
//  ConvertToWebP
//
//  Created by Matthew Stevens on 8/15/23.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers
import SDWebImage
import SDWebImageWebPCoder

struct ImageConverterGUI: View {
    @State private var folderPath: String = ""
    @State private var destinationFolderPath: String = ""
    @State private var quality: Double = 100.0
    @State private var newWidthPercentage: Double = 100.0
    @State private var compress: Bool = false
    @State private var rename: Bool = false
    @State private var convert: Bool = false
    @State private var progress: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Image/Folder:")
                TextField("", text: $folderPath)
                    .border(Color.gray, width: 1)
                Button("Select Folder") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.urls.first {
                        folderPath = url.path
                    }
                }
                Button("Select File") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.urls.first {
                        folderPath = url.path
                    }
                }
            }

            HStack {
                Text("Destination Folder:")
                TextField("", text: $destinationFolderPath)
                    .border(Color.gray, width: 1)
                Button("Select Folder") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.urls.first {
                        destinationFolderPath = url.path
                    }
                }
            }
            HStack{
                Toggle(isOn: $compress) {
                    Text("Compress")
                }
                Toggle(isOn: $rename) {
                    Text("Rename")
                }
                
                Toggle(isOn: $convert) {
                    Text("Convert")
                }
            }
            
            HStack {
                Text("Quality:")
                Slider(value: $quality, in: 0...100)
                Text("\(Int(quality))%")
            }
            
            HStack {
                Text("Resize Width (%):")
                Slider(value: $newWidthPercentage, in: 1...100)
                Text("\(Int(newWidthPercentage))%")
            }
            
            Button("Run") {
                convertImages()
            }
            
            ProgressView(value: progress, total: 100)
        }
        .padding()
    }
    
    func convertImages() {
        // Fetch all image files from the source directory recursively
        let imageFiles = fetchImageFiles(from: folderPath)
        let totalImages = imageFiles.count
        var processedImages = 0

        DispatchQueue.global(qos: .userInitiated).async {
            for file in imageFiles {
                // Load the image
                guard let inputImage = NSImage(contentsOfFile: file) else {
                    print("Failed to load the image from: \(file)")
                    continue
                }

                // Resize the image
                let scaleFactor = CGFloat(self.newWidthPercentage / 100.0)
                let newSize = CGSize(width: inputImage.size.width * scaleFactor, height: inputImage.size.height * scaleFactor)
                
                inputImage.size = newSize
                guard let imageRep = NSBitmapImageRep(data: inputImage.tiffRepresentation!),
                      let resizedData = imageRep.representation(using: .jpeg, properties: [:]) else {
                    print("Failed to resize the image: \(file)")
                    continue
                }
                
                let resizedImage = NSImage(data: resizedData)

                // Save as WebP
                let webPData = resizedImage?.sd_imageData(as: .webP, compressionQuality: CGFloat(self.quality / 100.0))

                // Determine the destination path
                let relativePath = file.replacingOccurrences(of: self.folderPath, with: "")
                var finalRelativePath = relativePath

                if self.rename {
                    let folderPath = URL(fileURLWithPath: relativePath).deletingLastPathComponent().path
                    let filename = URL(fileURLWithPath: relativePath).deletingPathExtension().lastPathComponent
                    let renamedFilename = self.renameFile(filename)
                    print(renamedFilename)
                    finalRelativePath = folderPath + "/" + renamedFilename + "a.webp"
                }

                let destinationURL = URL(fileURLWithPath: self.destinationFolderPath).appendingPathComponent(finalRelativePath)

                // Ensure the directory exists
                let directory = destinationURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

                // Write to file
                try? webPData?.write(to: destinationURL)

                processedImages += 1
                let progressValue = Double(processedImages) / Double(totalImages) * 100.0

                // Update progress on the main thread
                DispatchQueue.main.async {
                    self.progress = progressValue
                }
            }
        }
    }

    func renameFile(_ filename: String) -> String {
        var newName = filename
        print("Original Name: \(newName)")
        
        // Remove special characters (non-alphanumeric and non-hyphen/underscore/space)
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        newName = newName.components(separatedBy: allowedCharacters.inverted).joined()
        print("After removing special characters: \(newName)")
        
        // Convert to lowercase
        newName = newName.lowercased()
        print("After converting to lowercase: \(newName)")
        
        // Replace spaces with hyphens
        newName = newName.replacingOccurrences(of: " ", with: "-")
        print("After replacing spaces with hyphens: \(newName)")
        
        // Remove underscores and reduce multiple hyphens to a single hyphen
        newName = newName.replacingOccurrences(of: "_", with: "")
        newName = newName.replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
        print("After removing underscores and reducing multiple hyphens: \(newName)")
        
        // Remove leading and trailing hyphens
        newName = newName.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        print("After removing leading and trailing hyphens: \(newName)")

        return newName
    }
        
    func fetchImageFiles(from directory: String) -> [String] {
        guard let enumerator = FileManager.default.enumerator(atPath: directory) else { return [] }
        
        var imageFiles: [String] = []
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png"]
        
        for case let file as String in enumerator {
            let fileExtension = URL(fileURLWithPath: file).pathExtension.lowercased()
            if imageExtensions.contains(fileExtension) {
                imageFiles.append(directory + "/" + file)
            }
        }
        
        return imageFiles
    }
        
}
