import NIOConcurrencyHelpers
import Vapor

/// We recommend configuring this in your XCTest class's `override func setUp()`.
public var app: (@Sendable () throws -> Application)! {
    get {
        appBox.withLockedValue({ $0 })
    }
    set {
        appBox.withLockedValue { $0 = newValue }
    }
}
private let appBox: NIOLockedValueBox<(@Sendable () throws -> Application)?> = .init(nil)
