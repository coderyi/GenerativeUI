import Foundation
import os.log

/// Log levels for the GenerativeUI framework.
public enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    case none = 4

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Centralized logger for the GenerativeUI framework.
/// Supports structured log fields: screen_id, component_id, action_id, error_code.
public final class GenerativeUILogger {
    public static let shared = GenerativeUILogger()

    /// The minimum log level. Messages below this level are ignored.
    public var level: LogLevel = .info

    /// Optional external log handler. If set, logs are forwarded here instead of os_log.
    public var handler: ((LogLevel, String, [String: String]) -> Void)?

    private let osLog = OSLog(subsystem: "com.generativeui", category: "GenerativeUI")

    private init() {}

    public func debug(_ message: String, fields: [String: String] = [:]) {
        log(.debug, message: message, fields: fields)
    }

    public func info(_ message: String, fields: [String: String] = [:]) {
        log(.info, message: message, fields: fields)
    }

    public func warning(_ message: String, fields: [String: String] = [:]) {
        log(.warning, message: message, fields: fields)
    }

    public func error(_ message: String, fields: [String: String] = [:]) {
        log(.error, message: message, fields: fields)
    }

    private func log(_ logLevel: LogLevel, message: String, fields: [String: String]) {
        guard logLevel >= level else { return }

        if let handler = handler {
            handler(logLevel, message, fields)
            return
        }

        let fieldsString = fields.isEmpty ? "" : " " + fields.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        let formatted = "[\(logLevel)] \(message)\(fieldsString)"

        switch logLevel {
        case .debug:
            os_log("%{public}@", log: osLog, type: .debug, formatted)
        case .info:
            os_log("%{public}@", log: osLog, type: .info, formatted)
        case .warning:
            os_log("%{public}@", log: osLog, type: .default, formatted)
        case .error:
            os_log("%{public}@", log: osLog, type: .error, formatted)
        case .none:
            break
        }
    }
}
