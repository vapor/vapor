import Metrics
import Foundation
import NIOConcurrencyHelpers
import MetricsTestKit
import Testing

public final class TaskLocalMetricsSystemWrapper: MetricsFactory {
    public init() {}
    
    public func makeCounter(label: String, dimensions: [(String, String)]) -> any CoreMetrics.CounterHandler {
        metrics.makeCounter(label: label, dimensions: dimensions)
    }
    
    public func makeRecorder(label: String, dimensions: [(String, String)], aggregate: Bool) -> any CoreMetrics.RecorderHandler {
        metrics.makeRecorder(label: label, dimensions: dimensions, aggregate: aggregate)
    }
    
    public func makeTimer(label: String, dimensions: [(String, String)]) -> any CoreMetrics.TimerHandler {
        metrics.makeTimer(label: label, dimensions: dimensions)
    }
    
    public func destroyCounter(_ handler: any CoreMetrics.CounterHandler) {
        metrics.destroyCounter(handler)
    }
    
    public func destroyRecorder(_ handler: any CoreMetrics.RecorderHandler) {
        metrics.destroyRecorder(handler)
    }
    
    public func destroyTimer(_ handler: any CoreMetrics.TimerHandler) {
        metrics.destroyTimer(handler)
    }
}

@TaskLocal public var metrics: TestMetrics = TestMetrics()

public struct MetricsTaskLocalTrait: TestTrait, SuiteTrait, TestScoping {
    fileprivate var implementation: @Sendable (_ body: @Sendable () async throws -> Void) async throws -> Void

    public func provideScope(for test: Testing.Test, testCase: Testing.Test.Case?, performing function: @Sendable @concurrent () async throws -> Void) async throws {
        try await implementation {
            try await function()
        }
    }

}

extension Trait where Self == MetricsTaskLocalTrait {
    public static func withMetrics(_ value: TestMetrics) -> Self {
        Self { body in
            try await $metrics.withValue(value) {
                try await body()
            }
        }
    }
}
