import Benchmark

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration = .init(
        metrics: [.instructions, .mallocCountTotal, .wallClock],
        warmupIterations: 3,
        scalingFactor: .kilo,
        maxDuration: .seconds(3)
    )

    requestBenchmarks()
    authenticationBenchmarks()
    routingBenchmarks()
    responseBenchmarks()
    serialisationBenchmarks()
    writerBenchmarks()
    contentBenchmarks()
    middlewareBenchmarks()
    macroRoutingBenchmarks()
}
