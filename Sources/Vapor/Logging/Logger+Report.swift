import Foundation
import Logging

extension Logger {
    /// Reports an `Error` to this `Logger`.
    ///
    /// - parameters:
    ///     - error: `Error` to log.
    public func report(
        error: Error,
        metadata: @autoclosure () -> Logger.Metadata? = nil,
        source: @autoclosure() -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        let errorSource: ErrorSource?
        let reason: String
        let level: Logger.Level
        switch error {
        case let debuggable as DebuggableError:
            if self.logLevel <= .trace {
                reason = debuggable.debuggableHelp(format: .long)
            } else {
                reason = debuggable.debuggableHelp(format: .short)
            }
            errorSource = debuggable.source
            level = debuggable.logLevel
        case let abort as AbortError:
            reason = abort.reason
            errorSource = nil
            level = .warning
        default:
            reason = String(reflecting: error)
            errorSource = nil
            level = .warning
        }

        self.log(
            level: level,
            .init(stringLiteral: reason),
            metadata: metadata(),
            source: source(),
            file: errorSource?.file ?? file,
            function: errorSource?.function ?? function,
            line: numericCast(errorSource?.line ?? line)
        )
    }
}
