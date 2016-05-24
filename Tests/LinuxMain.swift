#if os(Linux)

import XCTest
@testable import VaporTestSuite

XCTMain([
    testCase(ApplicationTests.allTests),
    testCase(ConfigTests.allTests),
    testCase(ControllerTests.allTests),
    testCase(EnvironmentTests.allTests),
	testCase(EventTests.allTests),
    testCase(HashTests.allTests),
	testCase(HTTPStreamTests.swift),
    testCase(LogTests.allTests),
    testCase(MemorySessionDriverTests.allTests),
	testCase(PerformanceTests.swift),
    testCase(ProcessTests.allTests),
    testCase(QueryParameterTests.allTests),
    testCase(ResponseTests.allTests),
    testCase(RouterTests.allTests),
    testCase(RouteTests.allTests),
    testCase(SessionTests.allTests),
	testCase(TestHTTPStream.allTests),
	testCase(TypedRouteTests.allTests),
	testCase(ValidationConvenienceTests.allTests),
	testCase(ValidationCountTests.allTests),
	testCase(ValidationTests.allTests),
	testCase(ValidationUniqueTests.allTests)
])

#endif
