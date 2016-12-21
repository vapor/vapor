import XCTest
import HTTP
@testable import Vapor

class CORSMiddlewareTests: XCTestCase {
    static let allTests = [
        ("testCORSMiddleware", testCORSMiddleware),
        ("testCorsSameOrigin", testCorsSameOrigin),
        ("testCorsAnyOrigin", testCorsAnyOrigin),
        ("testCorsNoOrigin", testCorsNoOrigin),
        ("testCorsCustomOriginFailure", testCorsCustomOriginFailure),
        ("testCorsCustomOriginSuccess", testCorsCustomOriginSuccess),
        ]


    func dropWithCors(config: CORSConfiguration = .default) -> Droplet {
        let drop = Droplet()
        drop.middleware.insert(CORSMiddleware(configuration: config), at: 0)
        return drop
    }

    func dropWithCors(settings: Settings.Config) -> Droplet {
        let drop = Droplet()
        drop.middleware.insert(try! CORSMiddleware(configuration: settings), at: 0)
        return drop
    }

    // MARK: - Origin Tests -

    func testCorsSameOrigin() {
        let config = CORSConfiguration(allowedOrigin: .originBased,
                                       allowedMethods: [.get],
                                       allowedHeaders: [])
        let drop = dropWithCors(config: config)
        drop.get("*") { req in
            return ""
        }

        do {
            let req = try Request(method: .get, uri: "*", headers: ["Origin" : "http://test.com"])
            let response = try drop.respond(to: req)
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
        drop.get("*") { req in
            return ""
        }

        do {
            let req = try Request(method: .get, uri: "*", headers: ["Origin" : "http://test.com"])
            let response = try drop.respond(to: req)
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
        drop.get("*") { req in
            return ""
        }

        // Test we get empty origin back
        do {
            let req = try Request(method: .get, uri: "*", headers: ["Origin" : "http://test.com"])
            let response = try drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Origin"], "")
        } catch {
            XCTAssert(false)
        }

        // Test we don't get any cors headers if no origin specified
        do {
            let req = try Request(method: .get, uri: "*")
            let response = try drop.respond(to: req)
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
        drop.get("*") { req in
            return ""
        }

        do {
            let req = try Request(method: .get, uri: "*", headers: ["Origin" : "http://vapor.codes"])
            let response = try drop.respond(to: req)
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
        drop.get("*") { req in
            return ""
        }

        do {
            let req = try Request(method: .get, uri: "*", headers: ["Origin" : "http:/google.com"])
            let response = try drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Origin"], "http://vapor.codes")
        } catch {
            XCTAssert(false)
        }
    }
}
