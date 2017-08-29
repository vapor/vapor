#if os(Linux)

import XCTest
import CoreTests
import CryptoTests
import DebuggingTests
import HTTPTests
import LeafTests
import MySQLTests
import RoutingTests
import ServiceTests
import TCPTests
import VaporTests
import WebSocketTests

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
