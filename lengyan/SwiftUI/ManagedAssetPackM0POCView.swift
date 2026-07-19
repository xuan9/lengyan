//
//  ManagedAssetPackM0POCView.swift
//  lengyan
//
//  TestFlight-visible M0 diagnostic. This does not route production audio.
//

import AVFoundation
import BackgroundAssets
import Foundation
import SwiftUI
import System

enum ManagedAssetsM0POCFeature {
    static var isEnabled: Bool {
        guard #available(iOS 26.0, *) else { return false }
        return Bundle.main.object(
            forInfoDictionaryKey: "LengyanM0ManagedAssetsDiagnosticsEnabled"
        ) as? Bool == true
    }
}

@available(iOS 26.0, *)
@MainActor
final class ManagedAssetPackM0POCModel: ObservableObject {
    static let assetPackID = "org.fuxuan.lengyan.m0.smoke"
    static let markerRelativePath = "M0/managed-assets-smoke.txt"
    static let audioRelativePath = "M0/managed-assets-smoke.m4a"
    static let expectedMarker = "lengyan-managed-assets-m0-ok-v1"

    @Published private(set) var statusText = "尚未检查"
    @Published private(set) var progressFraction = 0.0
    @Published private(set) var isBusy = false
    @Published private(set) var verifiedURL: URL?
    @Published private(set) var verifiedAudioURL: URL?
    @Published private(set) var isPlaying = false
    @Published private(set) var events: [String] = []

    private var operationTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?
    private var activeProgress: Progress?
    private var progressObservation: NSKeyValueObservation?
    private var audioPlayer: AVAudioPlayer?
    private var playbackCompletionTask: Task<Void, Never>?

    deinit {
        activeProgress?.cancel()
        operationTask?.cancel()
        statusTask?.cancel()
        progressObservation?.invalidate()
        playbackCompletionTask?.cancel()
        audioPlayer?.stop()
    }

    func refresh() {
        startOperation(label: "检查") { [weak self] in
            guard let self else { return }
            do {
                let manager = AssetPackManager.shared
                let pack = try await manager.assetPack(withID: Self.assetPackID)
                let status: AssetPack.Status
                if #available(iOS 26.4, *) {
                    status = await manager.localStatus(ofAssetPackWithID: Self.assetPackID)
                } else {
                    status = try await manager.status(ofAssetPackWithID: Self.assetPackID)
                }
                self.statusText = self.describe(status: status, downloadSize: pack.downloadSize)
                self.appendEvent("状态：\(self.statusText)")
            } catch {
                self.report(error, prefix: "检查失败")
            }
        }
    }

    func downloadAndVerify() {
        cancelActiveOperation(cancelSystemDownload: true)
        isBusy = true
        progressFraction = 0
        verifiedURL = nil
        verifiedAudioURL = nil
        statusText = "准备下载"
        appendEvent("开始请求 \(Self.assetPackID)")
        statusTask = makeStatusListener()

        operationTask = Task { [weak self] in
            guard let self else { return }
            defer { self.finishOperation() }

            do {
                let manager = AssetPackManager.shared
                let pack = try await manager.assetPack(withID: Self.assetPackID)
                self.appendEvent("已取得 pack v\(pack.version)，\(pack.downloadSize) bytes")

                if #available(iOS 26.4, *) {
                    try await manager.ensureLocalAvailability(
                        of: pack,
                        requireLatestVersion: false
                    )
                } else {
                    try await manager.ensureLocalAvailability(of: pack)
                }

                guard !Task.isCancelled else { return }
                let verified = try self.verifyLocalPack()
                self.progressFraction = 1
                self.verifiedURL = verified.markerURL
                self.verifiedAudioURL = verified.audioURL
                self.statusText = "验证成功"
                self.appendEvent(
                    "marker + M4A 验证成功：\(String(format: "%.2f", verified.duration)) 秒"
                )
            } catch {
                guard !Task.isCancelled else { return }
                self.report(error, prefix: "下载或验证失败")
            }
        }
    }

    func verifyOnly() {
        startOperation(label: "验证") { [weak self] in
            guard let self else { return }
            do {
                let verified = try self.verifyLocalPack()
                self.verifiedURL = verified.markerURL
                self.verifiedAudioURL = verified.audioURL
                self.statusText = "验证成功"
                self.appendEvent(
                    "本地 marker + M4A 正确：\(String(format: "%.2f", verified.duration)) 秒"
                )
            } catch {
                self.report(error, prefix: "本地验证失败")
            }
        }
    }

    func cancel() {
        cancelActiveOperation(cancelSystemDownload: true)
        statusText = "已请求取消"
        appendEvent("已调用 Progress.cancel() 并取消监听")
    }

    func playSmokeAudio() {
        guard let url = verifiedAudioURL else {
            report(VerificationError.audioNotVerified, prefix: "播放失败")
            return
        }

        stopPlayback(logEvent: false)
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            guard player.prepareToPlay(), player.play() else {
                throw VerificationError.audioPlaybackDidNotStart
            }
            audioPlayer = player
            isPlaying = true
            statusText = "正在播放测试音"
            appendEvent("从 Managed pack 播放 \(url.lastPathComponent)")

            let waitNanoseconds = UInt64((player.duration + 0.25) * 1_000_000_000)
            playbackCompletionTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: waitNanoseconds)
                guard !Task.isCancelled, let self else { return }
                self.audioPlayer = nil
                self.playbackCompletionTask = nil
                self.isPlaying = false
                self.statusText = "测试音播放完成"
                self.appendEvent("M4A 播放完成")
            }
        } catch {
            report(error, prefix: "播放失败")
        }
    }

    func stopPlayback() {
        stopPlayback(logEvent: true)
    }

    func remove() {
        cancelActiveOperation(cancelSystemDownload: true)
        stopPlayback(logEvent: false)
        isBusy = true
        statusText = "正在删除"
        appendEvent("请求 remove")

        operationTask = Task { [weak self] in
            guard let self else { return }
            defer { self.finishOperation() }
            do {
                try await AssetPackManager.shared.remove(assetPackWithID: Self.assetPackID)
                self.progressFraction = 0
                self.verifiedURL = nil
                self.verifiedAudioURL = nil
                self.statusText = "已删除"
                self.appendEvent("remove 成功")
            } catch {
                guard !Task.isCancelled else { return }
                self.report(error, prefix: "删除失败")
            }
        }
    }

    private func startOperation(
        label: String,
        operation: @escaping @MainActor () async -> Void
    ) {
        cancelActiveOperation(cancelSystemDownload: true)
        isBusy = true
        statusText = "正在\(label)"
        operationTask = Task { [weak self] in
            await operation()
            self?.finishOperation()
        }
    }

    private func makeStatusListener() -> Task<Void, Never> {
        Task { [weak self] in
            let updates = AssetPackManager.shared.statusUpdates(
                forAssetPackWithID: Self.assetPackID
            )

            for await update in updates {
                guard let self, !Task.isCancelled else { return }
                let isTerminal = self.apply(update: update)
                if isTerminal { return }
            }
        }
    }

    private func apply(update: AssetPackManager.DownloadStatusUpdate) -> Bool {
        switch update {
        case .began(let pack):
            statusText = "已开始"
            appendEvent("began v\(pack.version)")
            return false
        case .paused(let pack):
            statusText = "系统已暂停"
            appendEvent("paused v\(pack.version)")
            return false
        case .downloading(let pack, let progress):
            statusText = "下载中"
            observe(progress: progress)
            appendEvent("downloading v\(pack.version)")
            return false
        case .finished(let pack):
            statusText = "下载完成，正在验证"
            progressFraction = 1
            appendEvent("finished v\(pack.version)")
            return true
        case .failed(let pack, let error):
            statusText = "系统下载失败"
            appendEvent("failed v\(pack.version)：\(error.localizedDescription)")
            return true
        @unknown default:
            appendEvent("收到未知下载状态")
            return false
        }
    }

    private func observe(progress: Progress) {
        activeProgress = progress
        progressObservation?.invalidate()
        progressObservation = progress.observe(
            \.fractionCompleted,
            options: [.initial, .new]
        ) { [weak self] progress, _ in
            DispatchQueue.main.async {
                self?.progressFraction = progress.fractionCompleted
            }
        }
    }

    private func verifyLocalPack() throws -> (
        markerURL: URL,
        audioURL: URL,
        duration: TimeInterval
    ) {
        let manager = AssetPackManager.shared
        let markerURL = try manager.url(for: FilePath(Self.markerRelativePath))
        let data = try Data(contentsOf: markerURL)
        let marker = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard marker == Self.expectedMarker else {
            throw VerificationError.markerMismatch(actual: marker)
        }

        let audioURL = try manager.url(for: FilePath(Self.audioRelativePath))
        let player = try AVAudioPlayer(contentsOf: audioURL)
        guard player.duration > 0, player.prepareToPlay() else {
            throw VerificationError.invalidAudio
        }
        return (markerURL, audioURL, player.duration)
    }

    private func describe(status: AssetPack.Status, downloadSize: Int) -> String {
        var components: [String] = []
        if status.contains(.downloaded) { components.append("downloaded") }
        if status.contains(.downloading) { components.append("downloading") }
        if status.contains(.downloadAvailable) { components.append("downloadAvailable") }
        if status.contains(.updateAvailable) { components.append("updateAvailable") }
        if status.contains(.upToDate) { components.append("upToDate") }
        if status.contains(.outOfDate) { components.append("outOfDate") }
        if status.contains(.obsolete) { components.append("obsolete") }
        if components.isEmpty { components.append("raw=\(status.rawValue)") }
        return "\(components.joined(separator: ", ")) · \(downloadSize) bytes"
    }

    private func cancelActiveOperation(cancelSystemDownload: Bool) {
        if cancelSystemDownload {
            activeProgress?.cancel()
        }
        operationTask?.cancel()
        statusTask?.cancel()
        progressObservation?.invalidate()
        operationTask = nil
        statusTask = nil
        progressObservation = nil
        activeProgress = nil
        isBusy = false
    }

    private func finishOperation() {
        statusTask?.cancel()
        progressObservation?.invalidate()
        operationTask = nil
        statusTask = nil
        progressObservation = nil
        activeProgress = nil
        isBusy = false
    }

    private func stopPlayback(logEvent: Bool) {
        let wasPlaying = audioPlayer?.isPlaying == true
        playbackCompletionTask?.cancel()
        playbackCompletionTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        if logEvent, wasPlaying {
            statusText = "已停止测试音"
            appendEvent("停止 M4A 播放")
        }
    }

    private func report(_ error: Error, prefix: String) {
        statusText = prefix
        appendEvent("\(prefix)：\(error.localizedDescription)")
    }

    private func appendEvent(_ message: String) {
        let timestamp = Self.timestampFormatter.string(from: Date())
        events.insert("\(timestamp)  \(message)", at: 0)
        if events.count > 40 {
            events.removeLast(events.count - 40)
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private enum VerificationError: LocalizedError {
        case markerMismatch(actual: String?)
        case invalidAudio
        case audioNotVerified
        case audioPlaybackDidNotStart

        var errorDescription: String? {
            switch self {
            case .markerMismatch(let actual):
                return "marker 不匹配：\(actual ?? "<non-UTF8>")"
            case .invalidAudio:
                return "M4A 无法解码或时长为零"
            case .audioNotVerified:
                return "请先下载并验证 pack"
            case .audioPlaybackDidNotStart:
                return "AVAudioPlayer 未能开始播放"
            }
        }
    }
}

@available(iOS 26.0, *)
struct ManagedAssetPackM0POCView: View {
    @StateObject private var model = ManagedAssetPackM0POCModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("仅验证一个非生产小包，不会替换现有 ODR 音频。")
                    .font(.callout)
                    .foregroundColor(.secondary)

                Group {
                    diagnosticRow("Pack ID", ManagedAssetPackM0POCModel.assetPackID)
                    diagnosticRow("状态", model.statusText)
                    diagnosticRow(
                        "Marker",
                        model.verifiedURL?.lastPathComponent ?? "尚未验证"
                    )
                    diagnosticRow(
                        "测试音",
                        model.verifiedAudioURL?.lastPathComponent ?? "尚未验证"
                    )
                }

                ProgressView(value: model.progressFraction, total: 1)
                    .opacity(model.progressFraction > 0 || model.isBusy ? 1 : 0.35)

                HStack {
                    Button("下载并验证") { model.downloadAndVerify() }
                        .buttonStyle(.borderedProminent)
                    Button("取消") { model.cancel() }
                        .buttonStyle(.bordered)
                        .disabled(!model.isBusy)
                }

                HStack {
                    Button("播放测试音") { model.playSmokeAudio() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.verifiedAudioURL == nil || model.isBusy)
                    Button("停止播放") { model.stopPlayback() }
                        .buttonStyle(.bordered)
                        .disabled(!model.isPlaying)
                }

                HStack {
                    Button("检查状态") { model.refresh() }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy)
                    Button("仅验证本地") { model.verifyOnly() }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy)
                    Button("删除") { model.remove() }
                        .buttonStyle(.bordered)
                        .disabled(model.isBusy)
                }

                Divider()

                Text("事件日志")
                    .font(.headline)
                if model.events.isEmpty {
                    Text("暂无事件")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(model.events.enumerated()), id: \.offset) { _, event in
                        Text(event)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(SutraDesignSystem.backgroundColor())
        .task { model.refresh() }
    }

    private func diagnosticRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
    }
}
