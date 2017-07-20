import XCTest
import HTTP
import Vapor

class CORSMiddlewareTests: XCTestCase {
    func dropWithCors(config settings: CORSConfiguration = .default) -> Droplet {
        var config = Config([:])
        try! config.set("droplet.middleware", ["my-cors"])
        
        var services = Services.default()
        let cors = CORSMiddleware(configuration: settings)
        services.instance(cors, name: "my-cors")
        
        let drop = try! Droplet(config, services)
        
        drop.get("*") { _
            in return ""
        }
        
        return drop
    }

    func dropWithCors(settings: Configs.Config) -> Droplet {
        var config = Config([:])
        try! config.set("droplet.middleware", ["my-cors"])
        
        var services = Services.default()
        let cors = try! CORSMiddleware(config: settings)
        services.instance(cors, name: "my-cors")
        
        let drop = try! Droplet(config, services)
        
        drop.get("*") { _
            in return ""
        }
        
        return drop
    }

    // MARK: - Origin Tests -

    func testCorsSameOrigin() {
        let config = CORSConfiguration(
            allowedOrigin: .originBased,
            allowedMethods: [.get],
            allowedHeaders: []
        )
        let drop = dropWithCors(config: config)

        do {
            let req = Request(method: .get, uri: "*", headers: ["Origin" : "http://test.com"])
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

        do {
            let req = Request(method: .get, uri: "*", headers: ["Origin" : "http://test.com"])
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

        // Test we get empty origin back
        do {
            let req = Request(method: .get, uri: "*", headers: ["Origin" : "http://test.com"])
            let response = try drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Origin"], "")
        } catch {
            XCTAssert(false)
        }

        // Test we don't get any cors headers if no origin specified
        do {
            let req = Request(method: .get, uri: "*")
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

        do {
            let req = Request(method: .get, uri: "*", headers: ["Origin" : "http://vapor.codes"])
            let response = try drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Origin"], "http://vapor.codes")
        } catch {
            XCTAssert(false)
        }
    }

    func testCorsMultipleCustomOriginSuccess() {
        let config = CORSConfiguration(
            allowedOrigin: .custom("http://vapor.codes, http://beta.vapor.codes"),
            allowedMethods: [.get],
            allowedHeaders: []
        )
        let drop = dropWithCors(config: config)

        do {
            let req =  Request(method: .get, uri: "*", headers: ["Origin" : "http://beta.vapor.codes"])
            let response = try drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Origin"], "http://beta.vapor.codes")
        } catch {
            XCTAssert(false)
        }
    }

    func testCorsCustomOriginFailure() {
        let config = CORSConfiguration(
            allowedOrigin: .custom("http://vapor.codes"),
            allowedMethods: [.get],
            allowedHeaders: []
        )
        let drop = dropWithCors(config: config)

        do {
            let req = Request(method: .get, uri: "*", headers: ["Origin" : "http://google.com"])
            let response = try drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Origin"], "http://vapor.codes")
        } catch {
            XCTAssert(false)
        }
    }

    func testCorsMultipleCustomOriginFailure() {
        let config = CORSConfiguration(
            allowedOrigin: .custom("http://beta.vapor.codes, http://vapor.codes"),
            allowedMethods: [.get],
            allowedHeaders: []
        )
        let drop = dropWithCors(config: config)

        do {
            let req = Request(method: .get, uri: "*", headers: ["Origin" : "http://google.com"])
            let response = try drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Origin"], "http://beta.vapor.codes, http://vapor.codes")
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
            let req = Request(method: .get, uri: "*", headers: ["Origin" : "http:/google.com"])
            let response = try drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Credentials"], "true")
        } catch {
            XCTAssert(false)
        }
    }

    func testCorsCaching() {
        do {
            let req = Request(method: .get, uri: "*", headers: ["Origin" : "http://vapor.codes"])

            // Test default value
            var config = CORSConfiguration(allowedOrigin: .custom("http://vapor.codes"),
                                           allowedMethods: [.get],
                                           allowedHeaders: [])
            var drop = dropWithCors(config: config)
            var response = try drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Max-Age"], "600")

            // Test custom value
            config = CORSConfiguration(allowedOrigin: .custom("http://vapor.codes"),
                                           allowedMethods: [.get],
                                           allowedHeaders: [],
                                           cacheExpiration: 100)
            drop = dropWithCors(config: config)
            response = try drop.respond(to: req)
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
            let req = Request(method: .options, uri: "*", headers: ["Origin" : "http://vapor.codes"])
            let response = try drop.respond(to: req)
            XCTAssertEqual(response.headers["Access-Control-Allow-Methods"], "GET, PUT, DELETE")
        } catch {
            XCTAssert(false)
        }
    }
    
    static let allTests = [
        ("testCorsSameOrigin", testCorsSameOrigin),
        ("testCorsAnyOrigin", testCorsAnyOrigin),
        ("testCorsNoOrigin", testCorsNoOrigin),
        ("testCorsCustomOriginFailure", testCorsCustomOriginFailure),
        ("testCorsCustomOriginSuccess", testCorsCustomOriginSuccess),
        ("testCorsMultipleCustomOriginSuccess", testCorsMultipleCustomOriginSuccess),
        ("testCorsMultipleCustomOriginFailure", testCorsMultipleCustomOriginFailure),
        ("testCorsCredentials", testCorsCredentials),
        ("testCorsCaching", testCorsCaching),
        ("testCorsMethods", testCorsMethods),
    ]
}
