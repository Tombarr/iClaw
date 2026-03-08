import Foundation
import AVFoundation
import Combine

@MainActor
class PodcastPlayerManager: ObservableObject {
    static let shared = PodcastPlayerManager()

    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var episodeTitle: String = ""
    @Published var showName: String = ""
    @Published var isActive = false

    private var player: AVPlayer?
    private var timeObserver: Any?

    private init() {}

    func play(url: URL, title: String, show: String) {
        stop()

        episodeTitle = title
        showName = show
        isActive = true

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)

        // Observe duration once the item is ready
        Task {
            // Wait for the item to load its duration
            if let dur = try? await item.asset.load(.duration) {
                let seconds = CMTimeGetSeconds(dur)
                if seconds.isFinite && seconds > 0 {
                    self.duration = seconds
                }
            }
        }

        // Periodic time observer for progress
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                let seconds = CMTimeGetSeconds(time)
                if seconds.isFinite {
                    self.currentTime = seconds
                }
                // Update duration if it wasn't available initially
                if self.duration <= 0, let item = self.player?.currentItem {
                    let dur = CMTimeGetSeconds(item.duration)
                    if dur.isFinite && dur > 0 {
                        self.duration = dur
                    }
                }
            }
        }

        // Observe when playback ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }

        player?.play()
        isPlaying = true
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    func stop() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        episodeTitle = ""
        showName = ""
        isActive = false
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
    }

    func skipForward(_ seconds: Double = 15) {
        let target = min(currentTime + seconds, duration)
        seek(to: target)
    }

    func skipBackward(_ seconds: Double = 15) {
        let target = max(currentTime - seconds, 0)
        seek(to: target)
    }
}
