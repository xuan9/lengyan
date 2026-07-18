import Foundation

/// 阅读停留计时器 — 过滤打开后立即返回的误触。
/// 明确的翻页/导航由阅读控制器立即保存；此阈值只处理无交互阅读。
struct ReadingStayTimer {
    static let defaultThreshold: TimeInterval = 3

    private var activeSince: Date?
    private var accumulatedActiveTime: TimeInterval = 0
    private let threshold: TimeInterval

    init(threshold: TimeInterval = ReadingStayTimer.defaultThreshold) {
        self.threshold = threshold
    }

    mutating func start(at date: Date = Date()) {
        guard activeSince == nil else { return }
        activeSince = date
    }

    var isValidReading: Bool {
        isValidReading(at: Date())
    }

    mutating func pause(at date: Date = Date()) {
        guard let activeSince else { return }
        accumulatedActiveTime += max(date.timeIntervalSince(activeSince), 0)
        self.activeSince = nil
    }

    func isValidReading(at date: Date) -> Bool {
        activeTime(at: date) >= threshold
    }

    func remainingTime(at date: Date = Date()) -> TimeInterval {
        max(threshold - activeTime(at: date), 0)
    }

    private func activeTime(at date: Date) -> TimeInterval {
        let currentActiveTime = activeSince.map {
            max(date.timeIntervalSince($0), 0)
        } ?? 0
        return accumulatedActiveTime + currentActiveTime
    }
}

/// Gates the first persisted position in a reader session. Passive viewing is
/// confirmed after the foreground threshold; an explicit page/navigation action
/// can commit immediately. Once confirmed, later lifecycle checkpoints always
/// persist the current position.
final class ReadingCheckpointGate {
    private var timer: ReadingStayTimer
    private var scheduledCommit: DispatchWorkItem?
    private var scheduleGeneration = 0
    private var isResumed = false
    private(set) var isConfirmed = false

    init(threshold: TimeInterval = ReadingStayTimer.defaultThreshold) {
        timer = ReadingStayTimer(threshold: threshold)
    }

    func resume(onThreshold: @escaping () -> Void) {
        guard !isResumed else { return }
        isResumed = true
        guard !isConfirmed else { return }
        timer.start()
        scheduleThresholdCommit(onThreshold)
    }

    func pause(onCheckpoint: () -> Void) {
        guard isResumed else { return }
        isResumed = false
        timer.pause()
        cancelScheduledCommit()
        guard isConfirmed || timer.isValidReading else { return }
        isConfirmed = true
        onCheckpoint()
    }

    func commit(_ checkpoint: () -> Void) {
        timer.pause()
        cancelScheduledCommit()
        isConfirmed = true
        checkpoint()
    }

    private func scheduleThresholdCommit(_ checkpoint: @escaping () -> Void) {
        cancelScheduledCommit()
        let delay = timer.remainingTime()
        guard delay > 0 else {
            isConfirmed = true
            timer.pause()
            checkpoint()
            return
        }

        scheduleGeneration += 1
        let generation = scheduleGeneration
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  generation == self.scheduleGeneration,
                  !self.isConfirmed else { return }
            self.scheduledCommit = nil
            if self.timer.isValidReading {
                self.timer.pause()
                self.isConfirmed = true
                checkpoint()
            } else {
                // Dispatch timers should not fire early, but reschedule from the
                // measured foreground time if the runtime does so.
                self.scheduleThresholdCommit(checkpoint)
            }
        }
        scheduledCommit = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelScheduledCommit() {
        scheduleGeneration += 1
        scheduledCommit?.cancel()
        scheduledCommit = nil
    }
}
