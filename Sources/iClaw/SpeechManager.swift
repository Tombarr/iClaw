import Foundation
import Speech
import AVFoundation

@MainActor
class SpeechManager: NSObject, ObservableObject {
    static let shared = SpeechManager()
    
    @Published var isRecording = false
    @Published var transcription = ""
    
    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var streamContinuation: AsyncStream<AnalyzerInput>.Continuation?
    
    private var recordingTask: Task<Void, Never>?
    private var resultsTask: Task<Void, Never>?
    
    private override init() {
        super.init()
    }
    
    func startRecording() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            Task { @MainActor in
                if authStatus == .authorized {
                    self.beginRecording()
                } else {
                    self.transcription = "Speech recognition not authorized."
                    self.isRecording = false
                }
            }
        }
    }
    
    private func beginRecording() {
        transcription = "Initializing offline speech model..."
        isRecording = true
        
        recordingTask = Task {
            do {
                let locale = Locale(identifier: "en-US")
                
                // Configure offline SpeechTranscriber
                let transcriber = SpeechTranscriber(
                    locale: locale,
                    transcriptionOptions: [],
                    reportingOptions: [],
                    attributeOptions: []
                )
                
                // Ensure fully offline approach: Check and download required AssetInventory
                if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                    self.transcription = "Downloading offline language model. Please wait..."
                    try await downloader.downloadAndInstall()
                }
                
                let a = SpeechAnalyzer(modules: [transcriber])
                self.analyzer = a
                
                let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
                self.streamContinuation = continuation
                
                // Listen to results asynchronously
                self.resultsTask = Task { @MainActor in
                    var currentText = ""
                    do {
                        for try await result in transcriber.results {
                            let chunk = String(result.text.characters)
                            currentText += chunk
                            self.transcription = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } catch {
                        self.transcription = "Error reading speech: \(error.localizedDescription)"
                        self.isRecording = false
                    }
                }
                
                // Configure AudioEngine
                let inputNode = self.audioEngine.inputNode
                let format = inputNode.outputFormat(forBus: 0)
                
                inputNode.removeTap(onBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                    continuation.yield(AnalyzerInput(buffer: buffer))
                }
                
                self.audioEngine.prepare()
                try self.audioEngine.start()
                
                self.transcription = "Listening..."
                
                // Stream audio into the analyzer
                _ = try await a.analyzeSequence(stream)
                
            } catch {
                self.transcription = "Failed to start: \(error.localizedDescription)"
                self.stopRecording()
            }
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        streamContinuation?.finish()
        streamContinuation = nil
        
        Task {
            if let a = analyzer {
                await a.cancelAndFinishNow()
            }
            analyzer = nil
        }
        
        recordingTask?.cancel()
        resultsTask?.cancel()
        
        isRecording = false
    }
}
