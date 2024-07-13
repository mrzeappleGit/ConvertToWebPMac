//
//  ConvertToWebPApp.swift
//  ConvertToWebP
//
//  Created by Matthew Stevens on 8/15/23.
//

import SwiftUI
import Combine

struct ContentView: View {
    enum ActiveView {
        case converter, fileRenamer, pdfToImage, videoConverter, textFormatter
    }

    @State private var activeView: ActiveView = .converter

    var body: some View {
        VStack {
            HStack {
                Button("Converter") {
                    withAnimation {
                        self.activeView = .converter
                    }
                }
                .disabled(activeView == .converter)

                Button("File Renamer") {
                    withAnimation {
                        self.activeView = .fileRenamer
                    }
                }
                .disabled(activeView == .fileRenamer)
                
                Button("PDF to Image") {
                    withAnimation {
                        self.activeView = .pdfToImage
                    }
                }
                .disabled(activeView == .pdfToImage)
                
                Button("Video Converter") {
                    withAnimation {
                        self.activeView = .videoConverter
                    }
                }
                .disabled(activeView == .videoConverter)
                
                Button("Text Formatter"){
                    withAnimation {
                        self.activeView = .textFormatter
                    }
                }
                .disabled(activeView == .textFormatter)
                
            }
            .padding()
            
            switch activeView {
            case .converter:
                ImageConverterGUI()  // Assuming you have this SwiftUI view in your project
            case .fileRenamer:
                FileRenamerView()  // Placeholder for your file renamer functionality
            case .pdfToImage:
                pdfToImageView()  // Using the SwiftUI view for PDF-to-Image conversion
            case .videoConverter:
                VideoConverterView()
            case .textFormatter:
                TextFormatterView()
            }
        }
        .frame(width: 800, height: 350)
    }
}

@main
struct MainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
