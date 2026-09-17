import Benchmark
import Logging

let benchmarks: @Sendable () -> Void = {
    LoggingSystem.bootstrap { _ in SwiftLogNoOpLogHandler() }
    Benchmark.defaultConfiguration = .init(
        metrics: [.instructions, .mallocCountTotal, .wallClock],
        warmupIterations: 3,
        scalingFactor: .kilo,
        maxDuration: .seconds(3)
    )

    endToEndBenchmarks()
    requestBenchmarks()
    authenticationBenchmarks()
    routingBenchmarks()
    responseBenchmarks()
    serialisationBenchmarks()
    writerBenchmarks()
    streamingBenchmarks()
    contentBenchmarks()
    middlewareBenchmarks()
    macroRoutingBenchmarks()
}
