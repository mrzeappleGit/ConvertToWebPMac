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
    // MARK: - State Variables

    // Path to the source image or folder
    @State private var folderPath: String = ""
    // Path to the destination folder
    @State private var destinationFolderPath: String = ""
    // Compression quality for the output image
    @State private var quality: Double = 100.0
    // Percentage to resize the image width
    @State private var newWidthPercentage: Double = 100.0
    // Toggle for compressing the image
    @State private var compress: Bool = false
    // Toggle for renaming the file
    @State private var rename: Bool = false
    // Toggle for converting the image to WebP format
    @State private var convert: Bool = false
    // Progress of the conversion process
    @State private var progress: Double = 0.0
    // Toggle for resizing the image
    @State private var resize: Bool = false
    // Holds the original selected image for preview
    @State private var selectedImage: NSImage?
    // Holds the processed image for preview
    @State private var processedImage: NSImage?
    // Controls the visibility of the image zoom window
    @State private var showZoomView = false

    // MARK: - Main Body

    var body: some View {
        HStack {
            // MARK: - Controls
            VStack(alignment: .leading) {
                // Input path selection
                HStack {
                    Text("Image/Folder:")
                    TextField("Select an image or folder", text: $folderPath)
                        .border(Color.gray, width: 1)
                    // Button to select a folder
                    Button("Select Folder") {
                        selectFolder()
                    }
                    // Button to select a single file
                    Button("Select File") {
                        selectFile()
                    }
                }

                // Destination path selection
                HStack {
                    Text("Destination Folder:")
                    TextField("Select a destination", text: $destinationFolderPath)
                        .border(Color.gray, width: 1)
                    // Button to select a destination folder
                    Button("Select Folder") {
                        selectDestinationFolder()
                    }
                }

                // Toggles for image operations
                HStack {
                    Toggle(isOn: $compress) {
                        Text("Compress")
                    }
                    .onChange(of: compress) { _ in updatePreview() }
                    Toggle(isOn: $rename) {
                        Text("Rename")
                    }
                    Toggle(isOn: $convert) {
                        Text("Convert")
                    }
                    .onChange(of: convert) { _ in updatePreview() }
                    Toggle(isOn: $resize) {
                        Text("Resize")
                    }
                    .onChange(of: resize) { _ in updatePreview() }
                }

                // Quality slider and text field
                HStack {
                    Text("Quality:")
                    Slider(value: $quality, in: 0...100, onEditingChanged: { editing in
                        if !editing {
                            updatePreview()
                        }
                    })
                    .disabled(!compress)
                    TextField("", value: $quality, formatter: NumberFormatter(), onCommit: {
                        self.quality = min(max(self.quality, 0), 100)
                        updatePreview()
                    })
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(!compress)
                    Text("%")
                }

                // Resize width slider and text field
                HStack {
                    Text("Resize Width (%):")
                    Slider(value: $newWidthPercentage, in: 1...100, onEditingChanged: { editing in
                        if !editing {
                            updatePreview()
                        }
                    })
                    .disabled(!resize)
                    TextField("", value: $newWidthPercentage, formatter: NumberFormatter(), onCommit: {
                        self.newWidthPercentage = min(max(self.newWidthPercentage, 1), 100)
                        updatePreview()
                    })
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(!resize)
                    Text("%")
                }
                
                // Run button to start the conversion
                Button("Run") {
                    convertImages()
                }
                
                // Progress bar for the conversion process
                ProgressView(value: progress, total: 100)
            }
            .padding()

            // MARK: - Image Preview
            VStack {
                // Display the processed image if available, otherwise show the original selected image
                let imageToDisplay = processedImage ?? selectedImage
                
                if let image = imageToDisplay {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .onTapGesture {
                            self.showZoomView.toggle()
                        }
                        .sheet(isPresented: $showZoomView) {
                            ImageZoomView(image: image)
                        }
                } else {
                    Text("No Image Selected")
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 300, height: 300)
            .padding()
        }
    }

    // MARK: - File/Folder Selection
    
    /// Opens a panel to select a source folder.
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.urls.first {
            folderPath = url.path
            selectedImage = nil
            updatePreview()
        }
    }
    
    /// Opens a panel to select a single source file and updates the preview.
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.urls.first {
            folderPath = url.path
            selectedImage = NSImage(contentsOf: url)
            updatePreview()
        }
    }
    
    /// Opens a panel to select the destination folder.
    private func selectDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.urls.first {
            destinationFolderPath = url.path
        }
    }

    // MARK: - Live Preview

    /// Updates the image preview based on the current settings.
    private func updatePreview() {
        // Ensure there's a source image to process.
        guard let inputImage = selectedImage else {
            processedImage = nil
            return
        }

        // Run processing on a background thread to keep the UI responsive.
        DispatchQueue.global(qos: .userInitiated).async {
            var imageToProcess: NSImage = inputImage

            // Apply resizing if the toggle is on.
            if self.resize {
                let scaleFactor = CGFloat(self.newWidthPercentage / 100.0)
                let newSize = CGSize(width: inputImage.size.width * scaleFactor, height: inputImage.size.height * scaleFactor)
                imageToProcess = self.resizeImage(image: inputImage, to: newSize)
            }

            // Get the final image data based on compression and conversion settings.
            // The original folderPath is used to get the source file extension if not converting.
            guard let finalImageData = self.getImageData(for: imageToProcess, from: self.folderPath) else {
                return
            }
            
            // Create the final preview image from the processed data.
            let finalPreviewImage = NSImage(data: finalImageData)

            // Update the UI on the main thread.
            DispatchQueue.main.async {
                self.processedImage = finalPreviewImage
            }
        }
    }
    
    // MARK: - Image Conversion Logic
    
    /// Converts images based on the selected options and saves them.
    func convertImages() {
        var imageFiles: [String] = []
        var isDirectory: ObjCBool = false
        
        // Check if the path is a directory or a single file
        if FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                imageFiles = fetchImageFiles(from: folderPath)
            } else {
                imageFiles = [folderPath]
            }
        } else {
            print("Source path is not valid.")
            return
        }
        
        let totalImages = imageFiles.count
        guard totalImages > 0 else { return }
        var processedCount = 0
        let isSingleFile = !isDirectory.boolValue
        
        // Process images on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            for file in imageFiles {
                guard let inputImage = NSImage(contentsOfFile: file) else {
                    print("Failed to load image from: \(file)")
                    continue
                }
                
                // Resize the image if enabled
                var outputImage: NSImage? = inputImage
                if self.resize {
                    let scaleFactor = CGFloat(self.newWidthPercentage / 100.0)
                    let newSize = CGSize(width: inputImage.size.width * scaleFactor, height: inputImage.size.height * scaleFactor)
                    outputImage = resizeImage(image: inputImage, to: newSize)
                }
                
                guard let finalImage = outputImage,
                      let finalImageData = getImageData(for: finalImage, from: file) else {
                    print("Failed to process image: \(file)")
                    continue
                }

                // Determine destination path and save the file
                let destinationURL = getDestinationURL(for: file, isSingleFile: isSingleFile)
                saveImageData(finalImageData, to: destinationURL)
                
                processedCount += 1
                let progressValue = Double(processedCount) / Double(totalImages) * 100.0
                
                // Update progress on the main thread
                DispatchQueue.main.async {
                    self.progress = progressValue
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    /// Resizes an NSImage to the specified size.
    /// - Parameters:
    ///   - image: The image to resize.
    ///   - size: The new size for the image.
    /// - Returns: A new resized NSImage.
    private func resizeImage(image: NSImage, to size: CGSize) -> NSImage {
        let newRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: newRep)
        image.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        
        let newImage = NSImage(size: size)
        newImage.addRepresentation(newRep)
        return newImage
    }
    
    /// Gets the image data based on selected format and quality.
    /// - Parameters:
    ///   - image: The input NSImage.
    ///   - originalPath: The path of the original image file.
    /// - Returns: The processed image data.
    private func getImageData(for image: NSImage, from originalPath: String) -> Data? {
        let compressionQuality: CGFloat = compress ? CGFloat(quality / 100.0) : 1.0
        let fileExtension = URL(fileURLWithPath: originalPath).pathExtension.lowercased()
        
        if convert {
            return image.sd_imageData(as: .webP, compressionQuality: compressionQuality)
        } else {
            switch fileExtension {
            case "jpeg", "jpg":
                return image.sd_imageData(as: .JPEG, compressionQuality: compressionQuality)
            case "png":
                return image.sd_imageData(as: .PNG)
            case "webp":
                return image.sd_imageData(as: .webP, compressionQuality: compressionQuality)
            default:
                // If we don't have a valid extension (e.g., from folder selection), default to JPEG.
                return image.sd_imageData(as: .JPEG, compressionQuality: compressionQuality)
            }
        }
    }
    
    /// Determines the destination URL for the processed image.
    /// - Parameters:
    ///   - originalPath: The path of the original image file.
    ///   - isSingleFile: A boolean indicating if the source is a single file.
    /// - Returns: The URL for the destination file.
    private func getDestinationURL(for originalPath: String, isSingleFile: Bool) -> URL {
        var finalRelativePath: String
        
        if isSingleFile {
            let filename = URL(fileURLWithPath: originalPath).lastPathComponent
            finalRelativePath = filename
            if rename {
                let renamedFilename = renameFile(URL(fileURLWithPath: finalRelativePath).deletingPathExtension().lastPathComponent)
                let fileExtension = convert ? "webp" : URL(fileURLWithPath: finalRelativePath).pathExtension
                finalRelativePath = "\(renamedFilename).\(fileExtension)"
            } else if convert {
                finalRelativePath = URL(fileURLWithPath: finalRelativePath).deletingPathExtension().appendingPathExtension("webp").lastPathComponent
            }
        } else {
            let relativePath = originalPath.replacingOccurrences(of: folderPath, with: "")
            finalRelativePath = relativePath
            if rename {
                let renamedFilename = renameFile(URL(fileURLWithPath: relativePath).deletingPathExtension().lastPathComponent)
                let fileExtension = convert ? "webp" : URL(fileURLWithPath: relativePath).pathExtension
                let folderStructure = URL(fileURLWithPath: relativePath).deletingLastPathComponent().path
                finalRelativePath = folderStructure + "/" + "\(renamedFilename).\(fileExtension)"
            } else if convert {
                finalRelativePath = URL(fileURLWithPath: relativePath).deletingPathExtension().appendingPathExtension("webp").path
            }
        }
        
        return URL(fileURLWithPath: destinationFolderPath).appendingPathComponent(finalRelativePath)
    }

    /// Saves the image data to the specified URL.
    /// - Parameters:
    ///   - data: The image data to save.
    ///   - url: The destination file URL.
    private func saveImageData(_ data: Data, to url: URL) {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        try? data.write(to: url)
    }

    /// Renames a file according to a set of rules.
    /// - Parameter filename: The original filename.
    /// - Returns: The sanitized and renamed filename.
    func renameFile(_ filename: String) -> String {
        var newName = filename
        // Remove special characters, convert to lowercase, and replace spaces with hyphens
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        newName = newName.components(separatedBy: allowedCharacters.inverted).joined()
        newName = newName.lowercased()
        newName = newName.replacingOccurrences(of: " ", with: "-")
        newName = newName.replacingOccurrences(of: "_", with: "")
        newName = newName.replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
        newName = newName.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return newName
    }
    
    /// Fetches all image files from a directory recursively.
    /// - Parameter directory: The directory to search for images.
    /// - Returns: An array of strings representing the paths to the image files.
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

// MARK: - Image Zoom View

/// A view that displays an image and allows zooming and panning.
struct ImageZoomView: View {
    // Environment variable to control the presentation state (e.g., dismissing the sheet).
    @Environment(\.presentationMode) var presentationMode
    var image: NSImage

    // Enum to define the active tool
    enum Tool {
        case pan, zoom
    }

    // State for the selected tool
    @State private var selectedTool: Tool = .pan

    // State for zoom
    @State private var scale: CGFloat = 1.0
    
    // State for pan
    @State private var offset: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Toolbar
            HStack(spacing: 16) {
                // Pan Tool Button
                Button(action: { selectedTool = .pan }) {
                    Image(systemName: "hand.draw.fill")
                        .font(.title2)
                }
                .buttonStyle(ToolButtonStyle(isSelected: selectedTool == .pan))
                .keyboardShortcut(" ", modifiers: [])


                // Zoom Tool Button
                Button(action: { selectedTool = .zoom }) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.title2)
                }
                .buttonStyle(ToolButtonStyle(isSelected: selectedTool == .zoom))
                .keyboardShortcut("z", modifiers: [])
                
                Spacer() // Pushes the close button to the far right.

                // Close Button
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            // MARK: - Image Container
            ZoomableImageView(image: image,
                              scale: $scale,
                              offset: $offset,
                              selectedTool: $selectedTool)
        }
        .background(Color.black.opacity(0.2))
        .frame(minWidth: 400, minHeight: 450)
    }
}


// Custom button style for the toolbar
struct ToolButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .foregroundColor(isSelected ? .accentColor : .primary)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Zoomable Image View

/// A view that wraps a custom NSView to handle gestures and events correctly.
struct ZoomableImageView: NSViewRepresentable {
    var image: NSImage
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @Binding var selectedTool: ImageZoomView.Tool

    func makeNSView(context: Context) -> CustomImageView {
        let view = CustomImageView(image: image)
        view.coordinator = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: CustomImageView, context: Context) {
        // Pass the coordinator to the view for updates.
        nsView.coordinator = context.coordinator
        // Trigger a layout pass to apply the latest scale and offset.
        DispatchQueue.main.async {
            nsView.needsLayout = true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: ZoomableImageView
        var lastPanLocation: NSPoint?

        init(_ parent: ZoomableImageView) {
            self.parent = parent
        }

        @objc func panGesture(_ recognizer: NSPanGestureRecognizer) {
            guard parent.selectedTool == .pan, let view = recognizer.view else { return }
            
            let location = recognizer.location(in: view.superview)
            
            if recognizer.state == .began {
                lastPanLocation = location
            }
            
            if let lastLocation = lastPanLocation {
                let deltaX = location.x - lastLocation.x
                let deltaY = location.y - lastLocation.y
                
                // Use a temporary variable for the new offset
                var newOffset = parent.offset
                newOffset.width += deltaX
                newOffset.height -= deltaY // AppKit's Y is flipped from SwiftUI
                parent.offset = newOffset
            }
            
            lastPanLocation = location
            
            if recognizer.state == .ended || recognizer.state == .cancelled {
                lastPanLocation = nil
            }
        }
        
        @objc func magnificationGesture(_ recognizer: NSMagnificationGestureRecognizer) {
            guard parent.selectedTool == .zoom else { return }

            let newScale = parent.scale * recognizer.magnification
            parent.scale = max(0.5, min(newScale, 10.0)) // Clamp scale
            recognizer.magnification = 1.0 // Reset for next event
        }

        @objc func scrollWheel(with event: NSEvent) {
            guard parent.selectedTool == .zoom else { return }
            
            let sensitivity: CGFloat = 0.1
            let delta = event.scrollingDeltaY
            let newScale = parent.scale + (delta * sensitivity)
            parent.scale = max(0.5, min(newScale, 10.0))
        }
    }
}

// MARK: - Custom NSView for Gestures

/// The custom NSView that hosts the image and its gesture recognizers.
class CustomImageView: NSView {
    private var imageView: NSImageView
    var coordinator: ZoomableImageView.Coordinator?

    init(image: NSImage) {
        self.imageView = NSImageView(image: image)
        super.init(frame: .zero)

        wantsLayer = true
        layer?.masksToBounds = true

        imageView.imageScaling = .scaleProportionallyDown
        addSubview(imageView)

        let pan = NSPanGestureRecognizer(target: self, action: #selector(panGesture))
        addGestureRecognizer(pan)
        
        let magnification = NSMagnificationGestureRecognizer(target: self, action: #selector(magnificationGesture))
        addGestureRecognizer(magnification)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func scrollWheel(with event: NSEvent) {
        coordinator?.scrollWheel(with: event)
    }

    @objc private func panGesture(_ recognizer: NSPanGestureRecognizer) {
        coordinator?.panGesture(recognizer)
    }
    
    @objc private func magnificationGesture(_ recognizer: NSMagnificationGestureRecognizer) {
        coordinator?.magnificationGesture(recognizer)
    }
    
    // update is now replaced by direct manipulation in layout
    override func layout() {
        super.layout()
        
        guard let imageSize = imageView.image?.size else { return }
        
        // Calculate the aspect ratio to fit the image inside the view bounds
        let viewSize = self.bounds.size
        let imageAspectRatio = imageSize.width / imageSize.height
        let viewAspectRatio = viewSize.width / viewSize.height
        
        var renderSize = viewSize
        if imageAspectRatio > viewAspectRatio {
            renderSize.height = viewSize.width / imageAspectRatio
        } else {
            renderSize.width = viewSize.height * imageAspectRatio
        }

        // Apply the zoom scale
        let scaledSize = NSSize(width: renderSize.width * (coordinator?.parent.scale ?? 1.0),
                                height: renderSize.height * (coordinator?.parent.scale ?? 1.0))
        
        // Apply the pan offset
        let newOrigin = NSPoint(x: (viewSize.width - scaledSize.width) / 2 + (coordinator?.parent.offset.width ?? 0),
                                y: (viewSize.height - scaledSize.height) / 2 - (coordinator?.parent.offset.height ?? 0))
        
        imageView.frame = NSRect(origin: newOrigin, size: scaledSize)
    }
}
