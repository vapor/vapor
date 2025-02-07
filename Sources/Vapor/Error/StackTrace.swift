import Foundation
import NIOConcurrencyHelpers

@available(*, deprecated, message: "Captured stack traces are no longer supported by Vapor")
extension Optional where Wrapped == StackTrace {
    public static func capture(skip: Int = 0) -> Self { StackTrace() }
}

@available(*, deprecated, message: "Captured stack traces are no longer supported by Vapor")
public struct StackTrace: Sendable {
    public struct Frame: Sendable {
        public var file: String
        public var function: String
    }
    public static var isCaptureEnabled: Bool {
        get { false }
        set {}
    }
    public static func capture(skip: Int = 0) -> Self? { nil }
    public var frames: [Frame] { [] }
    public func description(max: Int = 16) -> String { "" }
}

@available(*, deprecated, message: "Captured stack traces are no longer supported by Vapor")
extension StackTrace: CustomStringConvertible {
    public var description: String { self.description() }
}

@available(*, deprecated, message: "Captured stack traces are no longer supported by Vapor")
extension StackTrace.Frame: CustomStringConvertible {
    public var description: String { "\(self.file) \(self.function)" }
}

@available(*, deprecated, message: "Captured stack traces are no longer supported by Vapor")
extension Collection where Element == StackTrace.Frame, Index: BinaryInteger {
    var readable: String { "" }
}
