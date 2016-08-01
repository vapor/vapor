#if os(Linux)

import XCTest
@testable import VaporTestSuite
@testable import RoutingTestSuite
@testable import HTTPRoutingTestSuite

XCTMain([
    // Vapor
    testCase(ConfigTests.allTests),
    testCase(ConsoleTests.allTests),
    testCase(ContentTests.allTests),
    testCase(CookieTests.allTests),
    testCase(DataSplitTests.allTests),
    testCase(DropletTests.allTests),
    testCase(EnvironmentTests.allTests),
    testCase(EventTests.allTests),
    testCase(FileManagerTests.allTests),
    testCase(HashTests.allTests),
    testCase(LocalizationTests.allTests),
    testCase(LogTests.allTests),
    testCase(MemorySessionDriverTests.allTests),
    testCase(ProcessTests.allTests),
    testCase(ProviderTests.allTests),
    testCase(ResourceTests.allTests),
    testCase(ResponseTests.allTests),
    testCase(SessionTests.allTests),
    testCase(ValidationConvenienceTests.allTests),
    testCase(ValidationCountTests.allTests),
    testCase(ValidationTests.allTests),
    testCase(ValidationUniqueTests.allTests),

    // Routing
    testCase(BranchTests.allTests),
    testCase(RouteBuilderTests.allTests),
    testCase(RouteCollectionTests.allTests),
    testCase(RouterTests.allTests),
    testCase(RouteTests.allTests),

    // HTTPRouting
    testCase(AddTests.allTests),
    testCase(GroupedTests.allTests),
    testCase(GroupTests.allTests),
])

#endif
