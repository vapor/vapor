import XCTest
import HTTP
@testable import Vapor

class CORSMiddlewareTests: XCTestCase {
    static let allTests = [
        ("testCorsSameOrigin", testCorsSameOrigin),
        ("testCorsAnyOrigin", testCorsAnyOrigin),
        ("testCorsNoOrigin", testCorsNoOrigin),
        ("testCorsCustomOriginFailure", testCorsCustomOriginFailure),
        ("testCorsCustomOriginSuccess", testCorsCustomOriginSuccess),
        ("testCorsCredentials", testCorsCredentials),
        ("testCorsCaching", testCorsCaching),
        ("testCorsMethods", testCorsMethods),
        ]


    func dropWithCors(config: CORSConfiguration = .default) -> Droplet {
        let drop = try! Droplet()
        drop.middleware.insert(CORSMiddleware(configuration: config), at: 0)
        drop.get("*") { _ in return "" }
        return drop
    }

    func dropWithCors(settings: Settings.Config) -> Droplet {
        let drop = try! Droplet()
        drop.middleware.insert(try! CORSMiddleware(configuration: settings), at: 0)
        drop.get("*") { _ in return "" }
        return drop
    }

    // MARK: - Origin Tests -

    func testCorsSameOrigin() {
        let config = CORSConfiguration(allowedOrigin: .originBased,
                                       allowedMethods: [.get],
                                       allowedHeaders: [])
        let drop = dropWithCors(config: config)

        do {
            let req = try Request(method: .get, uri: "*", headers: ["Origin" : "http://test.com"])
            let response = drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Origin"], "http://test.com")
        } catch {
            XCTAssert(false)
        }
    }

    func testCorsAnyOrigin() {
        let config = CORSConfiguration(allowedOrigin: .all,
                                       allowedMethods: [.get],
                                       allowedHeaders: [])
        let drop = dropWithCors(config: config)

        do {
            let req = try Request(method: .get, uri: "*", headers: ["Origin" : "http://test.com"])
            let response = drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Origin"], "*")
        } catch {
            XCTAssert(false)
        }
    }

    func testCorsNoOrigin() {
        let config = CORSConfiguration(allowedOrigin: .none,
                                       allowedMethods: [.get],
                                       allowedHeaders: [])
        let drop = dropWithCors(config: config)

        // Test we get empty origin back
        do {
            let req = try Request(method: .get, uri: "*", headers: ["Origin" : "http://test.com"])
            let response = drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Origin"], "")
        } catch {
            XCTAssert(false)
        }

        // Test we don't get any cors headers if no origin specified
        do {
            let req = try Request(method: .get, uri: "*")
            let response = drop.respond(to: req)
            XCTAssertFalse(response.headers.contains(where: { $0.0 == "Access-Control-Allow-Origin" }), "")
        } catch {
            XCTAssert(false)
        }
    }

    func testCorsCustomOriginSuccess() {
        let config = CORSConfiguration(allowedOrigin: .custom("http://vapor.codes"),
                                       allowedMethods: [.get],
                                       allowedHeaders: [])
        let drop = dropWithCors(config: config)

        do {
            let req = try Request(method: .get, uri: "*", headers: ["Origin" : "http://vapor.codes"])
            let response = drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Origin"], "http://vapor.codes")
        } catch {
            XCTAssert(false)
        }
    }

    func testCorsCustomOriginFailure() {
        let config = CORSConfiguration(allowedOrigin: .custom("http://vapor.codes"),
                                       allowedMethods: [.get],
                                       allowedHeaders: [])
        let drop = dropWithCors(config: config)

        do {
            let req = try Request(method: .get, uri: "*", headers: ["Origin" : "http://google.com"])
            let response = drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Origin"], "http://vapor.codes")
        } catch {
            XCTAssert(false)
        }
    }

    func testCorsCredentials() {
        let config = CORSConfiguration(allowedOrigin: .custom("http://vapor.codes"),
                                       allowedMethods: [.get],
                                       allowedHeaders: [],
                                       allowCredentials: true)
        let drop = dropWithCors(config: config)

        do {
            let req = try Request(method: .get, uri: "*", headers: ["Origin" : "http:/google.com"])
            let response = drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Credentials"], "true")
        } catch {
            XCTAssert(false)
        }
    }

    func testCorsCaching() {
        do {
            let req = try Request(method: .get, uri: "*", headers: ["Origin" : "http://vapor.codes"])

            // Test default value
            var config = CORSConfiguration(allowedOrigin: .custom("http://vapor.codes"),
                                           allowedMethods: [.get],
                                           allowedHeaders: [])
            var drop = dropWithCors(config: config)
            var response = drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Max-Age"], "600")

            // Test custom value
            config = CORSConfiguration(allowedOrigin: .custom("http://vapor.codes"),
                                           allowedMethods: [.get],
                                           allowedHeaders: [],
                                           cacheExpiration: 100)
            drop = dropWithCors(config: config)
            response = drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Max-Age"], "100")
        } catch {
            XCTAssert(false)
        }
    }

    func testCorsMethods() {
        let config = CORSConfiguration(allowedOrigin: .custom("http://vapor.codes"),
                                       allowedMethods: [.get, .put, .delete],
                                       allowedHeaders: [])
        let drop = dropWithCors(config: config)

        do {
            let req = try Request(method: .options, uri: "*", headers: ["Origin" : "http://vapor.codes"])
            let response = drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Methods"], "GET, PUT, DELETE")
        } catch {
            XCTAssert(false)
        }
    }
}
