#if os(Linux)

import XCTest
@testable import VaporTests
@testable import TestingTests

XCTMain([
    // Vapor
    testCase(ApplicationTests.allTests),
    testCase(ApplicationTestingTests.allTests),
])

#endif
