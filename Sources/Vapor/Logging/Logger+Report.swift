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
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        let source: ErrorSource?
        let reason: String
        let level: Logger.Level
        switch error {
        case let debuggable as DebuggableError:
            if self.logLevel <= .trace {
                reason = debuggable.debuggableHelp(format: .long)
            } else {
                reason = debuggable.debuggableHelp(format: .short)
            }
            source = debuggable.source
            level = debuggable.logLevel
        case let abort as AbortError:
            reason = abort.reason
            source = nil
            level = .warning
        default:
            reason = String(reflecting: error)
            source = nil
            level = .warning
        }

        self.log(
            level: level,
            .init(stringLiteral: reason),
            metadata: metadata(),
            file: source?.file ?? file,
            function: source?.function ?? function,
            line: numericCast(source?.line ?? line)
        )
    }
}
