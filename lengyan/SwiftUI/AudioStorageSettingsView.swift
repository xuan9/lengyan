//
//  AudioStorageSettingsView.swift
//  lengyan
//

import BackgroundAssets
import SwiftUI

@MainActor
private final class AudioStorageSettingsModel: ObservableObject {
    @Published var summary = ""
    @Published var isBusy = false
    @Published var showRemovalConfirmation = false
    @Published var resultMessage: String?

    func refresh() {
        isBusy = true
        Task { [weak self] in
            guard let self else { return }
            let fallbackSummary = self.fallbackSummary()
            if #available(iOS 26.0, *) {
                await self.refreshManagedSummary(fallbackSummary: fallbackSummary)
            } else if fallbackSummary.fileCount > 0 {
                self.summary = String(
                    format: L10n.str("audio_storage_odr_fallback_format"),
                    fallbackSummary.fileCount,
                    ByteCountFormatter.string(
                        fromByteCount: fallbackSummary.byteCount,
                        countStyle: .file
                    )
                )
            } else {
                self.summary = L10n.str("audio_storage_odr_managed")
            }
            self.isBusy = false
        }
    }

    func removeAll() {
        isBusy = true
        resultMessage = nil
        Task { [weak self] in
            guard let self else { return }
            let results = await AudioManager.shared.removeAllDownloadedAudio()
            let failed = results.values.reduce(into: 0) { count, result in
                if case .failure = result { count += 1 }
            }
            if failed == 0 {
                self.resultMessage = L10n.str("audio_storage_remove_success")
            } else {
                self.resultMessage = String(
                    format: L10n.str("audio_storage_remove_partial_format"),
                    failed
                )
            }
            if #available(iOS 26.0, *) {
                await self.refreshManagedSummary(
                    fallbackSummary: self.fallbackSummary()
                )
            } else {
                self.summary = L10n.str("audio_storage_odr_released")
            }
            self.isBusy = false
        }
    }

    @available(iOS 26.0, *)
    private func refreshManagedSummary(
        fallbackSummary: CDNAudioCacheSummary
    ) async {
        var downloadedCount = 0
        var totalBytes = 0
        let manager = AssetPackManager.shared

        for descriptor in AudioAssetCatalog.descriptors {
            do {
                let pack = try await manager.assetPack(withID: descriptor.managedPackID)
                let status: AssetPack.Status
                if #available(iOS 26.4, *) {
                    status = await manager.localStatus(
                        ofAssetPackWithID: descriptor.managedPackID
                    )
                } else {
                    status = try await manager.status(
                        ofAssetPackWithID: descriptor.managedPackID
                    )
                }
                if status.contains(.downloaded) {
                    downloadedCount += 1
                    totalBytes += pack.downloadSize
                }
            } catch {
                // A pack not yet visible to this build is simply not local.
            }
        }

        let formattedBytes = ByteCountFormatter.string(
            fromByteCount: Int64(totalBytes),
            countStyle: .file
        )
        if fallbackSummary.fileCount > 0 {
            summary = String(
                format: L10n.str("audio_storage_combined_format"),
                downloadedCount,
                formattedBytes,
                fallbackSummary.fileCount,
                ByteCountFormatter.string(
                    fromByteCount: fallbackSummary.byteCount,
                    countStyle: .file
                )
            )
        } else {
            summary = String(
                format: L10n.str("audio_storage_managed_format"),
                downloadedCount,
                formattedBytes
            )
        }
    }

    private func fallbackSummary() -> CDNAudioCacheSummary {
        guard let configuration = CDNAudioFallbackConfiguration.production else {
            return CDNAudioCacheSummary(fileCount: 0, byteCount: 0)
        }
        return CDNAudioCache.summary(configuration: configuration)
    }
}

struct AudioStorageSettingsView: View {
    @StateObject private var model = AudioStorageSettingsModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(model.summary)
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))

                Text(L10n.str("audio_storage_explanation"))
                    .font(SutraTypographyBridge.uiSmall(weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textSecondary))

                if let resultMessage = model.resultMessage {
                    Text(resultMessage)
                        .font(SutraTypographyBridge.uiSmall(weight: .medium))
                        .foregroundColor(SutraDesignSystem.color(.textSecondary))
                }

                HStack(spacing: 12) {
                    Button(L10n.str("audio_storage_refresh")) {
                        model.refresh()
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        model.showRemovalConfirmation = true
                    } label: {
                        Text(L10n.str("audio_storage_remove_all"))
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(model.isBusy)

                if model.isBusy {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
        .background(SutraDesignSystem.backgroundColor())
        .task { model.refresh() }
        .alert(
            L10n.str("audio_storage_remove_confirm_title"),
            isPresented: $model.showRemovalConfirmation
        ) {
            Button(L10n.str("cancel"), role: .cancel) {}
            Button(L10n.str("audio_storage_remove_all"), role: .destructive) {
                model.removeAll()
            }
        } message: {
            Text(L10n.str("audio_storage_remove_confirm_body"))
        }
    }
}
