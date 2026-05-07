import Foundation

/// 阅读停留计时器 — 停留超过阈值才视为有效阅读
struct ReadingStayTimer {
    private var appearTime: Date?
    private let threshold: TimeInterval

    init(threshold: TimeInterval = 10) {
        self.threshold = threshold
    }

    mutating func start() {
        appearTime = Date()
    }

    var isValidReading: Bool {
        guard let appearTime else { return false }
        return Date().timeIntervalSince(appearTime) > threshold
    }
}
