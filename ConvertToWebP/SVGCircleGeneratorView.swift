import SwiftUI
import Cocoa // Needed for NSImage, NSColor, NSOpenPanel

// Define the types of shapes the user can draw
enum DrawingMode: String, CaseIterable, Identifiable {
    case circle = "Circle"
    case polygon = "Polygon"
    var id: String { self.rawValue }
}

struct SVGCircleGeneratorView: View { // Renamed view
    // MARK: - State Variables

    // Image Handling
    @State private var originalImage: NSImage? = nil
    @State private var displayImage: Image? = nil
    @State private var imageSize: CGSize = .zero
    @State private var imageContainerSize: CGSize = .zero // Size of the GeometryReader container

    // Drawing Mode
    @State private var currentMode: DrawingMode = .circle

    // Circle Specific State
    @State private var radiusString: String = "20"
    @State private var centerClickLocation: CGPoint? = nil // VIEW coordinates for circle center

    // Polygon Specific State
    @State private var polygonPoints: [CGPoint] = [] // ORIGINAL image coordinates for SVG
    @State private var polygonDisplayPoints: [CGPoint] = [] // VIEW coordinates for Canvas drawing
    @State private var isPolygonClosed: Bool = false // **** NEW: Track if polygon is finished ****

    // Shared State / Output
    @State private var generatedSVGPath: String = ""
    @State private var isShapeDrawn: Bool = false // Tracks if *any* shape element exists

    // Drawing Feedback (used by both)
    @State private var feedbackContrastColor: Color = .yellow // Use a visible default
    @State private var currentDisplayRect: CGRect = .zero // Cache the calculated display rect

    // Constants
    let polygonClosingThreshold: CGFloat = 15.0 // Max distance in VIEW pixels to close polygon

    // MARK: - Body
    var body: some View {
        VStack(spacing: 15) {
            // --- Top Controls ---
            HStack {
                Button("Load Image") {
                    loadImage()
                }

                // Mode Selector
                Picker("Shape Type", selection: $currentMode) {
                    ForEach(DrawingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: currentMode) { _ in
                    clearShapes()
                }

                Button("Clear Shape") {
                    clearShapes()
                }
                .disabled(!isShapeDrawn)

                Spacer()

                // Conditional Radius Input for Circle Mode
                if currentMode == .circle {
                    Text("Circle Radius:")
                    TextField("", text: $radiusString)
                        .frame(width: 50)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .multilineTextAlignment(.trailing)
                        .onChange(of: radiusString) { newValue in
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            if filtered.filter({ $0 == "." }).count > 1 {
                                radiusString = String(filtered.dropLast())
                            } else {
                                radiusString = filtered
                            }
                            if currentMode == .circle, centerClickLocation != nil {
                                updateCircleFeedback()
                            }
                        }
                }
            }
            .padding(.horizontal)

            // --- Image Display Area ---
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

                    if let displayImage = displayImage {
                        displayImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .border(Color.gray.opacity(0.5))
                            .onChange(of: geometry.size) { newSize in
                                imageContainerSize = newSize
                                calculateDisplayMetrics()
                            }
                            .onAppear {
                                imageContainerSize = geometry.size
                                calculateDisplayMetrics()
                            }

                        // --- Canvas for Drawing Feedback ---
                        Canvas { context, size in
                            guard currentDisplayRect != .zero else { return }
                            switch currentMode {
                            case .circle:
                                drawCircleFeedback(context: context, size: size)
                            case .polygon:
                                drawPolygonFeedback(context: context, size: size)
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            // Only handle tap if polygon isn't already closed
                            if currentMode == .polygon && isPolygonClosed {
                                print("Polygon is closed. Clear shape to start a new one.")
                                // Optionally show an alert/info message
                                showInfo(title: "Polygon Closed", message: "The polygon is already closed. Clear the shape to draw a new one.")
                            } else {
                                handleTap(at: location, containerSize: geometry.size)
                            }
                        }

                    } else {
                        Text("Load an image to begin")
                            .foregroundColor(.secondary)
                    }
                }
                .onAppear {
                    imageContainerSize = geometry.size
                    calculateDisplayMetrics()
                }
            }
            .frame(minHeight: 200)

            // --- Instructions ---
            Text(instructionText) // Updated computed property
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            // --- SVG Output ---
            VStack(alignment: .leading) {
                Text("Generated SVG Path Data:")
                TextEditor(text: .constant(generatedSVGPath))
                    .frame(height: 60)
                    .font(.system(.body, design: .monospaced))
                    .border(Color.gray.opacity(0.5))
                    .background(Color(.textBackgroundColor))
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    // MARK: - Computed Properties (for dynamic UI text)
    var instructionText: String {
        if originalImage == nil {
            return "Load an image to begin."
        }
        switch currentMode {
        case .circle:
            return isShapeDrawn ? "Circle generated. Click 'Clear Shape' to draw another." : "Click on the image to define the circle's center."
        case .polygon:
            // **** UPDATED Instructions ****
            if isPolygonClosed {
                return "Polygon closed (\(polygonPoints.count) points). Click 'Clear Shape' to start over."
            } else if polygonPoints.isEmpty {
                return "Click on the image to add the first point of the polygon."
            } else if polygonPoints.count < 3 {
                 return "Click to add more points. Current points: \(polygonPoints.count)."
            } else {
                 return "Click to add more points, or click near the first point (within \(Int(polygonClosingThreshold))px) to close the polygon. Current points: \(polygonPoints.count)."
            }
        }
    }

    // MARK: - Image Loading and Scaling/Positioning
    func loadImage() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.image]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK {
            guard let url = openPanel.url, let nsImage = NSImage(contentsOf: url) else {
                showError(title: "Load Error", message: "Could not load the selected image.")
                return
            }
            clearShapes() // Clear previous drawing before loading new
            originalImage = nsImage
            imageSize = nsImage.size
            displayImage = Image(nsImage: nsImage)
            calculateDisplayMetrics() // Calculate initial display rect
        }
    }

    func calculateDisplayMetrics() {
        guard let imgSize = originalImage?.size, imgSize.width > 0, imgSize.height > 0, imageContainerSize != .zero else {
            currentDisplayRect = .zero
            polygonDisplayPoints = [] // Clear display points if no image/container
            return
        }

        let viewAspectRatio = imageContainerSize.width / imageContainerSize.height
        let imageAspectRatio = imgSize.width / imgSize.height

        var displayRectWidth: CGFloat
        var displayRectHeight: CGFloat

        if viewAspectRatio > imageAspectRatio {
            displayRectHeight = imageContainerSize.height
            displayRectWidth = displayRectHeight * imageAspectRatio
        } else {
            displayRectWidth = imageContainerSize.width
            displayRectHeight = displayRectWidth / imageAspectRatio
        }

        let displayRectX = (imageContainerSize.width - displayRectWidth) / 2.0
        let displayRectY = (imageContainerSize.height - displayRectHeight) / 2.0
        currentDisplayRect = CGRect(x: displayRectX, y: displayRectY, width: displayRectWidth, height: displayRectHeight)

        updatePolygonDisplayPoints()
        updateCircleFeedback()
    }

    // MARK: - Coordinate Conversion
    func viewToOriginalImageCoords(viewPoint: CGPoint) -> CGPoint? {
        guard currentDisplayRect != .zero, let imgSize = originalImage?.size, imgSize.width > 0, imgSize.height > 0 else {
            return nil
        }
        guard currentDisplayRect.contains(viewPoint) else {
             print("Click outside displayed image bounds.")
             return nil
         }
        let xInDisplay = viewPoint.x - currentDisplayRect.origin.x
        let yInDisplay = viewPoint.y - currentDisplayRect.origin.y
        let originalX = (xInDisplay / currentDisplayRect.width) * imgSize.width
        let originalY = (yInDisplay / currentDisplayRect.height) * imgSize.height
        let clampedX = max(0, min(imgSize.width, originalX))
        let clampedY = max(0, min(imgSize.height, originalY))
        return CGPoint(x: clampedX, y: clampedY)
    }

    func originalToViewImageCoords(originalPoint: CGPoint) -> CGPoint? {
         guard currentDisplayRect != .zero, let imgSize = originalImage?.size, imgSize.width > 0, imgSize.height > 0 else {
             return nil
         }
         let xInDisplay = (originalPoint.x / imgSize.width) * currentDisplayRect.width
         let yInDisplay = (originalPoint.y / imgSize.height) * currentDisplayRect.height
         let viewX = xInDisplay + currentDisplayRect.origin.x
         let viewY = yInDisplay + currentDisplayRect.origin.y
         return CGPoint(x: viewX, y: viewY)
     }

    // MARK: - Click Handling
    func handleTap(at location: CGPoint, containerSize: CGSize) {
        // Basic validation (already checked for closed polygon in .onTapGesture)
        guard originalImage != nil else {
            showError(title: "No Image", message: "Please load an image first.")
            return
        }
        if containerSize != imageContainerSize {
             imageContainerSize = containerSize
             calculateDisplayMetrics()
        }
        guard let originalPoint = viewToOriginalImageCoords(viewPoint: location) else {
             return
        }

        print("Click Location (View): \(location)")
        print("Image Display Rect: \(currentDisplayRect)")
        print("Click Location (Original Image): \(originalPoint)")

        // --- Pixel Color & Contrast (Placeholder) ---

        switch currentMode {
        case .circle:
            handleCircleTap(location: location, originalCenter: originalPoint)
        case .polygon:
            handlePolygonTap(location: location, originalPoint: originalPoint)
        }
        // Set isShapeDrawn only if it's not already set OR if the polygon wasn't previously drawn (e.g., after clearing)
        if !isShapeDrawn || (currentMode == .polygon && polygonPoints.count <= 1 && !isPolygonClosed) {
             isShapeDrawn = true // Mark that some shape element now exists or is starting
        }
    }

    func handleCircleTap(location: CGPoint, originalCenter: CGPoint) {
        guard let radiusValue = Double(radiusString), radiusValue > 0 else {
            showError(title: "Invalid Radius", message: "Please enter a positive number for the radius.")
            return
        }
        centerClickLocation = location
        updateCircleFeedback()
        generateCircleSVG(center: originalCenter, radius: CGFloat(radiusValue))
    }

    func handlePolygonTap(location: CGPoint, originalPoint: CGPoint) {
         // **** Check for Closing Click ****
         // Condition: At least 3 points exist (start + 2 others), and click is near the first point.
         if polygonDisplayPoints.count >= 3, let firstDisplayPoint = polygonDisplayPoints.first {
             let dx = location.x - firstDisplayPoint.x
             let dy = location.y - firstDisplayPoint.y
             let distance = sqrt(dx*dx + dy*dy)

             if distance < polygonClosingThreshold {
                 isPolygonClosed = true
                 print("Polygon closed by clicking near start.")
                 // SVG already includes 'Z' based on point count > 1,
                 // so no need to regenerate specifically, but doesn't hurt.
                 generatePolygonSVG()
                 // Do not add the closing click as a new point
                 return
             }
         }

         // If not closing, add the point
         polygonPoints.append(originalPoint)
         polygonDisplayPoints.append(location) // Use the actual click location for display list
         generatePolygonSVG() // Update SVG with the new point
     }

    // MARK: - Drawing Feedback (Canvas)
    func updateCircleFeedback() {
         guard centerClickLocation != nil,
               currentDisplayRect != .zero,
               let imgSize = originalImage?.size, imgSize.width > 0,
               let radiusValue = Double(radiusString), radiusValue > 0
         else { return }
         // Trigger redraw via state change (implicitly via handleTap/radiusString change)
    }

    func drawCircleFeedback(context: GraphicsContext, size: CGSize) {
        guard let center = centerClickLocation,
              let radiusValue = Double(radiusString), radiusValue > 0,
              let imgSize = originalImage?.size, imgSize.width > 0,
              currentDisplayRect != .zero
        else { return }
        let displayRadius = CGFloat(radiusValue) * (currentDisplayRect.width / imgSize.width)
        let circlePath = Path(ellipseIn: CGRect(
            x: center.x - displayRadius,
            y: center.y - displayRadius,
            width: displayRadius * 2,
            height: displayRadius * 2
        ))
        context.stroke(circlePath, with: .color(feedbackContrastColor), lineWidth: 2)
        let markerRadius: CGFloat = 3
        let markerRect = CGRect(
            x: center.x - markerRadius,
            y: center.y - markerRadius,
            width: markerRadius * 2,
            height: markerRadius * 2
        )
        context.fill(Path(ellipseIn: markerRect), with: .color(.red))
    }

     func updatePolygonDisplayPoints() {
         guard currentDisplayRect != .zero else {
             polygonDisplayPoints = []
             return
         }
         polygonDisplayPoints = polygonPoints.compactMap { originalPoint in
             originalToViewImageCoords(originalPoint: originalPoint)
         }
     }

    func drawPolygonFeedback(context: GraphicsContext, size: CGSize) {
        guard !polygonDisplayPoints.isEmpty else { return }
        let markerRadius: CGFloat = 3
        for (index, point) in polygonDisplayPoints.enumerated() {
            let markerRect = CGRect(
                x: point.x - markerRadius,
                y: point.y - markerRadius,
                width: markerRadius * 2,
                height: markerRadius * 2
            )
            // Optionally make the first point slightly different
             context.fill(Path(ellipseIn: markerRect), with: .color(index == 0 ? .blue : .red))
             context.fill(Path(ellipseIn: markerRect), with: .color(.red))
        }

        if polygonDisplayPoints.count > 1 {
            var path = Path()
            path.move(to: polygonDisplayPoints[0])
            for i in 1..<polygonDisplayPoints.count {
                path.addLine(to: polygonDisplayPoints[i])
            }
            // If closed, also draw the final closing line explicitly for feedback
            // The SVG Z command handles the actual path data closing.
            if isPolygonClosed && polygonDisplayPoints.count > 1 {
                 path.closeSubpath() // Explicitly close for canvas stroke
            }
            context.stroke(path, with: .color(feedbackContrastColor), lineWidth: 2)
        }
    }

    func generateCircleSVG(center: CGPoint, radius: CGFloat) {
        let cx = round(center.x * 100) / 100
        let cy = round(center.y * 100) / 100
        let r = round(radius * 100) / 100
        let startX = cx
        let startY = cy - r
        let dy1 = 2 * r
        let dy2 = -2 * r
        let rStr = String(format: "%.2f", r)
        let path = "M\(String(format: "%.2f", startX)) \(String(format: "%.2f", startY)) " +
                   "a\(rStr),\(rStr) 0 1 0 0,\(String(format: "%.2f", dy1)) " +
                   "a\(rStr),\(rStr) 0 1 0 0,\(String(format: "%.2f", dy2))Z"
        generatedSVGPath = path
    }

    func generatePolygonSVG() {
        guard !polygonPoints.isEmpty else {
            generatedSVGPath = ""
            return
        }
        let pathData = polygonPoints.enumerated().map { (index, point) -> String in
            let prefix = (index == 0) ? "M" : "L"
            let px = round(point.x * 100) / 100
            let py = round(point.y * 100) / 100
            return "\(prefix)\(String(format: "%.2f", px)) \(String(format: "%.2f", py))"
        }.joined(separator: " ")
        // Add 'Z' to close the path if there are enough points to form a shape (implicitly closed by SVG viewers)
        // We only add Z if it's meant to be a closed shape (more than 2 points)
        let finalPath = polygonPoints.count > 2 ? (pathData + " Z") : pathData
        generatedSVGPath = finalPath
    }

    // MARK: - UI Actions
    func clearShapes() {
        centerClickLocation = nil
        polygonPoints = []
        polygonDisplayPoints = []
        isPolygonClosed = false
        generatedSVGPath = ""
        isShapeDrawn = false
    }

    // MARK: - Alerts
    // ... (showError, showInfo remain the same) ...
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
struct SVGShapeGeneratorView_Previews: PreviewProvider {
    static var previews: some View {
        SVGCircleGeneratorView()
            .frame(width: 600, height: 500)
    }
}
