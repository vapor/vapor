#if os(Linux)

import XCTest
@testable import CacheTests
@testable import CookiesTests
@testable import VaporTests
@testable import RoutingTests
@testable import HTTPRoutingTests

XCTMain([
    // Cache
    testCase(FluentCacheTests.allTests),
    testCase(MemoryCacheTests.allTests),

    // Cookies
    testCase(CookiesTests.allTests),
    testCase(CookieTests.allTests),
    testCase(HTTPTests.allTests),
    testCase(ParsingTests.allTests),
    testCase(SerializingTests.allTests),

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
    testCase(RoutingTests.allTests),
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
