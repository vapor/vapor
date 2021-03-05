import XCTVapor
import Vapor
import Metrics
@testable import CoreMetrics

class MetricsTests: XCTestCase {
    func testMetricsIncreasesCounter() {
        let metrics = CapturingMetricsSystem()
        MetricsSystem.bootstrapInternal(metrics)

        let app = Application(.testing)
        defer { app.shutdown() }

        struct User: Content {
            let id: Int
            let name: String
        }

        app.routes.get("users", ":userID") { req -> User in
            let userID = try req.parameters.require("userID", as: Int.self)
            if userID == 1 {
                return User(id: 1, name: "Tim")
            } else {
                throw Abort(.notFound)
            }
        }

        XCTAssertNoThrow(try app.testable().test(.GET, "/users/1") { res in
            XCTAssertEqual(res.status, .ok)
            let resData = try res.content.decode(User.self)
            XCTAssertEqual(resData.id, 1)
            XCTAssertEqual(metrics.counters.count, 1)
            let counter = metrics.counters["http_requests_total"] as! TestCounter
            print(counter.dimensions)
            let pathDimension = try XCTUnwrap(counter.dimensions.first(where: { $0.0 == "path"}))
            XCTAssertEqual(pathDimension.1, "/users/:userID")
            XCTAssertNil(counter.dimensions.first(where: { $0.0 == "path" && $0.1 == "/users/1" }))
            let methodDimension = try XCTUnwrap(counter.dimensions.first(where: { $0.0 == "method"}))
            XCTAssertEqual(methodDimension.1, "GET")
            let status = try XCTUnwrap(counter.dimensions.first(where: { $0.0 == "status"}))
            XCTAssertEqual(status.1, "200")

            let timer = metrics.timers["http_request_duration_seconds"] as! TestTimer
            let timerPathDimension = try XCTUnwrap(timer.dimensions.first(where: { $0.0 == "path"}))
            XCTAssertEqual(timerPathDimension.1, "/users/:userID")
            let timerMethodDimension = try XCTUnwrap(timer.dimensions.first(where: { $0.0 == "method"}))
            XCTAssertEqual(timerMethodDimension.1, "GET")
            let timerStatusDimension = try XCTUnwrap(timer.dimensions.first(where: { $0.0 == "status"}))
            XCTAssertEqual(timerStatusDimension.1, "200")
        })
    }

    func testID404DoesntSpamMetrics() {
        let metrics = CapturingMetricsSystem()
        MetricsSystem.bootstrapInternal(metrics)

        let app = Application(.testing)
        defer { app.shutdown() }

        struct User: Content {
            let id: Int
            let name: String
        }

        app.routes.get("users", ":userID") { req -> User in
            let userID = try req.parameters.require("userID", as: Int.self)
            if userID == 1 {
                return User(id: 1, name: "Tim")
            } else {
                throw Abort(.notFound)
            }
        }

        XCTAssertNoThrow(try app.testable().test(.GET, "/users/2") { res in
            XCTAssertEqual(res.status, .notFound)
            let counter = metrics.counters["http_requests_total"] as! TestCounter
            let pathDimension = try XCTUnwrap(counter.dimensions.first(where: { $0.0 == "path"}))
            XCTAssertEqual(pathDimension.1, "/users/:userID")
            let methodDimension = try XCTUnwrap(counter.dimensions.first(where: { $0.0 == "method"}))
            XCTAssertEqual(methodDimension.1, "GET")
            let status = try XCTUnwrap(counter.dimensions.first(where: { $0.0 == "status"}))
            XCTAssertEqual(status.1, "404")
            XCTAssertNil(counter.dimensions.first(where: { $0.1 == "200" }))
            XCTAssertNil(counter.dimensions.first(where: { $0.0 == "path" && $0.1 == "/users/1" }))

            let timer = metrics.timers["http_request_duration_seconds"] as! TestTimer
            let timerPathDimension = try XCTUnwrap(timer.dimensions.first(where: { $0.0 == "path"}))
            XCTAssertEqual(timerPathDimension.1, "/users/:userID")
            let timerMethodDimension = try XCTUnwrap(timer.dimensions.first(where: { $0.0 == "method"}))
            XCTAssertEqual(timerMethodDimension.1, "GET")
            let timerStatusDimension = try XCTUnwrap(timer.dimensions.first(where: { $0.0 == "status"}))
            XCTAssertEqual(timerStatusDimension.1, "404")
            XCTAssertNil(timer.dimensions.first(where: { $0.1 == "200" }))
        })
    }

    func test404RewritesPathForMetricsToAvoidDOSAttack()  {
        let metrics = CapturingMetricsSystem()
        MetricsSystem.bootstrapInternal(metrics)

        let app = Application(.testing)
        defer { app.shutdown() }

        XCTAssertNoThrow(try app.testable().test(.GET, "/not/found") { res in
            XCTAssertEqual(res.status, .notFound)
            XCTAssertEqual(metrics.counters.count, 1)
            let counter = metrics.counters["http_requests_total"] as! TestCounter
            let pathDimension = try XCTUnwrap(counter.dimensions.first(where: { $0.0 == "path"}))
            XCTAssertEqual(pathDimension.1, "vapor_route_undefined")
            let methodDimension = try XCTUnwrap(counter.dimensions.first(where: { $0.0 == "method"}))
            XCTAssertEqual(methodDimension.1, "undefined")
            let status = try XCTUnwrap(counter.dimensions.first(where: { $0.0 == "status"}))
            XCTAssertEqual(status.1, "404")

            let timer = metrics.timers["http_request_duration_seconds"] as! TestTimer
            let timerPathDimension = try XCTUnwrap(timer.dimensions.first(where: { $0.0 == "path"}))
            XCTAssertEqual(timerPathDimension.1, "vapor_route_undefined")
            let timerMethodDimension = try XCTUnwrap(timer.dimensions.first(where: { $0.0 == "method"}))
            XCTAssertEqual(timerMethodDimension.1, "undefined")
            let timerStatusDimension = try XCTUnwrap(timer.dimensions.first(where: { $0.0 == "status"}))
            XCTAssertEqual(timerStatusDimension.1, "404")
            XCTAssertNil(timer.dimensions.first(where: { $0.1 == "200" }))
        })
    }
}

