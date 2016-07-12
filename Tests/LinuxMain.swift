#if os(Linux)

import XCTest
@testable import VaporTestSuite

XCTMain([
    testCase(DropletTests.allTests),
    testCase(ConfigTests.allTests),
    testCase(ConsoleTests.allTests),
    testCase(ContentTests.allTests),
    testCase(ControllerTests.allTests),
    testCase(DataSplitTests.allTests),
    testCase(EnvironmentTests.allTests),
    testCase(EventTests.allTests),
    testCase(FileManagerTests.allTests),
    testCase(HashTests.allTests),
    testCase(LocalizationTests.allTests),
    testCase(LogTests.allTests),
    testCase(MemorySessionDriverTests.allTests),
    testCase(ProcessTests.allTests),
    testCase(ResponseTests.allTests),
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
