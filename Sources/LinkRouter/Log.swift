import Foundation
import os

/// Unified-log wrapper. Read with:
///   log stream --predicate 'subsystem == "io.github.macrosak.linkrouter"'
enum Log {
    private static let logger = Logger(subsystem: "io.github.macrosak.linkrouter", category: "app")

    static func info(_ message: String) { logger.notice("\(message, privacy: .public)") }
    static func error(_ message: String) { logger.error("\(message, privacy: .public)") }

    /// Milliseconds since `start` (a `DispatchTime.now()` reading).
    static func ms(since start: DispatchTime) -> String {
        String(format: "%.1fms", Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
    }
}
