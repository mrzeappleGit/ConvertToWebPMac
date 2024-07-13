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
    @State private var resize: Bool = false
    
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
                Toggle(isOn: $resize){
                    Text("Resize")
                }
            }
            
            HStack {
                Text("Quality:")
                Slider(value: $quality, in: 0...100)
                    .disabled(!compress)
                TextField("", value: $quality, formatter: NumberFormatter(), onCommit: {
                                if self.quality > 100 {
                                    self.quality = 100
                                }
                            })
                                .frame(width: 50)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(!compress)
                Text("%")
            }
            
            HStack {
                Text("Resize Width (%):")
                Slider(value: $newWidthPercentage, in: 1...100)
                    .disabled(!resize)
                TextField("", value: $newWidthPercentage, formatter: NumberFormatter(), onCommit: {
                                if self.newWidthPercentage > 100 {
                                    self.newWidthPercentage = 100
                                }
                            })
                                .frame(width: 50)
                                .multilineTextAlignment(.center)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(!resize)
                Text("%")
            }
            
            Button("Run") {
                convertImages()
            }
            
            ProgressView(value: progress, total: 100)
        }
        .padding()
    }
    
    func convertImages() {
        // Check if the folderPath is a directory or a file
        var imageFiles: [String] = []
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                // Fetch all image files from the source directory recursively
                imageFiles = fetchImageFiles(from: folderPath)
            } else {
                // Process only the single file selected
                imageFiles = [folderPath]
            }
        }
        
        let totalImages = imageFiles.count
        var processedImages = 0

        let isSingleFile = !isDirectory.boolValue

        DispatchQueue.global(qos: .userInitiated).async {
            for file in imageFiles {
                // Load the image
                guard let inputImage = NSImage(contentsOfFile: file) else {
                    print("Failed to load the image from: \(file)")
                    continue
                }

                // Resize the image
                var outputImage: NSImage? = inputImage
                if self.resize {
                    let scaleFactor = CGFloat(self.newWidthPercentage / 100.0)
                    let newSize = CGSize(width: inputImage.size.width * scaleFactor, height: inputImage.size.height * scaleFactor)
                    
                    let newRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(newSize.width), pixelsHigh: Int(newSize.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: NSColorSpaceName.deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                    
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: newRep)
                    inputImage.draw(in: NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height), from: NSZeroRect, operation: .copy, fraction: 1.0)
                    NSGraphicsContext.restoreGraphicsState()
                    
                    outputImage = NSImage(size: newSize)
                    outputImage?.addRepresentation(newRep)
                }

                guard let imageData = outputImage?.tiffRepresentation,
                         let imageRep = NSBitmapImageRep(data: imageData),
                         let resizedData = imageRep.representation(using: .jpeg, properties: [:]) else {
                    print("Failed to resize the image: \(file)")
                    continue
                }

                let resizedImage = NSImage(data: resizedData)

                // Determine compression quality
                let compressionQuality: CGFloat = compress ? CGFloat(self.quality / 100.0) : 1.0
                let fileExtension = URL(fileURLWithPath: file).pathExtension.lowercased()

                var finalImageData: Data?
                if convert {
                    // Convert to WebP with the specified compression quality
                    finalImageData = resizedImage?.sd_imageData(as: .webP, compressionQuality: compressionQuality)
                } else {
                    switch fileExtension {
                    case "jpeg", "jpg":
                        // Convert to JPEG with the specified compression quality
                        finalImageData = resizedImage?.sd_imageData(as: .JPEG, compressionQuality: compressionQuality)
                    case "png":
                        // Convert to PNG
                        finalImageData = resizedImage?.sd_imageData(as: .PNG)
                    case "webp":
                        // Handle WebP
                        finalImageData = resizedImage?.sd_imageData(as: .webP, compressionQuality: compressionQuality)
                    default:
                        print("Unsupported format: \(fileExtension). Skipping...")
                        continue
                    }
                }

                // Determine the destination path
                var finalRelativePath: String
                if isSingleFile {
                    let filename = URL(fileURLWithPath: file).lastPathComponent
                    finalRelativePath = filename
                    if self.rename {
                        let renamedFilename = self.renameFile(URL(fileURLWithPath: finalRelativePath).deletingPathExtension().lastPathComponent)
                        let fileExtension = convert ? "webp" : URL(fileURLWithPath: finalRelativePath).pathExtension
                        finalRelativePath = "\(renamedFilename).\(fileExtension)"
                    } else if convert {
                        finalRelativePath = URL(fileURLWithPath: finalRelativePath).deletingPathExtension().appendingPathExtension("webp").lastPathComponent
                    }
                } else {
                    let relativePath = file.replacingOccurrences(of: self.folderPath, with: "")
                    finalRelativePath = relativePath
                    if self.rename {
                        let renamedFilename = self.renameFile(URL(fileURLWithPath: relativePath).deletingPathExtension().lastPathComponent)
                        let fileExtension = convert ? "webp" : URL(fileURLWithPath: relativePath).pathExtension
                        let folderStructure = URL(fileURLWithPath: relativePath).deletingLastPathComponent().path
                        finalRelativePath = folderStructure + "/" + "\(renamedFilename).\(fileExtension)"
                    } else if convert {
                        finalRelativePath = URL(fileURLWithPath: relativePath).deletingPathExtension().appendingPathExtension("webp").path
                    }
                }

                let destinationURL = URL(fileURLWithPath: self.destinationFolderPath).appendingPathComponent(finalRelativePath)

                // Ensure the directory exists
                let directory = destinationURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

                // Write to file
                try? finalImageData?.write(to: destinationURL)

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
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "webp"]
        
        for case let file as String in enumerator {
            let fileExtension = URL(fileURLWithPath: file).pathExtension.lowercased()
            if imageExtensions.contains(fileExtension) {
                imageFiles.append(directory + "/" + file)
            }
        }
        
        return imageFiles
    }
        
}
