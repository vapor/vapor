#if compiler(>=6.0)
import Testing
#endif

public enum XCTVaporContext {
#if compiler(>=6.0)
    @TaskLocal public static var emitWarningIfCurrentTestInfoIsAvailable: Bool?
#endif

    /// Throws an error if the test is being run in a swift-testing context.
    /// This is not fool-proof. Running tests in detached Tasks will bypass this detection.
    /// But don't rely on that. That loophole will be fixed in a future swift-testing version.
    static func warnIfInSwiftTestingContext(
        file: StaticString,
        line: UInt
    ) {
#if compiler(>=6.0)
        let shouldWarn = XCTVaporContext.emitWarningIfCurrentTestInfoIsAvailable ?? true
        let isInSwiftTesting = Test.current != nil
        if shouldWarn, isInSwiftTesting {
            print("""
            🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻🔻
            XCTVapor function triggered in a swift-testing context.
            This will result in test failures not being reported.
            Use 'app.testable()' instead of 'app.testing()' in XCTest tests.
            Use `XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) { /* Execute your tests here */ }` to avoid this warning.
            Location: \(file):\(line)
            🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺🔺
            """)
            fflush(stdout)
        }
#endif
    }
}
