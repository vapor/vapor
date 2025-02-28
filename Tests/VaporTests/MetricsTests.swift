import Vapor
import Metrics
@testable import CoreMetrics
import VaporTesting
import Testing

// These have to be serialized because the metrics system is essentially a global
@Suite("Metric Tests", .serialized, .disabled())
struct MetricsTests {
    @Test("Test Metrics Increases Counter")
    func testMetricsIncreasesCounter() async throws {
        try await withApp { app in
            let metrics = CapturingMetricsSystem()
            MetricsSystem.bootstrapInternal(metrics)

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

            try await app.testing().test(.GET, "/users/1") { res in
                #expect(res.status == .ok)
                let resData = try res.content.decode(User.self)
                #expect(resData.id == 1)
                #expect(metrics.counters.count == 1)
                let counter = metrics.counters["http_requests_total"] as! TestCounter
                let pathDimension = try #require(counter.dimensions.first(where: { $0.0 == "path"}))
                #expect(pathDimension.1 == "/users/:userID")
                #expect(counter.dimensions.first(where: { $0.0 == "path" && $0.1 == "/users/1" }) == nil)
                let methodDimension = try #require(counter.dimensions.first(where: { $0.0 == "method"}))
                #expect(methodDimension.1 == "GET")
                let status = try #require(counter.dimensions.first(where: { $0.0 == "status"}))
                #expect(status.1 == "200")

                let timer = metrics.timers["http_request_duration_seconds"] as! TestTimer
                let timerPathDimension = try #require(timer.dimensions.first(where: { $0.0 == "path"}))
                #expect(timerPathDimension.1 == "/users/:userID")
                let timerMethodDimension = try #require(timer.dimensions.first(where: { $0.0 == "method"}))
                #expect(timerMethodDimension.1 == "GET")
                let timerStatusDimension = try #require(timer.dimensions.first(where: { $0.0 == "status"}))
                #expect(timerStatusDimension.1 == "200")
            }
        }
    }

    @Test("Test 404 on Dyanmic Route Doesn't Spam Metrics")
    func testID404DoesntSpamMetrics() async throws {
        try await withApp { app in
            let metrics = CapturingMetricsSystem()
            MetricsSystem.bootstrapInternal(metrics)

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

            try await app.testing().test(.GET, "/users/2") { res in
                #expect(res.status == .notFound)
                let counter = metrics.counters["http_requests_total"] as! TestCounter
                let pathDimension = try #require(counter.dimensions.first(where: { $0.0 == "path"}))
                #expect(pathDimension.1 == "/users/:userID")
                let methodDimension = try #require(counter.dimensions.first(where: { $0.0 == "method"}))
                #expect(methodDimension.1 == "GET")
                let status = try #require(counter.dimensions.first(where: { $0.0 == "status"}))
                #expect(status.1 == "404")
                #expect(counter.dimensions.first(where: { $0.1 == "200" }) == nil)
                #expect(counter.dimensions.first(where: { $0.0 == "path" && $0.1 == "/users/1" }) == nil)

                let timer = metrics.timers["http_request_duration_seconds"] as! TestTimer
                let timerPathDimension = try #require(timer.dimensions.first(where: { $0.0 == "path"}))
                #expect(timerPathDimension.1 == "/users/:userID")
                let timerMethodDimension = try #require(timer.dimensions.first(where: { $0.0 == "method"}))
                #expect(timerMethodDimension.1 == "GET")
                let timerStatusDimension = try #require(timer.dimensions.first(where: { $0.0 == "status"}))
                #expect(timerStatusDimension.1 == "404")
                #expect(timer.dimensions.first(where: { $0.1 == "200" }) == nil)
            }
        }
    }

    @Test("Test 404 Rewrites Path for Metrics to Avoid DOS Attack")
    func test404RewritesPathForMetricsToAvoidDOSAttack() async throws {
        try await withApp { app in
            let metrics = CapturingMetricsSystem()
            MetricsSystem.bootstrapInternal(metrics)

            try await app.testing().test(.GET, "/not/found") { res in
                #expect(res.status == .notFound)
                #expect(metrics.counters.count == 1)
                let counter = metrics.counters["http_requests_total"] as! TestCounter
                let pathDimension = try #require(counter.dimensions.first(where: { $0.0 == "path"}))
                #expect(pathDimension.1 == "vapor_route_undefined")
                let methodDimension = try #require(counter.dimensions.first(where: { $0.0 == "method"}))
                #expect(methodDimension.1 == "undefined")
                let status = try #require(counter.dimensions.first(where: { $0.0 == "status"}))
                #expect(status.1 == "404")

                let timer = metrics.timers["http_request_duration_seconds"] as! TestTimer
                let timerPathDimension = try #require(timer.dimensions.first(where: { $0.0 == "path"}))
                #expect(timerPathDimension.1 == "vapor_route_undefined")
                let timerMethodDimension = try #require(timer.dimensions.first(where: { $0.0 == "method"}))
                #expect(timerMethodDimension.1 == "undefined")
                let timerStatusDimension = try #require(timer.dimensions.first(where: { $0.0 == "status"}))
                #expect(timerStatusDimension.1 == "404")
                #expect(timer.dimensions.first(where: { $0.1 == "200" }) == nil)
            }
        }
    }

    @Test("Test Metrics Disabled")
    func testMetricsDisabled() async throws {
        try await withApp { app in
            let metrics = CapturingMetricsSystem()
            MetricsSystem.bootstrapInternal(metrics)

            app.http.server.configuration.reportMetrics = false

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

            try await app.testing().test(.GET, "/users/1") { res in
                #expect(res.status == .ok)
                let resData = try res.content.decode(User.self)
                #expect(resData.id == 1)
                #expect(metrics.counters.count == 0)
                #expect(metrics.timers["http_request_duration_seconds"] == nil)
            }
        }
    }
}

