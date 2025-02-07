import Testing
import Foundation

public enum XCTVaporContext {
    @TaskLocal public static var emitWarningIfCurrentTestInfoIsAvailable: Bool?

    /// Throws an error if the test is being run in a swift-testing context.
    /// This is not fool-proof. Running tests in detached Tasks will bypass this detection.
    /// But don't rely on that. That loophole will be fixed in a future swift-testing version.
    static func warnIfInSwiftTestingContext(
        file: StaticString,
        line: UInt
    ) {
        let shouldWarn = XCTVaporContext.emitWarningIfCurrentTestInfoIsAvailable ?? true
        var isInSwiftTesting: Bool { Test.current != nil }
        if shouldWarn, isInSwiftTesting {
            print("""
            🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻
            XCTVapor function triggered in a swift-testing context.
            This will result in test failures not being reported.
            Use 'app.testable()' in XCTest tests, and 'app.testing()' in swift-testing ones.
            Use `XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) { /* Execute your tests here */ }` to avoid this warning.
            Location: \(file):\(line)
            🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺
            """)
            fflush(stdout)
        }
    }
}
