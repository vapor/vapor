#if os(Linux)

import XCTest
import Testing
@testable import CacheTests
@testable import SessionsTests
@testable import ConfigsTests
@testable import VaporTests
@testable import TestingTests

XCTMain([
    // Cache
    testCase(MemoryCacheTests.allTests),

    // Config
    testCase(ConfigsTests.ConfigTests.allTests),
    testCase(MergeTests.allTests),
    testCase(EnvTests.allTests),
    testCase(CLIConfigTests.allTests),

    // Sessions
    testCase(SessionsProtocolTests.allTests),
    testCase(SessionTests.allTests),

    // Vapor
    testCase(ConfigIntegrationTests.allTests),
    testCase(VaporTests.ConfigTests.allTests),
    testCase(CodableTests.allTests),
    testCase(ConsoleTests.allTests),
    testCase(ContentTests.allTests),
    testCase(CORSMiddlewareTests.allTests),
    testCase(DropletTests.allTests),
    testCase(EnvironmentTests.allTests),
    testCase(EventTests.allTests),
    testCase(FileManagerTests.allTests),
    testCase(FileMiddlewareTests.allTests),
    testCase(FormDataTests.allTests),
    testCase(HashTests.allTests),
    testCase(LogTests.allTests),
    testCase(MiddlewareTests.allTests),
    testCase(ProcessTests.allTests),
    testCase(ProviderTests.allTests),
    testCase(ResourceTests.allTests),
    testCase(RoutingTests.allTests),
    testCase(RouteListTests.allTests),
    testCase(SessionsTests.allTests),

    // Testing
    testCase(ResponderTests.allTests),
])

#endif
