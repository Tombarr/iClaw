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
        self.beginRecording()
    }
    
    private func beginRecording() {
        transcription = "Initializing offline speech model..."
        isRecording = true
        
        // The class itself is marked @MainActor, so tasks created here inherit it.
        // We explicitly make a non-isolated task for the heavy processing.
        recordingTask = Task.detached {
            do {
                let locale = Locale(identifier: "en-US")
                
                // Configure offline SpeechTranscriber with volatile results enabled
                let transcriber = SpeechTranscriber(
                    locale: locale,
                    transcriptionOptions: [],
                    reportingOptions: [.volatileResults],
                    attributeOptions: []
                )
                
                // Ensure fully offline approach: Check and download required AssetInventory
                if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                    await MainActor.run {
                        self.transcription = "Downloading offline language model. Please wait..."
                    }
                    try await downloader.downloadAndInstall()
                }
                
                let a = SpeechAnalyzer(modules: [transcriber])
                await MainActor.run {
                    self.analyzer = a
                }
                
                let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
                await MainActor.run {
                    self.streamContinuation = continuation
                }
                
                // Listen to results asynchronously
                await MainActor.run {
                    self.resultsTask = Task { @MainActor in
                        var finalizedTranscript = ""
                        var volatileTranscript = ""
                        do {
                            for try await result in transcriber.results {
                                if result.isFinal {
                                    volatileTranscript = ""
                                    finalizedTranscript += String(result.text.characters)
                                } else {
                                    volatileTranscript = String(result.text.characters)
                                }
                                self.transcription = (finalizedTranscript + volatileTranscript).trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        } catch {
                            self.transcription = "Error reading speech: \(error.localizedDescription)"
                            self.isRecording = false
                        }
                    }
                }
                
                // Configure AudioEngine must happen on MainActor
                try await MainActor.run {
                    let inputNode = self.audioEngine.inputNode
                    let format = inputNode.outputFormat(forBus: 0)
                    
                    inputNode.removeTap(onBus: 0)
                    
                    // AVAudioEngine's tap block is called on a background thread.
                    // We must not capture the continuation in a way that violates isolation,
                    // but the continuation itself is Sendable.
                    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                        continuation.yield(AnalyzerInput(buffer: buffer))
                    }
                    
                    self.audioEngine.prepare()
                    try self.audioEngine.start()
                    
                    self.transcription = "Listening..."
                }
                
                // Stream audio into the analyzer
                _ = try await a.analyzeSequence(stream)
                
            } catch {
                await MainActor.run {
                    self.transcription = "Failed to start: \(error.localizedDescription)"
                    self.stopRecording()
                }
            }
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        streamContinuation?.finish()
        streamContinuation = nil
        
        let localAnalyzer = analyzer
        Task {
            if let a = localAnalyzer {
                await a.cancelAndFinishNow()
            }
        }
        analyzer = nil
        
        recordingTask?.cancel()
        resultsTask?.cancel()
        
        isRecording = false
    }
}
