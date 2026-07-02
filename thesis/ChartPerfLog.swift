import Foundation
import os

/// Lightweight timing instrumentation for the chart rendering / loading hot paths.
///
/// Everything funnels through `os.Logger` (subsystem `com.thesis.charts`,
/// category `perf`) so the measurements show up in the Xcode console and can be
/// filtered with the `GetConsoleOutput` tool using the pattern `⏱` or `chart-perf`.
///
/// This is diagnostic scaffolding: it adds a `Logger.debug` line (and an
/// Instruments signpost interval) around the work we suspect is slow so we can
/// see real durations and, just as importantly, how *often* each path runs.
enum ChartPerf {
    static let log = Logger(subsystem: "com.thesis.charts", category: "perf")
    static let signposter = OSSignposter(logger: log)

    /// Measure a synchronous block, logging its duration in milliseconds.
    @inline(__always)
    static func measure<T>(_ name: String, detail: @autoclosure () -> String = "", _ body: () throws -> T) rethrows -> T {
        let state = signposter.beginInterval("chart-perf", id: signposter.makeSignpostID())
        let start = ContinuousClock().now
        let result = try body()
        let elapsed = ContinuousClock().now - start
        signposter.endInterval("chart-perf", state)
        let d = detail()
        log.debug("⏱ \(name, privacy: .public) \(d, privacy: .public) — \(Self.ms(elapsed), privacy: .public) ms")
        return result
    }

    /// Measure an async block, logging its duration in milliseconds.
    @inline(__always)
    static func measureAsync<T>(_ name: String, detail: @autoclosure () -> String = "", _ body: () async throws -> T) async rethrows -> T {
        let start = ContinuousClock().now
        let result = try await body()
        let elapsed = ContinuousClock().now - start
        let d = detail()
        log.debug("⏱ \(name, privacy: .public) \(d, privacy: .public) — \(Self.ms(elapsed), privacy: .public) ms")
        return result
    }

    /// Log a one-off event (e.g. "attachment view created") with optional detail.
    static func event(_ name: String, _ detail: @autoclosure () -> String = "") {
        let d = detail()
        log.debug("• \(name, privacy: .public) \(d, privacy: .public)")
    }

    private static func ms(_ duration: Duration) -> String {
        let seconds = Double(duration.components.seconds)
        let attos = Double(duration.components.attoseconds)
        return String(format: "%.2f", seconds * 1000 + attos / 1e15)
    }
}
