#if os(Linux)

import XCTest
@testable import VaporTestSuite

XCTMain([
    testCase(ApplicationTests.allTests),
    testCase(ConfigTests.allTests),
    testCase(ControllerTests.allTests),
    testCase(EnvironmentTests.allTests),
    testCase(HashTests.allTests),
    testCase(LogTests.allTests),
    testCase(MemorySessionDriverTests.allTests),
    testCase(ResponseTests.allTests),
    testCase(ProcessTests.allTests),
    testCase(RouterTests.allTests),
    testCase(RouteTests.allTests),
    testCase(QueryParameterTests.allTests),
    testCase(SessionTests.allTests),
    testCase(TypedRouteTests.allTests),
    testCase(HTTPStreamTests.allTests)
])

#endif
