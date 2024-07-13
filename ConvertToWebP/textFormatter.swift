//
//  textFormatter.swift
//  ConvertToWebP
//
//  Created by Matthew Stevens on 7/13/24.
//

import SwiftUI
import Cocoa
import Foundation

struct TextFormatterView: View {
    @State private var textToFormat: String = ""
    @State private var formattedText: String = ""
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Text to format:")
                TextField("Enter text here", text: $textToFormat)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minWidth: 300)
            }
            
            Button("Convert") {
                convertText()
            }
            .padding(.top)
            
            Text("Formatted text:")
                .padding(.top)
            Text(formattedText)
                .foregroundColor(.gray)
                .padding(.bottom)
            
            Button("Copy to Clipboard") {
                copyToClipboard()
            }
            .disabled(formattedText.isEmpty)
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    func convertText() {
        var newText = textToFormat
        newText = newText.replacingOccurrences(of: "[^\\w\\s-]", with: "", options: .regularExpression)
        newText = newText.lowercased()
        newText = newText.replacingOccurrences(of: " ", with: "-")
        newText = newText.replacingOccurrences(of: "[-_]+", with: "-", options: .regularExpression)
        newText = newText.replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
        
        formattedText = newText
        
        if formattedText.isEmpty {
            alertTitle = "Error"
            alertMessage = "Formatted text is empty. Please enter valid text."
            showAlert = true
        }
    }
    
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(formattedText, forType: .string)
        
        alertTitle = "Success"
        alertMessage = "Formatted text copied to clipboard."
        showAlert = true
    }
}
