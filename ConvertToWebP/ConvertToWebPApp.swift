import SwiftUI
import Combine // Keep if used by other views

// Assume other view files (ImageConverterGUI.swift, pdfToImageView.swift, etc.) exist
// and contain their respective SwiftUI Views.

struct ContentView: View {
    // Add the new view type to the enum
    enum ActiveView {
        case converter, fileRenamer, pdfToImage, videoConverter, textFormatter, svgCircleGenerator // Added svgCircleGenerator
    }

    @State private var activeView: ActiveView = .converter

    var body: some View {
        VStack(spacing: 0) { // Reduced spacing for tighter layout
            // --- Top Button Bar ---
            HStack {
                // Use a helper function or loop for less repetition if many buttons
                AppButton(title: "Converter", currentView: $activeView, targetView: .converter)
                AppButton(title: "File Renamer", currentView: $activeView, targetView: .fileRenamer)
                AppButton(title: "PDF to Image", currentView: $activeView, targetView: .pdfToImage)
                AppButton(title: "Video Converter", currentView: $activeView, targetView: .videoConverter)
                AppButton(title: "Text Formatter", currentView: $activeView, targetView: .textFormatter)
                AppButton(title: "SVG Overlay Gen", currentView: $activeView, targetView: .svgCircleGenerator)

                Spacer() // Pushes buttons to the left
            }
            .padding(.horizontal)
            .padding(.top, 10) // Add padding top
            .padding(.bottom, 5) // Reduce padding bottom
            .background(Color(.windowBackgroundColor).opacity(0.8)) // Subtle background

            Divider() // Separator

            // --- Content Area ---
            VStack { // Add VStack to contain the switched view
                switch activeView {
                case .converter:
                    ImageConverterGUI() // Assuming you have this SwiftUI view
                        .transition(.opacity) // Add transition
                case .fileRenamer:
                    FileRenamerView() // From your uploaded code
                        .transition(.opacity)
                case .pdfToImage:
                     // Replace with your actual PDF view if different
                    Text("PDF to Image View Placeholder")
                        .transition(.opacity)
//                  pdfToImageView()
                case .videoConverter:
                     // Replace with your actual Video view if different
                    Text("Video Converter View Placeholder")
                        .transition(.opacity)
//                  VideoConverterView()
                case .textFormatter:
                     // Replace with your actual Text view if different
                    Text("Text Formatter View Placeholder")
                        .transition(.opacity)
//                  TextFormatterView()

                // Add the case for the new view
                case .svgCircleGenerator:
                    SVGCircleGeneratorView() // The new view we created
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Allow content to expand

        }
        // Set a reasonable default window size
        .frame(minWidth: 700, minHeight: 500)
    }
}

// Helper struct for consistent button styling and action
struct AppButton: View {
    let title: String
    @Binding var currentView: ContentView.ActiveView
    let targetView: ContentView.ActiveView

    var body: some View {
        Button(title) {
            withAnimation(.easeInOut(duration: 0.2)) { // Add animation
                currentView = targetView
            }
        }
        .buttonStyle(.bordered) // Use a standard button style
        .disabled(currentView == targetView)
    }
}


@main
struct MainApp: App {
    // Keep your AppDelegate if it contains necessary setup
    // @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Add standard macOS menu commands if needed (About, Quit, etc.)
        .commands {
            CommandGroup(replacing: .appInfo) {
                 Button("About ConvertToWebP") {
                     // Show your custom About box or the standard one
                     NSApplication.shared.orderFrontStandardAboutPanel(
                         options: [
                            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(string: "Credits..."),
                             NSApplication.AboutPanelOptionKey.applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
                         ]
                     )
                 }
             }
        }
    }
}

// --- AppDelegate (Optional, keep if needed for lifecycle events) ---
// class AppDelegate: NSObject, NSApplicationDelegate {
//     func applicationDidFinishLaunching(_ notification: Notification) {
//         // Perform setup tasks
//         print("App finished launching")
//     }
//
//     func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
//         // Keep app running even if main window is closed (macOS standard behavior)
//         return true
//     }
// }
