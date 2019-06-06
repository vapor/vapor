import XCTVapor

final class MiddlewareTests: XCTestCase {
     func testSecurityHeadersMiddleware() throws {
         let app = Application.create(routes: { r, c in

             // Default Configuration
             r.grouped(SecurityHeadersMiddleware()).get("default") { req -> String in
                 return "test"
             }

             // Custom Configuration
             r.grouped(SecurityHeadersMiddleware(configuration: .init(strictTransportSecurity: .init(maxAge: 3600), contentSecurityPolicy: [.defaultSrc("'self'")]))).get("custom") { req -> String in
                 return "test"
             }

             // Custom Configuration, with preload option enabled and subdomains excluded
             r.grouped(SecurityHeadersMiddleware(configuration: .init(strictTransportSecurity: .init(maxAge: 3600, policy: .preload), contentSecurityPolicy: [.defaultSrc("'self'")]))).get("preload") { req -> String in
                 return "test"
             }

             // Custom Configuration, with preload option enabled and subdomains included
             r.grouped(SecurityHeadersMiddleware(configuration: .init(strictTransportSecurity: .init(maxAge: 3600, policy: .both), contentSecurityPolicy: [.defaultSrc("'self'")]))).get("subdomains") { req -> String in
                 return "test"
             }
         })
         defer { app.shutdown() }

         try app.testable().inMemory().test(.GET, "/default") { res in
             XCTAssertEqual(res.headers.firstValue(name: .xssProtection), "1; mode=block")
             XCTAssertEqual(res.headers.firstValue(name: .xContentTypeOptions), "nosniff")
             XCTAssertEqual(res.headers.firstValue(name: .xFrameOptions), "sameorigin")
         }

         try app.testable().inMemory().test(.GET, "/custom") { res in
             XCTAssertEqual(res.headers.firstValue(name: .contentSecurityPolicy), "default-src 'self'")
             XCTAssertEqual(res.headers.firstValue(name: .strictTransportSecurity), "max-age=3600")
         }

         try app.testable().inMemory().test(.GET, "/preload") { res in
             XCTAssertEqual(res.headers.firstValue(name: .contentSecurityPolicy), "default-src 'self'")
             XCTAssertEqual(res.headers.firstValue(name: .strictTransportSecurity), "max-age=3600; preload")
         }

         try app.testable().inMemory().test(.GET, "/subdomains") { res in
             XCTAssertEqual(res.headers.firstValue(name: .contentSecurityPolicy), "default-src 'self'")
             XCTAssertEqual(res.headers.firstValue(name: .strictTransportSecurity), "max-age=3600; includeSubDomains; preload")
         }
    }
}