import Vapor
import Metrics
@testable import CoreMetrics
import VaporTesting
import Testing

#if(compiler(>=6.1))
@Suite("Metric Tests")
struct MetricsTests {
    @Test("Test Metrics Increases Counter", .withMetrics(CapturingMetricsSystem()))
    func testMetricsIncreasesCounter() async throws {
        try await withApp { app in
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
                let counter = try #require(metrics.counters["http_requests_total"] as? TestCounter)
                let pathDimension = try #require(counter.dimensions.first(where: { $0.0 == "path"}))
                #expect(pathDimension.1 == "/users/:userID")
                #expect(counter.dimensions.first(where: { $0.0 == "path" && $0.1 == "/users/1" }) == nil)
                let methodDimension = try #require(counter.dimensions.first(where: { $0.0 == "method"}))
                #expect(methodDimension.1 == "GET")
                let status = try #require(counter.dimensions.first(where: { $0.0 == "status"}))
                #expect(status.1 == "200")

                let timer = try #require(metrics.timers["http_request_duration_seconds"] as? TestTimer)
                let timerPathDimension = try #require(timer.dimensions.first(where: { $0.0 == "path"}))
                #expect(timerPathDimension.1 == "/users/:userID")
                let timerMethodDimension = try #require(timer.dimensions.first(where: { $0.0 == "method"}))
                #expect(timerMethodDimension.1 == "GET")
                let timerStatusDimension = try #require(timer.dimensions.first(where: { $0.0 == "status"}))
                #expect(timerStatusDimension.1 == "200")
            }
        }
    }

    @Test("Test 404 on Dyanmic Route Doesn't Spam Metrics", .withMetrics(CapturingMetricsSystem()))
    func testID404DoesntSpamMetrics() async throws {
        try await withApp { app in
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
                let counter = try #require(metrics.counters["http_requests_total"] as? TestCounter)
                let pathDimension = try #require(counter.dimensions.first(where: { $0.0 == "path"}))
                #expect(pathDimension.1 == "/users/:userID")
                let methodDimension = try #require(counter.dimensions.first(where: { $0.0 == "method"}))
                #expect(methodDimension.1 == "GET")
                let status = try #require(counter.dimensions.first(where: { $0.0 == "status"}))
                #expect(status.1 == "404")
                #expect(counter.dimensions.first(where: { $0.1 == "200" }) == nil)
                #expect(counter.dimensions.first(where: { $0.0 == "path" && $0.1 == "/users/1" }) == nil)

                let timer = try #require(metrics.timers["http_request_duration_seconds"] as? TestTimer)
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

    @Test("Test 404 Rewrites Path for Metrics to Avoid DOS Attack", .withMetrics(CapturingMetricsSystem()))
    func test404RewritesPathForMetricsToAvoidDOSAttack() async throws {
        try await withApp { app in
            MetricsSystem.bootstrapInternal(metrics)

            try await app.testing().test(.GET, "/not/found") { res in
                #expect(res.status == .notFound)
                #expect(metrics.counters.count == 1)
                let counter = try #require(metrics.counters["http_requests_total"] as? TestCounter)
                let pathDimension = try #require(counter.dimensions.first(where: { $0.0 == "path"}))
                #expect(pathDimension.1 == "vapor_route_undefined")
                let methodDimension = try #require(counter.dimensions.first(where: { $0.0 == "method"}))
                #expect(methodDimension.1 == "undefined")
                let status = try #require(counter.dimensions.first(where: { $0.0 == "status"}))
                #expect(status.1 == "404")

                let timer = try #require(metrics.timers["http_request_duration_seconds"] as? TestTimer)
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

    @Test("Test Metrics Disabled", .withMetrics(CapturingMetricsSystem()))
    func testMetricsDisabled() async throws {
        try await withApp { app in
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

@TaskLocal var metrics = CapturingMetricsSystem()

struct MetricsTaskLocalTrait: TestTrait, SuiteTrait, TestScoping {
  fileprivate var implementation: @Sendable (_ body: @Sendable () async throws -> Void) async throws -> Void

  func provideScope(for test: Testing.Test, testCase: Testing.Test.Case?, performing function: @Sendable () async throws -> Void) async throws {
    try await implementation {
      try await function()
    }
  }

}

extension Trait where Self == MetricsTaskLocalTrait {
  static func withMetrics(_ value: CapturingMetricsSystem) -> Self {
    Self { body in
      try await $metrics.withValue(value) {
        try await body()
      }
    }
  }
}
#endif
