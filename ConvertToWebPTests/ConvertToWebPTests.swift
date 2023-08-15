//
//  ConvertToWebPApp.swift
//  ConvertToWebP
//
//  Created by Matthew Stevens on 8/15/23.
//

import SwiftUI
import Combine

struct ContentView: View {
    @State private var showImageConverter = true

    var body: some View {
        VStack {
            HStack {
                Button("Converter") {
                    withAnimation {
                        self.showImageConverter = true
                    }
                }
                .disabled(showImageConverter)
                
                Button("File Renamer") {
                    withAnimation {
                        self.showImageConverter = false
                    }
                }
                .disabled(!showImageConverter)
            }
            .padding()
            
            if showImageConverter {
                ImageConverterGUI()
            } else {
                FileRenamerGUI()
            }
        }
        .frame(width: 800, height: 350)
    }
}

struct FileRenamerGUI: View {
    var body: some View {
        // Your File Renamer GUI code here
        Text("File Renamer GUI")
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
