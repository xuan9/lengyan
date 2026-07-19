//
//  CDNAudioAssetProvider.swift
//  lengyan
//
//  Downloads the same immutable M4A bytes as the Apple-hosted packs from an
//  HTTPS fallback origin. Files are not trusted until byte count and SHA-256
//  both match the catalog compiled into the app.
//

import CryptoKit
import Foundation

struct CDNAudioFallbackConfiguration: Sendable {
    static let enabledInfoKey = "LengyanCDNAudioFallbackEnabled"
    static let baseURLInfoKey = "LengyanCDNAudioFallbackBaseURL"
    static let stallTimeoutInfoKey = "LengyanCDNAudioFallbackStallTimeoutSeconds"

    let baseURL: URL
    let cacheDirectory: URL
    let stallTimeout: TimeInterval
    let resourceTimeout: TimeInterval

    static var production: CDNAudioFallbackConfiguration? {
        from(bundle: .main)
    }

    static func from(
        bundle: Bundle,
        fileManager: FileManager = .default
    ) -> CDNAudioFallbackConfiguration? {
        guard bundle.object(forInfoDictionaryKey: enabledInfoKey) as? Bool == true,
              let rawURL = bundle.object(forInfoDictionaryKey: baseURLInfoKey) as? String,
              let baseURL = validatedBaseURL(rawURL),
              let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
              ).first else { return nil }

        let configuredTimeout = (bundle.object(
            forInfoDictionaryKey: stallTimeoutInfoKey
        ) as? NSNumber)?.doubleValue ?? 15

        return CDNAudioFallbackConfiguration(
            baseURL: baseURL,
            cacheDirectory: applicationSupport.appendingPathComponent(
                "AudioFallback",
                isDirectory: true
            ),
            stallTimeout: min(max(configuredTimeout, 5), 60),
            resourceTimeout: 5 * 60
        )
    }

    static func validatedBaseURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              var components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil else { return nil }
        components.query = nil
        components.fragment = nil
        return components.url
    }

    func remoteURL(for asset: AudioAssetDescriptor) -> URL {
        asset.cdnRelativePath.split(separator: "/").reduce(baseURL) { url, component in
            url.appendingPathComponent(String(component), isDirectory: false)
        }
    }
}

struct CDNAudioCacheSummary: Sendable {
    let fileCount: Int
    let byteCount: Int64
}

enum CDNAudioCache {
    static func destinationURL(
        for asset: AudioAssetDescriptor,
        configuration: CDNAudioFallbackConfiguration
    ) -> URL {
        asset.cdnRelativePath.split(separator: "/").reduce(
            configuration.cacheDirectory
        ) { url, component in
            url.appendingPathComponent(String(component), isDirectory: false)
        }
    }

    static func summary(
        configuration: CDNAudioFallbackConfiguration,
        fileManager: FileManager = .default
    ) -> CDNAudioCacheSummary {
        var fileCount = 0
        var byteCount: Int64 = 0
        for asset in AudioAssetCatalog.descriptors {
            let url = destinationURL(for: asset, configuration: configuration)
            guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                  let size = attributes[.size] as? NSNumber,
                  size.int64Value == asset.contentByteCount else { continue }
            fileCount += 1
            byteCount += size.int64Value
        }
        return CDNAudioCacheSummary(fileCount: fileCount, byteCount: byteCount)
    }

    static func validate(
        _ url: URL,
        for asset: AudioAssetDescriptor,
        fileManager: FileManager = .default
    ) throws {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber,
              size.int64Value == asset.contentByteCount else {
            throw AudioAssetError.invalidDownloadedFile(asset.id)
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            hasher.update(data: data)
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        guard digest == asset.contentSHA256 else {
            throw AudioAssetError.invalidDownloadedFile(asset.id)
        }
    }

    static func install(
        stagingURL: URL,
        for asset: AudioAssetDescriptor,
        configuration: CDNAudioFallbackConfiguration,
        fileManager: FileManager = .default
    ) throws -> URL {
        try validate(stagingURL, for: asset, fileManager: fileManager)
        let destination = destinationURL(for: asset, configuration: configuration)
        let parent = destination.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: parent,
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: stagingURL, to: destination)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDestination = destination
        try mutableDestination.setResourceValues(values)
        return destination
    }
}

protocol CDNAudioDownloading: Sendable {
    func download(
        from remoteURL: URL,
        to stagingURL: URL,
        expectedByteCount: Int64,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws
}

enum CDNAudioDownloadPolicy {
    static func exceedsExpectedSize(
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64,
        catalogByteCount: Int64
    ) -> Bool {
        guard catalogByteCount > 0 else { return true }
        if totalBytesWritten > catalogByteCount { return true }
        return totalBytesExpectedToWrite > catalogByteCount
    }
}

struct URLSessionCDNAudioDownloader: CDNAudioDownloading {
    let resourceTimeout: TimeInterval

    func download(
        from remoteURL: URL,
        to stagingURL: URL,
        expectedByteCount: Int64,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let operation = URLSessionCDNAudioDownloadOperation(
            remoteURL: remoteURL,
            stagingURL: stagingURL,
            expectedByteCount: expectedByteCount,
            resourceTimeout: resourceTimeout,
            progress: progress
        )
        try await operation.run()
    }
}

private final class URLSessionCDNAudioDownloadOperation: NSObject,
    URLSessionDownloadDelegate, @unchecked Sendable {
    private let remoteURL: URL
    private let stagingURL: URL
    private let expectedByteCount: Int64
    private let resourceTimeout: TimeInterval
    private let progress: @Sendable (Double) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var isFinished = false
    private var cancellationRequested = false

    init(
        remoteURL: URL,
        stagingURL: URL,
        expectedByteCount: Int64,
        resourceTimeout: TimeInterval,
        progress: @escaping @Sendable (Double) -> Void
    ) {
        self.remoteURL = remoteURL
        self.stagingURL = stagingURL
        self.expectedByteCount = expectedByteCount
        self.resourceTimeout = resourceTimeout
        self.progress = progress
    }

    func run() async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                start(continuation: continuation)
            }
        } onCancel: {
            self.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if CDNAudioDownloadPolicy.exceedsExpectedSize(
            totalBytesWritten: totalBytesWritten,
            totalBytesExpectedToWrite: totalBytesExpectedToWrite,
            catalogByteCount: expectedByteCount
        ) {
            downloadTask.cancel()
            finish(.failure(AudioAssetError.invalidDownloadedFile(
                remoteURL.lastPathComponent
            )))
            return
        }
        let expected = totalBytesExpectedToWrite > 0
            ? totalBytesExpectedToWrite
            : expectedByteCount
        guard expected > 0 else { return }
        progress(min(max(Double(totalBytesWritten) / Double(expected), 0), 1))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard downloadTask.response?.url?.scheme?.lowercased() == "https" else {
            finish(.failure(AudioAssetError.insecureRemoteResponse))
            return
        }
        if let response = downloadTask.response as? HTTPURLResponse,
           !(200...299).contains(response.statusCode) {
            finish(.failure(AudioAssetError.invalidRemoteResponse(response.statusCode)))
            return
        }
        do {
            try FileManager.default.moveItem(at: location, to: stagingURL)
            finish(.success(()))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            finish(.failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard request.url?.scheme?.lowercased() == "https" else {
            completionHandler(nil)
            finish(.failure(AudioAssetError.insecureRemoteResponse))
            return
        }
        completionHandler(request)
    }

    private func start(continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        if cancellationRequested {
            lock.unlock()
            continuation.resume(throwing: AudioAssetError.cancelled)
            return
        }
        self.continuation = continuation
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.httpMaximumConnectionsPerHost = 2
        let session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )
        var request = URLRequest(url: remoteURL)
        request.setValue("audio/mp4,audio/*", forHTTPHeaderField: "Accept")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        let task = session.downloadTask(with: request)
        task.countOfBytesClientExpectsToReceive = expectedByteCount
        self.session = session
        self.task = task
        lock.unlock()
        task.resume()
    }

    private func cancel() {
        lock.lock()
        cancellationRequested = true
        let task = self.task
        lock.unlock()
        task?.cancel()
    }

    private func finish(_ result: Result<Void, Error>) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        let continuation = self.continuation
        self.continuation = nil
        let session = self.session
        self.session = nil
        self.task = nil
        lock.unlock()

        switch result {
        case .success:
            continuation?.resume()
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
        session?.finishTasksAndInvalidate()
    }
}

actor CDNAudioAssetProvider: AudioAssetProvider {
    nonisolated let backendKind: AudioAssetBackendKind = .cloudflareCDN

    private struct Consumer {
        var intent: AudioAssetIntent
        let continuation: AsyncThrowingStream<AudioAssetEvent, Error>.Continuation
    }

    private struct Entry {
        let asset: AudioAssetDescriptor
        let generation: UUID
        var consumers: [UUID: Consumer]
        var leaseIDs: Set<UUID>
        var localURL: URL?
        var task: Task<Void, Never>?
    }

    private let configuration: CDNAudioFallbackConfiguration
    private let downloader: any CDNAudioDownloading
    private let fileManager: FileManager
    private var entries: [String: Entry] = [:]
    private var requestToAsset: [UUID: String] = [:]
    private var leaseToAsset: [UUID: String] = [:]
    private var isShutdown = false

    init(
        configuration: CDNAudioFallbackConfiguration,
        downloader: (any CDNAudioDownloading)? = nil,
        fileManager: FileManager = .default
    ) {
        self.configuration = configuration
        self.downloader = downloader ?? URLSessionCDNAudioDownloader(
            resourceTimeout: configuration.resourceTimeout
        )
        self.fileManager = fileManager
    }

    func request(
        _ asset: AudioAssetDescriptor,
        intent: AudioAssetIntent
    ) async -> AudioAssetRequestHandle {
        let requestID = UUID()
        let output = AsyncThrowingStream<AudioAssetEvent, Error>.audioAssetStream()
        output.continuation.onTermination = { [weak self] _ in
            Task { await self?.cancel(requestID: requestID) }
        }

        guard !isShutdown else {
            output.continuation.finish(throwing: AudioAssetError.cancelled)
            return AudioAssetRequestHandle(
                requestID: requestID,
                assetID: asset.id,
                events: output.stream
            )
        }

        requestToAsset[requestID] = asset.id
        let consumer = Consumer(intent: intent, continuation: output.continuation)
        output.continuation.yield(.queued)

        if var entry = entries[asset.id] {
            entry.consumers[requestID] = consumer
            entries[asset.id] = entry
            if let url = entry.localURL {
                deliverReady(assetID: asset.id, generation: entry.generation, url: url)
            }
        } else {
            let generation = UUID()
            var entry = Entry(
                asset: asset,
                generation: generation,
                consumers: [requestID: consumer],
                leaseIDs: [],
                localURL: nil,
                task: nil
            )
            entry.task = makeResolveTask(asset: asset, generation: generation)
            entries[asset.id] = entry
        }

        return AudioAssetRequestHandle(
            requestID: requestID,
            assetID: asset.id,
            events: output.stream
        )
    }

    func cachedLeaseIfAvailable(_ asset: AudioAssetDescriptor) -> AudioAssetLease? {
        if var entry = entries[asset.id], let url = entry.localURL {
            let lease = AudioAssetLease(assetID: asset.id, localURL: url)
            entry.leaseIDs.insert(lease.id)
            entries[asset.id] = entry
            leaseToAsset[lease.id] = asset.id
            return lease
        }
        guard entries[asset.id] == nil else { return nil }

        let destination = CDNAudioCache.destinationURL(
            for: asset,
            configuration: configuration
        )
        do {
            try CDNAudioCache.validate(destination, for: asset, fileManager: fileManager)
            let lease = AudioAssetLease(assetID: asset.id, localURL: destination)
            entries[asset.id] = Entry(
                asset: asset,
                generation: UUID(),
                consumers: [:],
                leaseIDs: [lease.id],
                localURL: destination,
                task: nil
            )
            leaseToAsset[lease.id] = asset.id
            return lease
        } catch {
            try? fileManager.removeItem(at: destination)
            return nil
        }
    }

    func promote(requestID: UUID) async {
        guard let assetID = requestToAsset[requestID],
              var entry = entries[assetID],
              var consumer = entry.consumers[requestID] else { return }
        consumer.intent = .playback
        entry.consumers[requestID] = consumer
        entries[assetID] = entry
    }

    func cancel(requestID: UUID) async {
        guard let assetID = requestToAsset.removeValue(forKey: requestID),
              var entry = entries[assetID],
              let consumer = entry.consumers.removeValue(forKey: requestID) else { return }
        consumer.continuation.finish(throwing: AudioAssetError.cancelled)
        entries[assetID] = entry
        cleanupIfUnused(assetID: assetID, generation: entry.generation, cancelTask: true)
    }

    func release(_ lease: AudioAssetLease) async {
        guard let assetID = leaseToAsset.removeValue(forKey: lease.id),
              var entry = entries[assetID] else { return }
        entry.leaseIDs.remove(lease.id)
        entries[assetID] = entry
        cleanupIfUnused(assetID: assetID, generation: entry.generation, cancelTask: false)
    }

    func evict(assetID: String) async throws -> AudioAssetEvictionResult {
        if let entry = entries[assetID],
           !entry.leaseIDs.isEmpty || !entry.consumers.isEmpty {
            throw AudioAssetError.packIsInUse(assetID)
        }
        if let entry = entries.removeValue(forKey: assetID) {
            entry.task?.cancel()
        }
        guard let asset = AudioAssetCatalog.descriptor(for: assetID) else {
            throw AudioAssetError.unknownAsset(assetID)
        }
        let destination = CDNAudioCache.destinationURL(
            for: asset,
            configuration: configuration
        )
        let assetDirectory = destination.deletingLastPathComponent()
        if fileManager.fileExists(atPath: assetDirectory.path) {
            try fileManager.removeItem(at: assetDirectory)
        }
        return .removed
    }

    func shutdown() async {
        guard !isShutdown else { return }
        isShutdown = true
        for assetID in Array(entries.keys) {
            guard let entry = entries.removeValue(forKey: assetID) else { continue }
            entry.task?.cancel()
            for (requestID, consumer) in entry.consumers {
                requestToAsset.removeValue(forKey: requestID)
                consumer.continuation.finish(throwing: AudioAssetError.cancelled)
            }
        }
        leaseToAsset.removeAll()
    }

    private func makeResolveTask(
        asset: AudioAssetDescriptor,
        generation: UUID
    ) -> Task<Void, Never> {
        Task { [weak self] in
            await self?.resolve(asset: asset, generation: generation)
        }
    }

    private func resolve(asset: AudioAssetDescriptor, generation: UUID) async {
        let destination = CDNAudioCache.destinationURL(
            for: asset,
            configuration: configuration
        )
        do {
            if fileManager.fileExists(atPath: destination.path) {
                do {
                    try CDNAudioCache.validate(destination, for: asset, fileManager: fileManager)
                    deliverReady(assetID: asset.id, generation: generation, url: destination)
                    return
                } catch {
                    try? fileManager.removeItem(at: destination)
                }
            }

            let stagingDirectory = configuration.cacheDirectory.appendingPathComponent(
                ".staging",
                isDirectory: true
            )
            try fileManager.createDirectory(
                at: stagingDirectory,
                withIntermediateDirectories: true
            )
            let stagingURL = stagingDirectory.appendingPathComponent(
                "\(asset.id)-\(generation.uuidString).part"
            )
            defer { try? fileManager.removeItem(at: stagingURL) }

            try await downloader.download(
                from: configuration.remoteURL(for: asset),
                to: stagingURL,
                expectedByteCount: asset.contentByteCount
            ) { [weak self] fraction in
                Task {
                    await self?.publishProgress(
                        assetID: asset.id,
                        generation: generation,
                        fraction: fraction
                    )
                }
            }
            try Task.checkCancellation()
            let installedURL = try CDNAudioCache.install(
                stagingURL: stagingURL,
                for: asset,
                configuration: configuration,
                fileManager: fileManager
            )
            deliverReady(assetID: asset.id, generation: generation, url: installedURL)
        } catch {
            finishFailure(assetID: asset.id, generation: generation, error: error)
        }
    }

    private func publishProgress(assetID: String, generation: UUID, fraction: Double) {
        guard let entry = entries[assetID], entry.generation == generation else { return }
        let clamped = min(max(fraction, 0), 1)
        for consumer in entry.consumers.values {
            consumer.continuation.yield(.progress(clamped))
        }
    }

    private func deliverReady(assetID: String, generation: UUID, url: URL) {
        guard var entry = entries[assetID], entry.generation == generation else { return }
        entry.task = nil
        entry.localURL = url
        let consumers = entry.consumers
        entry.consumers.removeAll()
        for (requestID, consumer) in consumers {
            requestToAsset.removeValue(forKey: requestID)
            let lease = AudioAssetLease(assetID: assetID, localURL: url)
            entry.leaseIDs.insert(lease.id)
            leaseToAsset[lease.id] = assetID
            consumer.continuation.yield(.progress(1))
            consumer.continuation.yield(.ready(lease))
            consumer.continuation.finish()
        }
        entries[assetID] = entry
        cleanupIfUnused(assetID: assetID, generation: generation, cancelTask: false)
    }

    private func finishFailure(assetID: String, generation: UUID, error: Error) {
        guard let entry = entries[assetID], entry.generation == generation else { return }
        for (requestID, consumer) in entry.consumers {
            requestToAsset.removeValue(forKey: requestID)
            consumer.continuation.finish(throwing: error)
        }
        entries.removeValue(forKey: assetID)
    }

    private func cleanupIfUnused(
        assetID: String,
        generation: UUID,
        cancelTask: Bool
    ) {
        guard let entry = entries[assetID],
              entry.generation == generation,
              entry.consumers.isEmpty,
              entry.leaseIDs.isEmpty else { return }
        if cancelTask {
            entry.task?.cancel()
        }
        entries.removeValue(forKey: assetID)
    }
}
