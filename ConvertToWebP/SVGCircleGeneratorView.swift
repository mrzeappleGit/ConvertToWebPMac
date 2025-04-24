import SwiftUI
import Cocoa // Needed for NSImage, NSColor, NSOpenPanel

struct SVGCircleGeneratorView: View {
    // MARK: - State Variables
    @State private var originalImage: NSImage? = nil // Holds the original loaded image
    @State private var displayImage: Image? = nil   // SwiftUI Image view for display
    @State private var imageSize: CGSize = .zero     // Original image dimensions
    @State private var displayScale: CGFloat = 1.0   // Scale factor for display
    @State private var imageContainerSize: CGSize = .zero // Size of the GeometryReader container

    @State private var radiusString: String = "20" // Radius input by user
    @State private var generatedSVGPath: String = ""

    // State for drawing feedback on Canvas
    @State private var centerClickLocation: CGPoint? = nil // Location of click in VIEW coordinates
    @State private var feedbackCircleRadius: CGFloat = 0
    @State private var feedbackContrastColor: Color = .white // Default contrast color
    @State private var isShapeDrawn: Bool = false

    // MARK: - Body
    var body: some View {
        VStack(spacing: 15) {
            // --- Top Controls ---
            HStack {
                Button("Load Image") {
                    loadImage()
                }

                Button("Clear Circle") {
                    clearShapes()
                }
                .disabled(centerClickLocation == nil) // Disable if no circle drawn

                Spacer() // Pushes radius input to the right

                Text("Circle Radius:")
                TextField("", text: $radiusString)
                    .frame(width: 50)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .multilineTextAlignment(.trailing)
                    // Ensure only numbers can be entered (basic validation)
                    .onChange(of: radiusString) { newValue in
                        let filtered = newValue.filter { "0123456789.".contains($0) }
                        // Allow only one decimal point
                        if filtered.filter({ $0 == "." }).count > 1 {
                            radiusString = String(filtered.dropLast())
                        } else {
                            radiusString = filtered
                        }
                    }
            }
            .padding(.horizontal)

            // --- Image Display Area ---
            GeometryReader { geometry in
                ZStack {
                    // Background for the image area (optional)
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

                    if let displayImage = displayImage {
                        displayImage
                            .resizable()
                            .aspectRatio(contentMode: .fit) // Maintain aspect ratio
                            .border(Color.gray.opacity(0.5)) // Optional border
                            .onChange(of: geometry.size) { newSize in
                                // Update container size when geometry changes
                                imageContainerSize = newSize
                                calculateDisplayScale() // Recalculate scale if container resizes
                            }

                        // --- Canvas for Drawing Feedback ---
                        Canvas { context, size in
                            // Draw feedback only if a click has occurred
                            if let center = centerClickLocation {
                                let circlePath = Path(ellipseIn: CGRect(
                                    x: center.x - feedbackCircleRadius,
                                    y: center.y - feedbackCircleRadius,
                                    width: feedbackCircleRadius * 2,
                                    height: feedbackCircleRadius * 2
                                ))

                                // Draw the circle outline with contrast color
                                context.stroke(circlePath, with: .color(feedbackContrastColor), lineWidth: 2)

                                // Draw the center marker (red dot)
                                let markerRadius: CGFloat = 3
                                let markerRect = CGRect(
                                    x: center.x - markerRadius,
                                    y: center.y - markerRadius,
                                    width: markerRadius * 2,
                                    height: markerRadius * 2
                                )
                                context.fill(Path(ellipseIn: markerRect), with: .color(.red))
                            }
                        }
                        // Make canvas same size as geometry reader
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    } else {
                        Text("Load an image to begin")
                            .foregroundColor(.secondary)
                    }
                }
                .onAppear {
                    // Store initial container size
                    imageContainerSize = geometry.size
                    calculateDisplayScale()
                }
                // --- Click Handling ---
                .onTapGesture { location in
                    handleTap(at: location, containerSize: geometry.size)
                }
            }
            .frame(minHeight: 200) // Ensure it has some initial height

            // --- Instructions ---
            Text(isShapeDrawn ? "Circle generated. Click 'Clear Circle' to draw another." : "Click on the image to define the circle's center.")
                .font(.caption)
                .foregroundColor(.secondary)

            // --- SVG Output ---
            VStack(alignment: .leading) {
                Text("Generated SVG Path Data:")
                TextEditor(text: .constant(generatedSVGPath)) // Use constant binding for read-only
                    .frame(height: 60)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.gray.opacity(0.5))
                    .background(Color(.textBackgroundColor)) // Use system background
            }
            .padding(.horizontal)

        }
        .padding(.vertical)
    }

    // MARK: - Image Loading and Scaling
    func loadImage() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image] // Allow common image types
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK {
            guard let url = openPanel.url, let nsImage = NSImage(contentsOf: url) else {
                showError(title: "Load Error", message: "Could not load the selected image.")
                return
            }
            clearShapes() // Clear previous drawing
            originalImage = nsImage
            imageSize = nsImage.size // Store original size
            displayImage = Image(nsImage: nsImage)
            calculateDisplayScale() // Calculate initial scale
        }
    }

    func calculateDisplayScale() {
        guard let img = originalImage, imageContainerSize != .zero, img.size != .zero else {
            displayScale = 1.0
            return
        }

        // Calculate scale based on fitting the image within the container
        let widthScale = imageContainerSize.width / img.size.width
        let heightScale = imageContainerSize.height / img.size.height
        displayScale = min(widthScale, heightScale) // Use the smaller scale to fit entirely
    }

    // MARK: - Click Handling and Drawing
    func handleTap(at location: CGPoint, containerSize: CGSize) {
        guard originalImage != nil else {
            showError(title: "No Image", message: "Please load an image first.")
            return
        }

        // --- 1. Calculate Image Display Rect ---
        // Determine the actual rect the image occupies within the GeometryReader/ZStack
        // based on .aspectRatio(contentMode: .fit)
        guard let imgSize = originalImage?.size, imgSize.width > 0, imgSize.height > 0 else { return }

        let viewAspectRatio = containerSize.width / containerSize.height
        let imageAspectRatio = imgSize.width / imgSize.height

        var displayRectWidth: CGFloat
        var displayRectHeight: CGFloat

        if viewAspectRatio > imageAspectRatio {
            // View is wider than image, height is the constraint
            displayRectHeight = containerSize.height
            displayRectWidth = displayRectHeight * imageAspectRatio
        } else {
            // View is taller than image (or equal aspect), width is the constraint
            displayRectWidth = containerSize.width
            displayRectHeight = displayRectWidth / imageAspectRatio
        }

        // Calculate the origin (top-left corner) of the displayed image within the container
        let displayRectX = (containerSize.width - displayRectWidth) / 2.0
        let displayRectY = (containerSize.height - displayRectHeight) / 2.0
        let imageDisplayRect = CGRect(x: displayRectX, y: displayRectY, width: displayRectWidth, height: displayRectHeight)

        // --- 2. Check if click is within the displayed image bounds ---
        if !imageDisplayRect.contains(location) {
            print("Click outside displayed image bounds.")
            return
        }

        // --- 3. Convert View Coordinates to Original Image Coordinates ---
        // Coordinates relative to the displayed image's top-left corner
        let xInDisplay = location.x - displayRectX
        let yInDisplay = location.y - displayRectY

        // Scale these coordinates back to the original image size
        let originalX = (xInDisplay / displayRectWidth) * imgSize.width
        let originalY = (yInDisplay / displayRectHeight) * imgSize.height

        // --- 4. Validate coordinates against original image size ---
         guard originalX >= 0 && originalX < imgSize.width && originalY >= 0 && originalY < imgSize.height else {
            print("Calculated original coordinates out of bounds.")
            return
        }

        print("Click Location (View): \(location)")
        print("Image Display Rect: \(imageDisplayRect)")
        print("Click Location (Original Image): \(CGPoint(x: originalX, y: originalY))")


        // --- 5. Get Radius ---
        guard let radiusValue = Double(radiusString), radiusValue > 0 else {
            showError(title: "Invalid Radius", message: "Please enter a positive number for the radius.")
            return
        }

        // --- 6. Pixel Color & Contrast (Placeholder) ---
        // *********************************************************************
        // This is where the complex part of getting pixel color would go.
        // It involves using originalImage (NSImage), originalX, originalY,
        // potentially converting to CGImage, creating a bitmap context,
        // drawing the pixel, and reading its color data.
        // let pixelColor = getPixelColor(image: originalImage!, x: Int(originalX), y: Int(originalY))
        // let contrastUIColor = getHighContrastUIColor(from: pixelColor) // Implement this based on luminance
        // feedbackContrastColor = Color(contrastUIColor) // Convert UIColor to SwiftUI Color
        // *********************************************************************
        // For now, we just use the default feedbackContrastColor (.white)

        // --- 7. Update State for Drawing Feedback ---
        centerClickLocation = location // Store the click location in VIEW coordinates for Canvas drawing
        feedbackCircleRadius = CGFloat(radiusValue) * (displayRectWidth / imgSize.width) // Scale radius for display
        isShapeDrawn = true

        // --- 8. Generate SVG Path ---
        generateSVG(center: CGPoint(x: originalX, y: originalY), radius: CGFloat(radiusValue))

    }

    // --- Placeholder for complex pixel color retrieval ---
    // func getPixelColor(image: NSImage, x: Int, y: Int) -> NSColor {
    //     // Implementation requires Core Graphics / AppKit bridging
    //     // 1. Get CGImage representation
    //     // 2. Create 1x1 bitmap context
    //     // 3. Draw the specific pixel into the context
    //     // 4. Read the color data from the context raw bytes
    //     // 5. Convert raw data to NSColor
    //     return NSColor.gray // Placeholder return
    // }
    //
    // --- Placeholder for contrast calculation ---
    // func getHighContrastUIColor(from color: NSColor) -> NSColor {
    //     // 1. Convert NSColor to RGB components
    //     // 2. Calculate luminance (similar to Python version)
    //     // 3. Return NSColor.black or NSColor.white
    //     return NSColor.white // Placeholder return
    // }


    // MARK: - SVG Generation
    func generateSVG(center: CGPoint, radius: CGFloat) {
        let cx = round(center.x * 100) / 100 // Round to 2 decimal places
        let cy = round(center.y * 100) / 100
        let r = round(radius * 100) / 100

        // Format for SVG path (using two arcs for a circle)
        // M cx cy-r a r r 0 1 0 0 2*r a r r 0 1 0 0 -2*r Z
        let startX = cx
        let startY = cy - r
        let dy1 = 2 * r
        let dy2 = -2 * r

        let rStr = String(format: "%.2f", r) // Ensure consistent formatting

        let path = "M\(String(format: "%.2f", startX)) \(String(format: "%.2f", startY))" +
                   "a\(rStr),\(rStr) 0 1 0 0,\(String(format: "%.2f", dy1))" +
                   "a\(rStr),\(rStr) 0 1 0 0,\(String(format: "%.2f", dy2))Z"

        generatedSVGPath = path
    }

    // MARK: - UI Actions
    func clearShapes() {
        centerClickLocation = nil
        feedbackCircleRadius = 0
        generatedSVGPath = ""
        isShapeDrawn = false
        // Keep the loaded image
    }

    // MARK: - Alerts
    func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    func showInfo(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Preview
struct SVGCircleGeneratorView_Previews: PreviewProvider {
    static var previews: some View {
        SVGCircleGeneratorView()
            .frame(width: 600, height: 500) // Provide a frame for preview
    }
}

