#if os(Linux)

import XCTest
@testable import VaporTestSuite

XCTMain([
    testCase(ApplicationTests.allTests),
    testCase(ConfigTests.allTests),
    testCase(ConsoleTests.allTests),
    testCase(ContentTests.allTests),
    testCase(ControllerTests.allTests),
    testCase(EnvironmentTests.allTests),
    testCase(EventTests.allTests),
    testCase(HashTests.allTests),
    testCase(HTTPBodyTests.allTests),
    testCase(HTTPHeadersTests.allTests),
    testCase(HTTPRequestTests.allTests),
    testCase(HTTPStreamTests.allTests),
    testCase(HTTPVersionTests.allTests),
    testCase(LocalizationTests.allTests),
    testCase(LogTests.allTests),
    testCase(MemorySessionDriverTests.allTests),
    testCase(PercentEncodingTests.allTests),
    testCase(ProcessTests.allTests),
    testCase(PromiseTests.allTests),
    testCase(ResponseTests.allTests),
    testCase(RouterTests.allTests),
    testCase(RouteTests.allTests),
    testCase(SessionTests.allTests),
    testCase(TypedRouteTests.allTests),
    testCase(UnsignedIntegerChunkingTests.allTests),
    testCase(URISerializationTests.allTests),
    testCase(UtilityTests.allTests),
    testCase(ValidationConvenienceTests.allTests),
    testCase(ValidationCountTests.allTests),
    testCase(ValidationTests.allTests),
    testCase(ValidationUniqueTests.allTests),
    testCase(WebSocketSerializationTests.allTests),
    testCase(WebSocketKeyTests.allTests),
])

#endif
