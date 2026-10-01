import Benchmark
import Logging

let benchmarks: @Sendable () -> Void = {
    LoggingSystem.bootstrap { _ in SwiftLogNoOpLogHandler() }
    configureBenchmarks()

    endToEndBenchmarks()
    requestBenchmarks()
    authenticationBenchmarks()
    routingBenchmarks()
    trieBenchmarks()
    responseBenchmarks()
    serialisationBenchmarks()
    writerBenchmarks()
    streamingBenchmarks()
    contentBenchmarks()
    middlewareBenchmarks()
    macroRoutingBenchmarks()
}
