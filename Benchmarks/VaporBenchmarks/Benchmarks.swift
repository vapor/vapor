import Benchmark

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration = .init(
        // Instruction and malloc counts are the signal we care about — they're deterministic and
        // survive a noisy machine. Wall clock is kept for context but shouldn't gate anything.
        metrics: [.instructions, .mallocCountTotal, .wallClock],
        warmupIterations: 3,
        // A single operation is far cheaper than the cost of taking one sample, so measure a
        // thousand per sample and let the results be scaled back down. Without this every benchmark
        // reports an identical ~30K instructions of measurement overhead.
        scalingFactor: .kilo,
        maxDuration: .seconds(3)
    )

    requestBenchmarks()
    authenticationBenchmarks()
    routingBenchmarks()
    responseBenchmarks()
    contentBenchmarks()
    middlewareBenchmarks()
    macroRoutingBenchmarks()
}
