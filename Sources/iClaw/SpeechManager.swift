import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation

/// Accumulates volatile and finalized speech transcription results.
struct TranscriptAccumulator: Sendable {
    private(set) var finalizedTranscript: String = ""
    private(set) var volatileTranscript: String = ""

    var combined: String {
        (finalizedTranscript + volatileTranscript).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func apply(text: String, isFinal: Bool) {
        if isFinal {
            volatileTranscript = ""
            finalizedTranscript += text
        } else {
            volatileTranscript = text
        }
    }
}

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

        recordingTask = Task {
            do {
                let locale = Locale(identifier: "en-US")

                // Configure offline SpeechTranscriber with volatile results enabled
                let transcriber = SpeechTranscriber(
                    locale: locale,
                    transcriptionOptions: [],
                    reportingOptions: [.volatileResults],
                    attributeOptions: []
                )

                // Ensure fully offline approach
                if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                    self.transcription = "Downloading offline language model. Please wait..."
                    try await downloader.downloadAndInstall()
                }

                let a = SpeechAnalyzer(modules: [transcriber])
                self.analyzer = a

                // Get the format SpeechAnalyzer expects
                guard let requiredFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
                    compatibleWith: [transcriber]
                ) else {
                    self.transcription = "No compatible audio format available."
                    self.stopRecording()
                    return
                }

                let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
                self.streamContinuation = continuation

                // Listen to results asynchronously
                self.resultsTask = Task.detached {
                    var accumulator = TranscriptAccumulator()
                    do {
                        for try await result in transcriber.results {
                            accumulator.apply(text: String(result.text.characters), isFinal: result.isFinal)
                            let combined = accumulator.combined

                            await MainActor.run {
                                SpeechManager.shared.transcription = combined
                            }
                        }
                    } catch {
                        await MainActor.run {
                            SpeechManager.shared.transcription = "Error reading speech: \(error.localizedDescription)"
                            SpeechManager.shared.isRecording = false
                        }
                    }
                }

                // Start the analyzer for live input
                try await Task.detached {
                    try await a.start(inputSequence: stream)
                }.value

                // Configure AudioEngine with format conversion
                let inputNode = self.audioEngine.inputNode
                let micFormat = inputNode.outputFormat(forBus: 0)

                inputNode.removeTap(onBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: micFormat) { @Sendable buffer, _ in
                    // Convert mic buffer to the format SpeechAnalyzer expects
                    guard let converter = AVAudioConverter(from: buffer.format, to: requiredFormat) else { return }
                    let frameCount = AVAudioFrameCount(
                        Double(buffer.frameLength) * requiredFormat.sampleRate / buffer.format.sampleRate
                    )
                    guard let converted = AVAudioPCMBuffer(pcmFormat: requiredFormat, frameCapacity: frameCount) else { return }

                    var error: NSError?
                    converter.convert(to: converted, error: &error) { _, status in
                        status.pointee = .haveData
                        return buffer
                    }

                    if error == nil {
                        continuation.yield(AnalyzerInput(buffer: converted))
                    }
                }

                self.audioEngine.prepare()
                try self.audioEngine.start()

                self.transcription = "Listening..."

            } catch {
                if !Task.isCancelled {
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
        analyzer = nil

        Task {
            if let a = localAnalyzer {
                try? await a.finalizeAndFinishThroughEndOfInput()
            }
        }

        recordingTask?.cancel()
        resultsTask?.cancel()

        isRecording = false
    }
}
