import Foundation
import Logging

extension Logger {
    /// Reports an `Error` to this `Logger`.
    ///
    /// - parameters:
    ///     - error: `Error` to log.
    public func report(
        error: Error,
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
        case let encoding as EncodingError:
            reason = "\(encoding)"
            source = nil
            level = .warning
        case let decoding as DecodingError:
            reason = "\(decoding)"
            source = nil
            level = .warning
        case let localized as LocalizedError:
            reason = localized.localizedDescription
            source = nil
            level = .warning
        case let convertible as CustomStringConvertible:
            reason = convertible.description
            source = nil
            level = .warning
        default:
            reason = "\(error)"
            source = nil
            level = .warning
        }
        
        self.log(
            level: level,
            .init(stringLiteral: reason),
            file: source?.file ?? file,
            function: source?.function ?? function,
            line: numericCast(source?.line ?? line)
        )
    }
}
