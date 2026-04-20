import Tracing
import InMemoryTracing
import Foundation
import NIOConcurrencyHelpers
import Testing

public final class TaskLocalTracingSystemWrapper: Tracer {
    public init() {}
    
    public func forceFlush() {
        tracer.forceFlush()
    }

    public func extract<Carrier, Extract>(_ carrier: Carrier, into context: inout ServiceContextModule.ServiceContext, using extractor: Extract) where Carrier == Extract.Carrier, Extract : Instrumentation.Extractor {
        tracer.extract(carrier, into: &context, using: extractor)
    }

    public func inject<Carrier, Inject>(_ context: ServiceContextModule.ServiceContext, into carrier: inout Carrier, using injector: Inject) where Carrier == Inject.Carrier, Inject : Instrumentation.Injector {
        tracer.inject(context, into: &carrier, using: injector)
    }

    public func startSpan<Instant>(_ operationName: String, context: @autoclosure () -> ServiceContext, ofKind kind: SpanKind, at instant: @autoclosure () -> Instant, function: String, file fileID: String, line: UInt) -> InMemorySpan where Instant : TracerInstant {
        tracer.startSpan(operationName, context: context(), ofKind: kind, at: instant(), function: function, file: fileID, line: line)
    }

    @available(*, deprecated, message: "prefer withSpan")
    public func startAnySpan<Instant>(_ operationName: String, context: @autoclosure () -> ServiceContext, ofKind kind: SpanKind, at instant: @autoclosure () -> Instant, function: String, file fileID: String, line: UInt) -> InMemorySpan where Instant : TracerInstant {
        tracer.startAnySpan(operationName, context: context(), ofKind: kind, at: instant(), function: function, file: fileID, line: line) as! InMemorySpan
    }

    public func activeSpan(identifiedBy context: ServiceContext) -> InMemorySpan? {
        tracer.activeSpan(identifiedBy: context)
    }
}

@TaskLocal public var tracer: InMemoryTracer = InMemoryTracer()

public struct TracingTaskLocalTrait: TestTrait, SuiteTrait, TestScoping {
    fileprivate var implementation: @Sendable (_ body: @Sendable () async throws -> Void) async throws -> Void

    public func provideScope(for test: Testing.Test, testCase: Testing.Test.Case?, performing function: @Sendable @concurrent () async throws -> Void) async throws {
        try await implementation {
            try await function()
        }
    }

}

extension Trait where Self == TracingTaskLocalTrait {
    public static func withTracer(_ value: InMemoryTracer) -> Self {
        Self { body in
            try await $tracer.withValue(value) {
                try await body()
            }
        }
    }
}
