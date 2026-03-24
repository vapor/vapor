import Vapor
import Metrics
import VaporTesting
import Testing
import RoutingKit
import HTTPTypes
import MetricsTestKit

@Suite("Metric Tests")
struct MetricsTests {
    @Test("Test Metrics Increases Counter", .withMetrics(TestMetrics()))
    func testMetricsIncreasesCounter() async throws {
        try await withApp { app in
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

            try await app.testing().test(.get, "/users/1") { res in
                #expect(res.status == .ok)
                let resData = try await res.content.decode(User.self)
                #expect(resData.id == 1)
                #expect(metrics.counters.count == 1)
                let counter = try #require(metrics.counters.first(where: { $0.label == "http_requests_total" }))
                let pathDimension = try #require(counter.dimensions.first(where: { $0.0 == "path"}))
                #expect(pathDimension.1 == "/users/:userID")
                #expect(counter.dimensions.first(where: { $0.0 == "path" && $0.1 == "/users/1" }) == nil)
                let methodDimension = try #require(counter.dimensions.first(where: { $0.0 == "method"}))
                #expect(methodDimension.1 == "GET")
                let status = try #require(counter.dimensions.first(where: { $0.0 == "status"}))
                #expect(status.1 == "200")

                let timer = try #require(metrics.timers.first(where: { $0.label == "http_request_duration_seconds" }))
                let timerPathDimension = try #require(timer.dimensions.first(where: { $0.0 == "path"}))
                #expect(timerPathDimension.1 == "/users/:userID")
                let timerMethodDimension = try #require(timer.dimensions.first(where: { $0.0 == "method"}))
                #expect(timerMethodDimension.1 == "GET")
                let timerStatusDimension = try #require(timer.dimensions.first(where: { $0.0 == "status"}))
                #expect(timerStatusDimension.1 == "200")
            }
        }
    }

    @Test("Test 404 on Dyanmic Route Doesn't Spam Metrics", .withMetrics(TestMetrics()))
    func testID404DoesntSpamMetrics() async throws {
        try await withApp { app in
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

            try await app.testing().test(.get, "/users/2") { res in
                #expect(res.status == .notFound)
                let counter = try #require(metrics.counters.first(where: { $0.label == "http_requests_total" }))
                let pathDimension = try #require(counter.dimensions.first(where: { $0.0 == "path"}))
                #expect(pathDimension.1 == "/users/:userID")
                let methodDimension = try #require(counter.dimensions.first(where: { $0.0 == "method"}))
                #expect(methodDimension.1 == "GET")
                let status = try #require(counter.dimensions.first(where: { $0.0 == "status"}))
                #expect(status.1 == "404")
                #expect(counter.dimensions.first(where: { $0.1 == "200" }) == nil)
                #expect(counter.dimensions.first(where: { $0.0 == "path" && $0.1 == "/users/1" }) == nil)

                let timer = try #require(metrics.timers.first(where: { $0.label == "http_request_duration_seconds" }))
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

    @Test("Test 404 Rewrites Path for Metrics to Avoid DOS Attack", .withMetrics(TestMetrics()))
    func test404RewritesPathForMetricsToAvoidDOSAttack() async throws {
        try await withApp { app in
            try await app.testing().test(.get, "/not/found") { res in
                #expect(res.status == .notFound)
                #expect(metrics.counters.count == 1)
                let counter = try #require(metrics.counters.first(where: { $0.label == "http_requests_total" }))
                let pathDimension = try #require(counter.dimensions.first(where: { $0.0 == "path"}))
                #expect(pathDimension.1 == "vapor_route_undefined")
                let methodDimension = try #require(counter.dimensions.first(where: { $0.0 == "method"}))
                #expect(methodDimension.1 == "undefined")
                let status = try #require(counter.dimensions.first(where: { $0.0 == "status"}))
                #expect(status.1 == "404")

                let timer = try #require(metrics.timers.first(where: { $0.label == "http_request_duration_seconds" }))
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

    @Test("Test Metrics Disabled", .withMetrics(TestMetrics()))
    func testMetricsDisabled() async throws {
        try await withApp { app in
            app.serverConfiguration.reportMetrics = false

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

            try await app.testing().test(.get, "/users/1") { res in
                #expect(res.status == .ok)
                let resData = try await res.content.decode(User.self)
                #expect(resData.id == 1)
                #expect(metrics.counters.count == 0)
                #expect(metrics.timers.first(where: { $0.label == "http_request_duration_seconds" }) == nil)
            }
        }
    }
}
