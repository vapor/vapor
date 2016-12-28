#if os(Linux)

import XCTest
@testable import CacheTests
@testable import SessionsTests
@testable import SettingsTests
@testable import CookiesTests
@testable import VaporTests

XCTMain([
    // Cache
    testCase(FluentCacheTests.allTests),
    testCase(MemoryCacheTests.allTests),

    // Config
    testCase(ConfigTests.allTests),
    testCase(MergeTests.allTests),
    testCase(EnvTests.allTests),
    testCase(CLIConfigTests.allTests),

    // Cookies
    testCase(CookiesTests.allTests),
    testCase(CookieTests.allTests),
    testCase(HTTPTests.allTests),
    testCase(ParsingTests.allTests),
    testCase(SerializingTests.allTests),

    // Sessions
    testCase(SessionsProtocolTests.allTests),
    testCase(SessionTests.allTests),

    // Vapor
    testCase(ConfigIntegrationTests.allTests),
    testCase(ConsoleTests.allTests),
    testCase(ContentTests.allTests),
    testCase(CookieTests.allTests),
    testCase(CORSMiddlewareTests.allTests),
    testCase(DataSplitTests.allTests),
    testCase(DropletTests.allTests),
    testCase(EnvironmentTests.allTests),
    testCase(EventTests.allTests),
    testCase(FileManagerTests.allTests),
    testCase(FileMiddlewareTests.allTests),
    testCase(HashTests.allTests),
    testCase(LocalizationTests.allTests),
    testCase(LogTests.allTests),
    testCase(MiddlewareTests.allTests),
    testCase(ProcessTests.allTests),
    testCase(ProviderTests.allTests),
    testCase(ResourceTests.allTests),
    testCase(RoutingTests.allTests),
    testCase(SessionsTests.allTests),
    testCase(ValidationConvenienceTests.allTests),
    testCase(ValidationCountTests.allTests),
    testCase(ValidationTests.allTests),
    testCase(ValidationUniqueTests.allTests),
])

#endif
