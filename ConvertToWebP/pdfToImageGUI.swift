//
//  pdfToImageGUI.swift
//  ConvertToWebP
//
//  Created by Matthew Stevens on 8/21/23.
//

import SwiftUI
import PDFKit
import Foundation
import UniformTypeIdentifiers
import SDWebImageWebPCoder

extension UTType {
    static var webp: UTType {
        return UTType(importedAs: "webp")
    }
}

// Rename from PNGFile to ImageFile for clarity
struct ImageFile: FileDocument {
    var imageData: Data

    // Include .webp type
    static var readableContentTypes: [UTType] { [.png, .webp] }
    
    init(imageData: Data) {
        self.imageData = imageData
    }

    init(configuration: ReadConfiguration) throws {
        self.imageData = Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: imageData)
    }
}

struct pdfToImageView: View {
    @State private var pdfFilePath: URL? = nil
    @State private var pdfFilePathString: String = ""
    @State private var showFilePicker: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showSavePanel: Bool = false
    @State private var fileToExport: ImageFile? = nil  // Change PNGFile to ImageFile

    // Computed property for suggested filename
    var suggestedFilename: String {
        guard let pdfPath = pdfFilePath else { return "thumbnail" }
        let baseFilename = pdfPath.deletingPathExtension().lastPathComponent
        return "\(baseFilename)-thumbnail"
    }

    var body: some View {
        VStack {
            HStack {
                Text("PDF File:")
                TextField("Select a PDF file...", text: $pdfFilePathString)
                    .disabled(true)
                    .frame(width: 200)

                Button("Select PDF") {
                    self.showFilePicker = true
                }
            }

            Button("Convert PDF") {
                convertPDFToWebP()
            }
        }
        .padding()
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url):
                self.pdfFilePath = url
                self.pdfFilePathString = url.absoluteString
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        .fileExporter(isPresented: $showSavePanel, document: fileToExport, contentType: .webp, defaultFilename: suggestedFilename) { result in
            switch result {
            case .success:
                alertMessage = "WebP saved successfully."
                showAlert = true
            case .failure(let error):
                alertMessage = "Error saving the WebP: \(error.localizedDescription)"
                showAlert = true
            }
        }
        .alert(isPresented: $showAlert, content: {
            Alert(title: Text("Notification"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        })
    }

    func convertPDFToWebP() {
        guard let pdfPath = pdfFilePath, pdfPath.pathExtension == "pdf" else {
            alertMessage = "Please select a valid PDF file."
            showAlert = true
            return
        }

        if let pdfDocument = PDFDocument(url: pdfPath), let page = pdfDocument.page(at: 0) {
            let pdfImage = page.thumbnail(of: CGSize(width: page.bounds(for: .mediaBox).size.width, height: page.bounds(for: .mediaBox).size.height), for: .mediaBox)

            if let webpData = webpData(from: pdfImage) {
                fileToExport = ImageFile(imageData: webpData)
                showSavePanel = true
            }
        }
    }

    func webpData(from image: NSImage) -> Data? {
        let coder = SDImageWebPCoder.shared
        return coder.encodedData(with: image, format: .webP, options: nil)
    }
}
