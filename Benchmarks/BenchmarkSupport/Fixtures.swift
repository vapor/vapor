import AsyncHTTPClient
import Benchmark
import Foundation

/// CI executes every fixture once; these results are not performance measurements.
package func configureSmokeRun() {
    guard ProcessInfo.processInfo.environment["BENCHMARK_SMOKE"] == "1" else { return }
    Benchmark.defaultConfiguration = .init(
        metrics: [.wallClock], warmupIterations: 0, scalingFactor: .one,
        maxDuration: .seconds(1), maxIterations: 1
    )
}

private struct Payload: Decodable, Equatable {
    var id: Int
    var name: String
    var tags: [String]
}

/// Check complete bodies before timing so a broken fixture cannot look faster.
package func validateResponse(route: String, at baseURL: String) async throws {
    let response = try await HTTPClient.shared.execute(
        HTTPClientRequest(url: baseURL + "/bench/" + route), timeout: .seconds(5)
    )
    let body = try await response.body.collect(upTo: 131_072)
    precondition(response.status.code == (route == "status" ? 204 : 200), route)
    if route == "json" {
        precondition(response.headers.first(name: "content-type")?.hasPrefix("application/json") == true)
        let decoded = try JSONDecoder().decode(Payload.self, from: Data(body.readableBytesView))
        precondition(decoded == Payload(id: 1, name: "benchmark", tags: ["a", "b", "c"]))
    } else {
        let expected: String
        switch route {
        case "status": expected = ""
        case "tiny": expected = "OK"
        case "large": expected = String(repeating: "x", count: 65_536)
        case "stream": expected = String(repeating: "y", count: 16_384)
        default: preconditionFailure("Unknown fixture: \(route)")
        }
        precondition(body.readableBytesView.elementsEqual(expected.utf8), route)
    }
}
