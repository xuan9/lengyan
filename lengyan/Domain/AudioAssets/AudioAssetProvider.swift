//
//  AudioAssetProvider.swift
//  lengyan
//

import Foundation

protocol AudioAssetProvider: Sendable {
    nonisolated var backendKind: AudioAssetBackendKind { get }

    func request(
        _ asset: AudioAssetDescriptor,
        intent: AudioAssetIntent
    ) async -> AudioAssetRequestHandle

    func promote(requestID: UUID) async
    func cancel(requestID: UUID) async
    func release(_ lease: AudioAssetLease) async
    func evict(assetID: String) async throws -> AudioAssetEvictionResult
    func shutdown() async
}
extension AsyncThrowingStream where Element == AudioAssetEvent, Failure == Error {
    static func audioAssetStream() -> (
        stream: AsyncThrowingStream<AudioAssetEvent, Error>,
        continuation: AsyncThrowingStream<AudioAssetEvent, Error>.Continuation
    ) {
        var captured: AsyncThrowingStream<AudioAssetEvent, Error>.Continuation?
        let stream = AsyncThrowingStream<AudioAssetEvent, Error> { continuation in
            captured = continuation
        }
        return (stream, captured!)
    }
}
