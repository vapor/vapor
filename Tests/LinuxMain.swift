#if os(Linux)

import XCTest
@testable import CoreTests
@testable import CryptoTests
@testable import DebuggingTests
@testable import HTTPTests
@testable import LeafTests
@testable import MySQLTests
@testable import RoutingTests
@testable import ServiceTests
@testable import TCPTests
@testable import VaporTests
@testable import WebSocketTests

XCTMain([
    // Core
    testCase(FutureTests.allTests),
    testCase(StreamTests.allTests),

    // Crypto
    testCase(Base64Tests.allTests),
    testCase(MD5Tests.allTests),
    testCase(PBKDF2Tests.allTests),
    testCase(SHA1Tests.allTests),
    testCase(SHA2Tests.allTests),

    // Debugging
    testCase(FooErrorTests.allTests),
    testCase(GeneralTests.allTests),
    testCase(TraceableTests.allTests),

    // HTTP
    testCase(MiddlewareTests.allTests),
    testCase(ParserTests.allTests),
    testCase(SerializerTests.allTests),

    // Leaf
    testCase(LeafTests.allTests),

    // MySQL
    testCase(MySQLTests.allTests),

    // Routing
    testCase(RouterTests.allTests),

    // Service
    testCase(ConfigTests.allTests),
    testCase(ServiceTests.allTests),

    // TCP
    testCase(SocketTests.allTests),

    // Vapor
    testCase(ApplicationTests.allTests),

    // WebSocket
    testCase(WebSocketTests.allTests),
])

#endif
