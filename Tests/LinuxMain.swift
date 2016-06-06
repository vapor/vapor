#if os(Linux)

import XCTest
@testable import VaporTestSuite

XCTMain([
    testCase(ApplicationTests.allTests),
    testCase(ConfigTests.allTests),
    testCase(ConsoleTests.allTests),
    testCase(ControllerTests.allTests),
    testCase(EnvironmentTests.allTests),
    testCase(EventTests.allTests),
    testCase(HashTests.allTests),
    testCase(HTTPStreamTests.allTests),
    testCase(LocalizationTests.allTests),
    testCase(LogTests.allTests),
    testCase(MemorySessionDriverTests.allTests),
    testCase(ProcessTests.allTests),
    testCase(ResponseTests.allTests),
    testCase(RequestTests.allTests),
    testCase(RouterTests.allTests),
    testCase(RouteTests.allTests),
    testCase(SessionTests.allTests),
    testCase(TypedRouteTests.allTests),
    testCase(ValidationConvenienceTests.allTests),
    testCase(ValidationCountTests.allTests),
    testCase(ValidationTests.allTests),
    testCase(ValidationUniqueTests.allTests),
])

#endif
