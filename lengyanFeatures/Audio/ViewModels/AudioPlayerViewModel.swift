//
//  AudioPlayerViewModel.swift
//  Lengyan
//
//  ViewModel for audio player
//  Handles playback state and controls
//

import SwiftUI

/// ViewModel for audio player
/// Reactive, testable, MVVM pattern
@MainActor
public final class AudioPlayerViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentTrack: String = "No track selected"
    @Published var isPlaying: Bool = false
    @Published var progress: Double = 0.0
    @Published var elapsedTime: String = "00:00"
    @Published var remainingTime: String = "-00:00"
    @Published var volume: Double = 0.5
    @Published var hasPreviousTrack: Bool = false
    @Published var hasNextTrack: Bool = false

    // MARK: - Computed Properties

    var trackInfo: String {
        return isPlaying ? "Now Playing" : "Paused"
    }

    // MARK: - Dependencies

    private let repository: AudioRepository
    private var progressTimer: Timer?

    // MARK: - Initialization

    public init(repository: AudioRepository) {
        self.repository = repository
        startProgressTimer()
    }

    deinit {
        stopProgressTimer()
    }

    // MARK: - Public Methods

    /// Toggle play/pause
    public func togglePlayPause() {
        if isPlaying {
            repository.pause()
            isPlaying = false
        } else {
            if repository.getCurrentTrack() == nil {
                repository.playTrack(named: "Track 1")
                currentTrack = "Track 1"
            } else {
                repository.resume()
            }
            isPlaying = true
        }
    }

    /// Play specific track
    public func playTrack(named: String) {
        repository.playTrack(named: named)
        currentTrack = named
        isPlaying = true
        progress = 0.0
    }

    /// Stop playback
    public func stop() {
        repository.stop()
        isPlaying = false
        progress = 0.0
    }

    /// Move to next track
    public func nextTrack() {
        // Implementation for next track
        // Will be added in future phase
        progress = min(progress + 0.1, 1.0)
    }

    /// Move to previous track
    public func previousTrack() {
        // Implementation for previous track
        // Will be added in future phase
        progress = max(progress - 0.1, 0.0)
    }

    // MARK: - Private Methods

    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateProgress() {
        guard isPlaying else { return }

        progress = min(progress + 0.01, 1.0)

        // Update time labels
        let elapsedSeconds = Int(progress * 300) // Assuming 5 minute tracks
        elapsedTime = formatTime(elapsedSeconds)

        let remainingSeconds = max(300 - elapsedSeconds, 0)
        remainingTime = "-" + formatTime(remainingSeconds)

        // Auto-stop at end
        if progress >= 1.0 {
            isPlaying = false
            repository.stop()
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
