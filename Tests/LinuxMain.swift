#if os(Linux)

import XCTest
@testable import CommandTests
@testable import ConsoleTests
@testable import CryptoTests
@testable import DebuggingTests
@testable import FluentTests
@testable import FluentMySQLTests
@testable import HTTPTests
@testable import HTTP2Tests
@testable import JWTTests
@testable import LeafTests
@testable import MultipartTests
@testable import MySQLTests
@testable import PufferfishTests
@testable import RandomTests
@testable import RedisTests
@testable import RoutingTests
@testable import ServiceTests
@testable import TLSTests
@testable import TCPTests
@testable import VaporTests
@testable import WebSocketTests

XCTMain([
    /// Console & Commands
    testCase(ConsoleTests.allTests),
    testCase(CommandTests.allTests),
  
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

    // Fluent
    testCase(SQLiteBenchmarkTests.allTests),
    testCase(FluentMySQLTests.allTests),

    // HTTP
    testCase(MiddlewareTests.allTests),
    testCase(ParserTests.allTests),
    testCase(SerializerTests.allTests),

    // HTTP2
    testCase(HTTP2Tests.allTests),
    testCase(HPACKTests.allTests),

    // JWT
    testCase(JWSTests.allTests),

    // Leaf
    testCase(LeafTests.allTests),
    testCase(LeafEncoderTests.allTests),

    // Multipart
    testCase(MultipartTests.allTests),

    // MySQL
    testCase(MySQLTests.allTests),

    // Pufferfish
    testCase(PufferfishTests.allTests),
  
    // Random
    testCase(RandomTests.allTests),

    // Redis
    testCase(RedisTests.allTests),
    
    // Routing
    testCase(RouterTests.allTests),

    // Service
    testCase(ConfigTests.allTests),
    testCase(ServiceTests.allTests),

    // TLS
    testCase(TLSTests.SSLTests.allTests),

    // TCP
    testCase(TCPTests.SocketsTests.allTests),

    // Vapor
    testCase(ApplicationTests.allTests),

    // WebSocket
    testCase(WebSocketTests.allTests),
])

#endif
