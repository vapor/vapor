import Vapor
import XCTest

func triggerError() throws {
    throw TestError.foo(reason: "So we can test stuff")
}


class TraceableTests: XCTestCase {
    func testPrintable() throws {
        do {
            try triggerError()
        } catch {
            print(error)
            print()
            print()
            debugPrint(error)
        }
    }
}
