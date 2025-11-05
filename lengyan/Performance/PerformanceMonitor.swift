//
//  PerformanceMonitor.swift
//  Lengyan
//
//  Performance monitoring and optimization
//  Tracks view rendering, memory usage, and async operations
//

import Foundation
import os.log
import SwiftUI

// MARK: - Performance Metrics
struct PerformanceMetrics {
    let viewName: String
    let renderTime: TimeInterval
    let memoryUsage: Int
    let timestamp: Date

    var description: String {
        return """
        View: \(viewName)
        Render Time: \(String(format: "%.2f", renderTime * 1000))ms
        Memory: \(memoryUsage)KB
        Timestamp: \(timestamp)
        """
    }
}

// MARK: - Performance Monitor
@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()

    private let logger = os.Logger(subsystem: "org.fuxuan.lengyan", category: "performance")
    private var metrics: [PerformanceMetrics] = []
    private var isMonitoring = false

    // Performance thresholds
    private let renderTimeThreshold: TimeInterval = 0.016 // 16ms (60fps)
    private let memoryThreshold: Int = 50 * 1024 // 50MB

    private init() {}

    // MARK: - Monitoring Control

    func startMonitoring() {
        isMonitoring = true
        logger.info("Performance monitoring started")
    }

    func stopMonitoring() {
        isMonitoring = false
        logger.info("Performance monitoring stopped")
    }

    func reset() {
        metrics.removeAll()
        logger.info("Performance metrics reset")
    }

    // MARK: - View Performance Tracking

    func trackViewRender<T: View>(
        viewName: String,
        operation: @escaping () -> T,
        completion: @escaping (T) -> Void
    ) {
        guard isMonitoring else {
            completion(operation())
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getMemoryUsage()

        // Execute operation
        let result = operation()

        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = getMemoryUsage()

        let renderTime = endTime - startTime
        let memoryUsed = endMemory - startMemory

        let metric = PerformanceMetrics(
            viewName: viewName,
            renderTime: renderTime,
            memoryUsage: memoryUsed,
            timestamp: Date()
        )

        metrics.append(metric)

        // Log slow renders
        if renderTime > renderTimeThreshold {
            logger.warning("Slow view render detected: \(viewName) took \(renderTime * 1000)ms")
        }

        // Log high memory usage
        if memoryUsed > memoryThreshold {
            logger.warning("High memory usage detected: \(viewName) used \(memoryUsed)KB")
        }

        completion(result)
    }

    // MARK: - Async Operation Tracking

    func trackAsyncOperation<T>(
        operationName: String,
        operation: @escaping () async -> T,
        completion: @escaping (T) -> Void
    ) async {
        guard isMonitoring else {
            let result = await operation()
            completion(result)
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        let result = await operation()

        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime

        logger.info("Async operation completed: \(operationName) took \(executionTime * 1000)ms")

        completion(result)
    }

    // MARK: - Metrics Access

    func getAllMetrics() -> [PerformanceMetrics] {
        return metrics
    }

    func getMetrics(for viewName: String) -> [PerformanceMetrics] {
        return metrics.filter { $0.viewName == viewName }
    }

    func getSlowRenders() -> [PerformanceMetrics] {
        return metrics.filter { $0.renderTime > renderTimeThreshold }
    }

    func getHighMemoryUsage() -> [PerformanceMetrics] {
        return metrics.filter { $0.memoryUsage > memoryThreshold }
    }

    func getAverageRenderTime(for viewName: String) -> TimeInterval {
        let viewMetrics = getMetrics(for: viewName)
        guard !viewMetrics.isEmpty else { return 0 }

        let total = viewMetrics.reduce(0.0) { $0 + $1.renderTime }
        return total / Double(viewMetrics.count)
    }

    func getTotalMemoryUsage() -> Int {
        return metrics.reduce(0) { $0 + $1.memoryUsage }
    }

    // MARK: - Memory Utilities

    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Int(info.resident_size) / 1024 // Convert to KB
        } else {
            return 0
        }
    }

    // MARK: - Performance Report

    func generateReport() -> String {
        var report = "=== Performance Report ===\n\n"

        report += "Total Metrics: \(metrics.count)\n"
        report += "Slow Renders: \(getSlowRenders().count)\n"
        report += "High Memory Usage: \(getHighMemoryUsage().count)\n\n"

        // Group by view name
        let groupedMetrics = Dictionary(grouping: metrics) { $0.viewName }

        report += "--- Per View Statistics ---\n"
        for (viewName, viewMetrics) in groupedMetrics {
            let avgRenderTime = viewMetrics.reduce(0.0) { $0 + $1.renderTime } / Double(viewMetrics.count)
            let maxRenderTime = viewMetrics.map { $0.renderTime }.max() ?? 0
            let totalMemory = viewMetrics.reduce(0) { $0 + $1.memoryUsage }

            report += "\nView: \(viewName)\n"
            report += "  Count: \(viewMetrics.count)\n"
            report += "  Avg Render Time: \(String(format: "%.2f", avgRenderTime * 1000))ms\n"
            report += "  Max Render Time: \(String(format: "%.2f", maxRenderTime * 1000))ms\n"
            report += "  Total Memory: \(totalMemory)KB\n"
        }

        return report
    }
}

// MARK: - View Modifier for Performance Tracking

struct PerformanceTrackedView<T: View>: View {
    let viewName: String
    let operation: () -> T

    @StateObject private var monitor = PerformanceMonitor.shared

    var body: some View {
        let _ = monitor.trackViewRender(viewName: viewName, operation: operation) { _ in }
        return operation()
    }
}

extension View {
    func trackPerformance(_ viewName: String) -> some View {
        self.modifier(PerformanceTrackedViewModifier(viewName: viewName))
    }
}

struct PerformanceTrackedViewModifier: ViewModifier {
    let viewName: String
    @StateObject private var monitor = PerformanceMonitor.shared

    func body(content: Content) -> some View {
        content
            .onAppear {
                let startTime = CFAbsoluteTimeGetCurrent()
                let startMemory = ProcessInfo.processInfo.physicalMemory / 1024

                // Defer tracking to after render
                DispatchQueue.main.async {
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let renderTime = endTime - startTime

                    if renderTime > 0.016 {
                        os_log("Slow render detected: %s took %.2fms",
                               log: OSLog.performance,
                               type: .warning,
                               viewName,
                               renderTime * 1000)
                    }
                }
            }
    }
}

// MARK: - Memory Warning Observer

class MemoryWarningObserver: ObservableObject {
    @Published var memoryWarningCount = 0
    private var notificationObserver: NSObjectProtocol?

    init() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.memoryWarningCount += 1

            os_log("Memory warning received! Count: %d",
                   log: OSLog.performance,
                   type: .error,
                   self?.memoryWarningCount ?? 0)

            // Trigger cleanup
            Task {
                await PerformanceMonitor.shared.trackAsyncOperation(
                    operationName: "Memory Cleanup",
                    operation: { self?.cleanupMemory() },
                    completion: { _ in }
                )
            }
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func cleanupMemory() {
        // Clear caches
        URLCache.shared.removeAllCachedResponses()

        // Force garbage collection hint
        autoreleasepool {
            // Add other cleanup operations
        }
    }
}

// MARK: - OSLog Extension
extension OSLog {
    static let performance = OSLog(subsystem: "org.fuxuan.lengyan", category: "performance")
}

// MARK: - Performance Optimizer

class PerformanceOptimizer {
    static let shared = PerformanceOptimizer()

    private init() {}

    // MARK: - View Optimization

    func optimizeForList(
        count: Int,
        cellHeight: CGFloat,
        estimatedHeight: CGFloat? = nil
    ) {
        os_log("Optimizing list with %d items, cell height: %.2f",
               log: OSLog.performance,
               type: .info,
               count,
               cellHeight)
    }

    func optimizeForGrid(
        items: [String],
        columns: Int,
        rowHeight: CGFloat
    ) {
        os_log("Optimizing grid with %d items, %d columns",
               log: OSLog.performance,
               type: .info,
               items.count,
               columns)
    }

    // MARK: - Memory Optimization

    func shouldUseLazyVStack(count: Int) -> Bool {
        return count > 100 // Use LazyVStack for large lists
    }

    func shouldUseLazyHStack(count: Int) -> Bool {
        return count > 50 // Use LazyHStack for large horizontal lists
    }

    // MARK: - Image Optimization

    func getOptimalImageSize(for availableSpace: CGSize) -> CGSize {
        // Return scaled size to reduce memory usage
        let maxDimension: CGFloat = 1000 // Max 1000px
        let scale = min(availableSpace.width, availableSpace.height) / maxDimension
        return availableSpace.applying(CGAffineTransform(scaleX: min(scale, 1), y: min(scale, 1)))
    }
}

// MARK: - Performance Optimized View Modifiers

struct LazyListModifier: ViewModifier {
    let count: Int
    let orientation: Axis

    func body(content: Content) -> some View {
        if PerformanceOptimizer.shared.shouldUseLazyVStack(count: count) && orientation == .vertical {
            LazyVStack {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    func lazyList(count: Int, orientation: Axis = .vertical) -> some View {
        self.modifier(LazyListModifier(count: count, orientation: orientation))
    }
}

struct MemoryEfficientImage: View {
    let url: URL?
    let contentMode: ContentMode

    @StateObject private var imageLoader = ImageLoader()

    var body: some View {
        Group {
            if let image = imageLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(contentMode: contentMode)
                    .onAppear {
                        Task {
                            await imageLoader.load(from: url)
                        }
                    }
            }
        }
    }
}

// MARK: - Image Loader

@MainActor
class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    func load(from url: URL?) async {
        guard let url = url else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let loadedImage = UIImage(data: data) {
                self.image = loadedImage
            }
        } catch {
            os_log("Failed to load image: %s",
                   log: OSLog.performance,
                   type: .error,
                   error.localizedDescription)
        }
    }
}
