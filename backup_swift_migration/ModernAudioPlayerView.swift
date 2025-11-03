//
//  ModernAudioPlayerView.swift
//  lengyan
//
//  Created by SwiftUI Migration on 2025/10/29.
//  Copyright © 2025年 xuan. All rights reserved.
//

import SwiftUI
import AVFoundation

// MARK: - Modern Audio Player View
struct ModernAudioPlayerView: View {
    @StateObject private var audioPlayer = AudioPlayerManager()
    @StateObject private var themeManager = ThemeManager()
    @State private var currentTrackIndex = 0
    @State private var isPlaying = false
    @State private var showTrackList = false

    // Audio tracks data
    private let audioTracks = [
        AudioTrack(id: 0, title: "楞严经 卷一", subtitle: "The Śūraṅgama Sūtra, Volume 1", duration: "32:15"),
        AudioTrack(id: 1, title: "楞严经 卷二", subtitle: "The Śūraṅgama Sūtra, Volume 2", duration: "28:42"),
        AudioTrack(id: 2, title: "楞严经 卷三", subtitle: "The Śūraṅgama Sūtra, Volume 3", duration: "35:18"),
        AudioTrack(id: 3, title: "楞严经 卷四", subtitle: "The Śūraṅgama Sūtra, Volume 4", duration: "29:55"),
        AudioTrack(id: 4, title: "楞严经 卷五", subtitle: "The Śūraṅgama Sūtra, Volume 5", duration: "31:22"),
        AudioTrack(id: 5, title: "楞严经 卷六", subtitle: "The Śūraṅgama Sūtra, Volume 6", duration: "26:38"),
        AudioTrack(id: 6, title: "楞严经 卷七", subtitle: "The Śūraṅgama Sūtra, Volume 7", duration: "30:45"),
        AudioTrack(id: 7, title: "楞严经 卷八", subtitle: "The Śūraṅgama Sūtra, Volume 8", duration: "33:12"),
        AudioTrack(id: 8, title: "楞严经 卷九", subtitle: "The Śūraṅgama Sūtra, Volume 9", duration: "27:28"),
        AudioTrack(id: 9, title: "楞严经 卷十", subtitle: "The Śūraṅgama Sūtra, Volume 10", duration: "29:03"),
        AudioTrack(id: 10, title: "楞严咒", subtitle: "The Śūraṅgama Mantra", duration: "12:45")
    ]

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        themeManager.backgroundColor,
                        themeManager.backgroundColor.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Current Track Info
                        currentTrackInfoSection

                        // Beautiful Audio Visualizer
                        audioVisualizerSection

                        // Playback Controls
                        playbackControlsSection

                        // Progress Section
                        progressSection

                        // Volume Control
                        volumeControlSection

                        // Track List
                        trackListSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitle("聽經")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showTrackList.toggle() }) {
                        Image(systemName: "list.bullet")
                            .foregroundColor(themeManager.primaryTextColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showTrackList) {
            TrackListSheetView(
                tracks: audioTracks,
                currentTrackIndex: $currentTrackIndex,
                onTrackSelected: { index in
                    currentTrackIndex = index
                    playTrack(at: index)
                }
            )
        }
        .onAppear {
            setupAudioPlayer()
        }
    }

    // MARK: - Current Track Info Section
    private var currentTrackInfoSection: some View {
        VStack(spacing: 16) {
            // Album Art Placeholder
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            LengyanDesignSystem.Colors.accentGold,
                            LengyanDesignSystem.Colors.accentGold.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
                .shadow(color: LengyanDesignSystem.Shadow.accent.color, radius: 16, x: 0, y: 8)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 32))
                            .foregroundColor(.white)

                        Text("楞严经")
                            .font(LengyanDesignSystem.Typography.sutraTitle)
                            .foregroundColor(.white)
                    }
                )

            // Track Information
            VStack(spacing: 8) {
                Text(audioTracks[currentTrackIndex].title)
                    .font(LengyanDesignSystem.Typography.uiTitle)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.primaryTextColor)
                    .multilineTextAlignment(.center)

                Text(audioTracks[currentTrackIndex].subtitle)
                    .font(LengyanDesignSystem.Typography.uiCaption)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Audio Visualizer Section
    private var audioVisualizerSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 4) {
                ForEach(0..<20, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LengyanDesignSystem.Colors.accentGold)
                        .frame(width: 4, height: isPlaying ? CGFloat.random(in: 20...60) : 20)
                        .animation(
                            isPlaying ?
                            .easeInOut(duration: Double.random(in: 0.3...0.8)).repeatForever() :
                            .default,
                            value: isPlaying
                        )
                }
            }
            .frame(height: 60)

            Text("正在播放: \(audioTracks[currentTrackIndex].title)")
                .font(LengyanDesignSystem.Typography.uiCaption)
                .foregroundColor(themeManager.secondaryTextColor)
        }
        .padding(.vertical, 20)
        .lengyanMaterialCard()
    }

    // MARK: - Playback Controls Section
    private var playbackControlsSection: some View {
        VStack(spacing: 24) {
            HStack(spacing: 40) {
                // Previous Button
                Button(action: previousTrack) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(themeManager.primaryTextColor)
                }
                .disabled(currentTrackIndex == 0)

                // Play/Pause Button
                Button(action: togglePlayPause) {
                    ZStack {
                        Circle()
                            .fill(LengyanDesignSystem.Colors.accentGold)
                            .frame(width: 80, height: 80)
                            .shadow(color: LengyanDesignSystem.Shadow.accent.color, radius: 12, x: 0, y: 6)

                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white)
                    }
                }

                // Next Button
                Button(action: nextTrack) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(themeManager.primaryTextColor)
                }
                .disabled(currentTrackIndex == audioTracks.count - 1)
            }

            // Additional Controls
            HStack(spacing: 32) {
                // Shuffle Button
                Button(action: { /* Shuffle logic */ }) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 18))
                        .foregroundColor(themeManager.secondaryTextColor)
                }

                // Repeat Button
                Button(action: { /* Repeat logic */ }) {
                    Image(systemName: "repeat")
                        .font(.system(size: 18))
                        .foregroundColor(themeManager.secondaryTextColor)
                }

                // Speed Button
                Button(action: { /* Speed logic */ }) {
                    Text("1.0x")
                        .font(LengyanDesignSystem.Typography.uiCaption)
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
        }
        .padding(.vertical, 24)
        .lengyanMaterialCard()
    }

    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 12) {
            // Time Labels
            HStack {
                Text(currentTime)
                    .font(LengyanDesignSystem.Typography.uiCaption)
                    .foregroundColor(themeManager.secondaryTextColor)

                Spacer()

                Text(audioTracks[currentTrackIndex].duration)
                    .font(LengyanDesignSystem.Typography.uiCaption)
                    .foregroundColor(themeManager.secondaryTextColor)
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(themeManager.secondaryTextColor.opacity(0.2))
                        .frame(height: 8)

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LengyanDesignSystem.Colors.accentGold)
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.easeInOut(duration: 0.1), value: progress)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Volume Control Section
    private var volumeControlSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "speaker.fill")
                    .foregroundColor(themeManager.secondaryTextColor)

                Slider(value: $volume, in: 0...1)
                    .accentColor(LengyanDesignSystem.Colors.accentGold)

                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(themeManager.secondaryTextColor)
            }

            HStack {
                Text("音量")
                    .font(LengyanDesignSystem.Typography.uiBody)
                    .foregroundColor(themeManager.primaryTextColor)

                Spacer()

                Text("\(Int(volume * 100))%")
                    .font(LengyanDesignSystem.Typography.uiBody)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
        }
        .padding(.vertical, 16)
        .lengyanMaterialCard()
    }

    // MARK: - Track List Section
    private var trackListSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("播放列表")
                    .font(LengyanDesignSystem.Typography.uiHeading)
                    .foregroundColor(themeManager.primaryTextColor)

                Spacer()

                Button(action: { showTrackList = true }) {
                    Text("查看全部")
                        .font(LengyanDesignSystem.Typography.uiCaption)
                        .foregroundColor(LengyanDesignSystem.Colors.accentGold)
                }
            }

            // Mini Track List (First 3 tracks)
            VStack(spacing: 8) {
                ForEach(Array(audioTracks.prefix(3).enumerated()), id: \.offset) { index, track in
                    MiniTrackRow(
                        track: track,
                        isPlaying: index == currentTrackIndex,
                        isCurrent: index == currentTrackIndex,
                        onTap: { playTrack(at: index) }
                    )
                }
            }
        }
        .lengyanMaterialCard()
    }

    // MARK: - Helper Properties
    @State private var progress: Double = 0.3
    @State private var volume: Double = 0.7
    @State private var currentTime: String = "2:15"

    // MARK: - Actions
    private func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            audioPlayer.play()
        } else {
            audioPlayer.pause()
        }
    }

    private func playTrack(at index: Int) {
        currentTrackIndex = index
        isPlaying = true
        // Update audio player with new track
        resetProgress()
    }

    private func nextTrack() {
        if currentTrackIndex < audioTracks.count - 1 {
            playTrack(at: currentTrackIndex + 1)
        }
    }

    private func previousTrack() {
        if currentTrackIndex > 0 {
            playTrack(at: currentTrackIndex - 1)
        }
    }

    private func resetProgress() {
        progress = 0.0
        currentTime = "0:00"
    }

    private func setupAudioPlayer() {
        // Setup audio player with current track
        audioPlayer.setupTrack(audioTracks[currentTrackIndex])
    }
}

// MARK: - Mini Track Row
struct MiniTrackRow: View {
    let track: AudioTrack
    let isPlaying: Bool
    let isCurrent: Bool
    let onTap: () -> Void
    @StateObject private var themeManager = ThemeManager()

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Play/Pause Icon
                ZStack {
                    Circle()
                        .fill(isPlaying ? LengyanDesignSystem.Colors.accentGold : themeManager.secondaryTextColor.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isPlaying ? .white : themeManager.primaryTextColor)
                }

                // Track Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(LengyanDesignSystem.Typography.uiBody)
                        .foregroundColor(themeManager.primaryTextColor)
                        .lineLimit(1)

                    Text(track.subtitle)
                        .font(LengyanDesignSystem.Typography.uiSmall)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .lineLimit(1)
                }

                Spacer()

                // Duration
                Text(track.duration)
                    .font(LengyanDesignSystem.Typography.uiSmall)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrent ? LengyanDesignSystem.Colors.accentGold.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isCurrent ? LengyanDesignSystem.Colors.accentGold.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Track List Sheet
struct TrackListSheetView: View {
    let tracks: [AudioTrack]
    @Binding var currentTrackIndex: Int
    let onTrackSelected: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager()

    var body: some View {
        NavigationView {
            List {
                ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                    TrackListRow(
                        track: track,
                        isPlaying: index == currentTrackIndex,
                        onTap: {
                            onTrackSelected(index)
                            dismiss()
                        }
                    )
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("播放列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Track List Row
struct TrackListRow: View {
    let track: AudioTrack
    let isPlaying: Bool
    let onTap: () -> Void
    @StateObject private var themeManager = ThemeManager()

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Track Number
                Text("\(track.id + 1)")
                    .font(LengyanDesignSystem.Typography.uiCaption)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .frame(width: 30, alignment: .leading)

                // Play Icon
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle")
                    .font(.system(size: 20))
                    .foregroundColor(isPlaying ? LengyanDesignSystem.Colors.accentGold : themeManager.secondaryTextColor)

                // Track Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(LengyanDesignSystem.Typography.uiBody)
                        .foregroundColor(themeManager.primaryTextColor)
                        .lineLimit(1)

                    Text(track.subtitle)
                        .font(LengyanDesignSystem.Typography.uiSmall)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .lineLimit(1)
                }

                Spacer()

                // Duration
                Text(track.duration)
                    .font(LengyanDesignSystem.Typography.uiCaption)
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(themeManager.backgroundColor)
    }
}

// MARK: - Data Models
struct AudioTrack {
    let id: Int
    let title: String
    let subtitle: String
    let duration: String
}

// MARK: - Audio Player Manager
class AudioPlayerManager: ObservableObject {
    private var audioPlayer: AVAudioPlayer?

    func setupTrack(_ track: AudioTrack) {
        // Setup audio player with track
        // This would integrate with your existing audio system
    }

    func play() {
        audioPlayer?.play()
    }

    func pause() {
        audioPlayer?.pause()
    }

    func stop() {
        audioPlayer?.stop()
    }
}

// MARK: - Preview
struct ModernAudioPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        ModernAudioPlayerView()
            .previewDisplayName("Modern Audio Player")
    }
}