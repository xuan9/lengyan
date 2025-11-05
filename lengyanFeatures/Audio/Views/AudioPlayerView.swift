//
//  AudioPlayerView.swift
//  Lengyan
//
//  Modern SwiftUI audio player view
//  <100 lines, declarative, testable
//

import SwiftUI

/// Modern audio player view
/// Clean, minimal implementation with playback controls
public struct AudioPlayerView: View {
    @StateObject private var viewModel: AudioPlayerViewModel

    public init(viewModel: AudioPlayerViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Track info
            VStack(spacing: 8) {
                Text(viewModel.currentTrack)
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                Text(viewModel.trackInfo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top)

            Spacer()

            // Progress bar
            ProgressView(value: viewModel.progress, total: 1.0)
                .tint(.accentColor)

            // Time labels
            HStack {
                Text(viewModel.elapsedTime)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(viewModel.remainingTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Playback controls
            HStack(spacing: 32) {
                Button {
                    viewModel.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .disabled(!viewModel.hasPreviousTrack)

                Button {
                    viewModel.togglePlayPause()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                }
                .tint(.accentColor)

                Button {
                    viewModel.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .disabled(!viewModel.hasNextTrack)
            }

            Spacer()

            // Volume control
            HStack {
                Image(systemName: "speaker.fill")
                    .foregroundColor(.secondary)

                Slider(value: $viewModel.volume, in: 0...1)

                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.secondary)
            }
            .padding(.bottom)
        }
        .padding()
        .navigationTitle("Audio Player")
    }
}

// MARK: - Preview

#Preview {
    let mockRepository = AudioRepositoryImpl()
    let viewModel = AudioPlayerViewModel(repository: mockRepository)
    return NavigationStack {
        AudioPlayerView(viewModel: viewModel)
    }
}
