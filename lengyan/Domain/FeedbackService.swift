//
//  FeedbackService.swift
//  lengyan
//
//  反馈提交服务 — Cloudflare Worker + D1
//

import UIKit

struct FeedbackService {
    private static let endpoint = "https://lengyan-feedback.dhyana9.workers.dev"
    private static let apiKey = "7e6c1216eb9a61b9de68ae86d07de92836dec07a33a256ee"

    struct FeedbackRequest {
        let content: String
    }

    static func submit(_ request: FeedbackRequest, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "FeedbackService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的服务地址"])))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        urlRequest.timeoutInterval = 15

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        let body: [String: String] = [
            "content": request.content,
            "type": "feedback",
            "device": deviceModel(),
            "os": "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            "appVersion": appVersion(),
            "deviceId": deviceId,
        ]

        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                completion(.failure(NSError(domain: "FeedbackService", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "服务器错误"])))
                return
            }
            completion(.success(()))
        }.resume()
    }

    private static func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    private static func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version).\(build)"
    }
}
