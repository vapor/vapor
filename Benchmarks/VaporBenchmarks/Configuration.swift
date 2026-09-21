import Benchmark
import Foundation

private enum MeasurementMode: String {
    case allocations
    case instructions
    case cpu
    case wallClock = "wall-clock"

    var metric: BenchmarkMetric {
        switch self {
        case .allocations: .mallocCountTotal
        case .instructions: .instructions
        case .cpu: .cpuTotal
        case .wallClock: .wallClock
        }
    }

    var thresholds: BenchmarkThresholds {
        switch self {
        case .allocations: .init(relative: [.p90: 1])
        case .instructions: .init(relative: [.p90: 5])
        case .cpu, .wallClock: .init(relative: [.p90: 10])
        }
    }
}

func configureBenchmarks() {
    let environment = ProcessInfo.processInfo.environment
    if environment["BENCHMARK_SMOKE"] == "1" {
        // Exercise every fixture without hardware counters or scaled repetitions.
        Benchmark.defaultConfiguration = .init(
            metrics: [.wallClock], warmupIterations: 0, scalingFactor: .one,
            maxDuration: .seconds(1), maxIterations: 1
        )
        return
    }

    #if BENCHMARK_ALLOCATION_COUNTING
        let defaultMode = MeasurementMode.allocations
    #else
        let defaultMode = MeasurementMode.instructions
    #endif
    let name = environment["BENCHMARK_MODE"] ?? defaultMode.rawValue
    guard let mode = MeasurementMode(rawValue: name) else {
        preconditionFailure("Unknown BENCHMARK_MODE '\(name)'; use allocations, instructions, cpu or wall-clock.")
    }

    #if BENCHMARK_ALLOCATION_COUNTING
        precondition(mode == .allocations, "Use a build without AllocationCounting for instruction and timing measurements.")
    #else
        precondition(mode != .allocations, "Allocation measurements require --traits AllocationCounting.")
        // The upstream Linux plugin preloads any interposer artifacts in its build directory,
        // including leftovers from earlier builds with different traits.
        for key in ["LD_PRELOAD", "DYLD_INSERT_LIBRARIES"] {
            let libraries = environment[key] ?? ""
            precondition(
                !libraries.contains("MallocInterposer") && !libraries.contains("SwiftRuntimeInterposer"),
                "Instruction and timing measurements require a fresh, separate --scratch-path without interposers.")
        }
    #endif

    Benchmark.defaultConfiguration = .init(
        metrics: [mode.metric],
        warmupIterations: 5, scalingFactor: .kilo, maxDuration: .seconds(5),
        thresholds: [mode.metric: mode.thresholds]
    )
}
