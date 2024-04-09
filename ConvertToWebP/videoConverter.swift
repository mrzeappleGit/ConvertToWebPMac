//
//  videoConverter.swift
//  ConvertToWebP
//
//  Created by Matthew Stevens on 10/12/23.
//

import SwiftUI
import Cocoa
import Foundation

struct VideoConverterView: View {
    @State private var videoFilePath: String = ""
    @State private var destinationFolderPath: String = ""
    @State private var outputFormat: String = "webm"
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var progress: Double = 0.0
    @State private var estimatedTime: Double = 0.0
    @State private var totalTime: Double = 1.0
    @State private var isConverting: Bool = false
    @State private var codec: String = ""

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Video File:")
                TextField("File Path", text: $videoFilePath)
                Button("Select File") {
                    self.videoFilePath = FileSelector.selectFile() ?? ""
                }
            }

            HStack {
                Text("Destination Folder:")
                TextField("Folder Path", text: $destinationFolderPath)
                Button("Select Folder") {
                    self.destinationFolderPath = FileSelector.selectFolder() ?? ""
                }
            }

            Picker(selection: $outputFormat, label: Text("Output Format:")) {
                Text("webm").tag("webm")
                Text("mp4").tag("mp4")
            }

            ProgressBar(value: $progress).frame(height: 20)

            Text("Estimated Time Remaining: \(Int(estimatedTime)) seconds")

            Button("Convert") {
                convertVideo()
            }
            .disabled(isConverting)
        }
        .padding()
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    func convertVideo() {
        isConverting = true
        if videoFilePath.isEmpty || destinationFolderPath.isEmpty {
            alertTitle = "Error"
            alertMessage = "Please select a video file and destination folder."
            showAlert = true
            isConverting = false
            return
        }

        let outputFileName = URL(fileURLWithPath: videoFilePath).deletingPathExtension().lastPathComponent + ".\(outputFormat)"
        let outputFilePath = "\(destinationFolderPath)/\(outputFileName)"
        
        // Extracting the total duration of the video
        // Extracting the total duration of the video
        let durationTask = Process()
        if let ffprobePath = Bundle.main.path(forResource: "ffprobe", ofType: "") {
            durationTask.launchPath = ffprobePath
        }
        durationTask.arguments = ["-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", videoFilePath]
            
        let durationPipe = Pipe()
        durationTask.standardOutput = durationPipe
        durationTask.launch()
        isConverting = true

        if let result = String(data: durationPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8), let duration = Double(result.trimmingCharacters(in: .whitespacesAndNewlines)) {
            self.totalTime = duration
        }

        // Setting up the ffmpeg conversion task
        let task = Process()
        if let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: "") {
            task.launchPath = ffmpegPath
        }
        if outputFormat == "webm" {
            codec = "libvpx"
        } else if outputFormat == "mp4" {
            codec = "hevc_videotoolbox"
        }
        task.arguments = ["-i", videoFilePath, "-c:v", codec, "-b:v", "1M", "-c:a", "libvorbis", outputFilePath]

        let outputPipe = Pipe()
        task.standardError = outputPipe

        let outputHandle = outputPipe.fileHandleForReading
        outputHandle.readabilityHandler = { pipe in
            if let line = String(data: pipe.availableData, encoding: .utf8) {
                if let time = self.extractTime(from: line) {
                    DispatchQueue.main.async {
                        self.progress = time / self.totalTime
                        self.estimatedTime = self.totalTime - time
                    }
                }
            }
        }

        task.terminationHandler = { _ in
            outputHandle.readabilityHandler = nil
            
            DispatchQueue.main.async {
                if task.terminationStatus == 0 {
                    self.alertTitle = "Success"
                    self.alertMessage = "Video converted successfully."
                } else {
                    self.alertTitle = "Error"
                    self.alertMessage = "There was a problem converting the video."
                }
                self.showAlert = true
                isConverting = false
            }
        }

        task.launch()
    }

    func extractTime(from line: String) -> Double? {
        let pattern = "time=([\\d:.]+)"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.utf16.count)) {
            let timeRange = match.range(at: 1)
            let timeString = (line as NSString).substring(with: timeRange)
            let parts = timeString.split(separator: ":").map { Double($0) }
            if parts.count == 3 {
                return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!
            }
        }
        return nil
    }
}

struct ProgressBar: View {
    @Binding var value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .opacity(0.3)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .cornerRadius(10)
                
                Rectangle()
                    .frame(width: CGFloat(self.value) * geometry.size.width, height: geometry.size.height)
                    .foregroundColor(.blue)
                    .cornerRadius(10)
            }
        }
    }
}


struct FileSelector1 {
    static func selectFolder() -> String? {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        if openPanel.runModal() == .OK {
            return openPanel.urls.first?.path
        }
        return nil
    }
    
    static func selectFile() -> String? {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        if openPanel.runModal() == .OK {
            return openPanel.urls.first?.path
        }
        return nil
    }
}
