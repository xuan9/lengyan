//
//  FeedbackService.swift
//  lengyan
//
//  反馈提交服务 — Cloudflare Worker + D1
//

import Foundation

struct FeedbackService {
    private static let legacyDraftKey = "feedbackDraft"
    private static let serviceBaseURL = URL(
        string: "https://lengyan-feedback.dhyana9.workers.dev"
    )!
    static let maximumContentLength = 2_000

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    enum SubmissionError: Error, Equatable {
        case invalidRequest
        case transportFailed
        case contentTooLong
        case rateLimited
        case serverRejected
    }

    struct FeedbackRequest {
        let content: String
    }

    private struct FeedbackResponse: Decodable {
        let ok: Bool
        let reference: String
    }

    static func normalizedContent(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Older releases persisted feedback drafts in UserDefaults. Consume that
    /// value once so an upgrade can keep the user's text in memory while
    /// immediately ending the unintended long-term storage.
    static func consumeLegacyDraft(from userDefaults: UserDefaults = .standard) -> String {
        let draft = userDefaults.string(forKey: legacyDraftKey) ?? ""
        userDefaults.removeObject(forKey: legacyDraftKey)
        return draft
    }

    static func submit(
        _ request: FeedbackRequest,
        completion: @escaping (Result<String, SubmissionError>) -> Void
    ) {
        let content = normalizedContent(request.content)
        guard !content.isEmpty,
              content.count <= maximumContentLength else {
            completion(.failure(SubmissionError.invalidRequest))
            return
        }

        var urlRequest = URLRequest(url: serviceBaseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 15

        let body = makePayload(
            content: content,
            appVersion: currentAppVersion()
        )

        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(SubmissionError.invalidRequest))
            return
        }

        session.dataTask(with: urlRequest) { data, response, error in
            if error != nil {
                completion(.failure(SubmissionError.transportFailed))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(SubmissionError.serverRejected))
                return
            }
            completion(submissionResult(statusCode: http.statusCode, data: data))
        }.resume()
    }

    /// Keeps status handling deterministic and testable without a live service.
    static func submissionResult(
        statusCode: Int,
        data: Data?
    ) -> Result<String, SubmissionError> {
        switch statusCode {
        case 413:
            return .failure(.contentTooLong)
        case 429:
            return .failure(.rateLimited)
        case 200 ... 299:
            guard let data,
                  let responseBody = try? JSONDecoder().decode(FeedbackResponse.self, from: data),
                  responseBody.ok,
                  let reference = normalizedReference(responseBody.reference) else {
                return .failure(.serverRejected)
            }
            return .success(reference)
        default:
            return .failure(.serverRejected)
        }
    }

    /// Pure payload builder kept internal so the exact minimization contract can be unit tested.
    static func makePayload(
        content: String,
        appVersion: String
    ) -> [String: String] {
        [
            "content": content,
            "appVersion": appVersion,
        ]
    }

    private static func currentAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// Accept only the exact reference format generated and indexed by the
    /// Worker. A broader client-side format could show a "successful" reference
    /// that the administrator lookup can never find.
    static func normalizedReference(_ value: String) -> String? {
        let reference = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowedCharacters = CharacterSet(charactersIn: "0123456789abcdef")
        guard reference.count == 32,
              reference.unicodeScalars.allSatisfy(allowedCharacters.contains) else {
            return nil
        }
        return reference
    }
}
