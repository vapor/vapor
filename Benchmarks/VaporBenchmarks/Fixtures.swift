import AsyncHTTPClient
import Benchmark
import Foundation
import NIOCore

let responseStreams = [
    (route: "stream", chunkSize: 1024, chunkCount: 16, knownLength: true),
    (route: "stream-chunked", chunkSize: 1024, chunkCount: 16, knownLength: false),
    (route: "stream-coarse", chunkSize: 65536, chunkCount: 1, knownLength: true),
    (route: "stream-fine", chunkSize: 256, chunkCount: 256, knownLength: true),
]
let responseRoutes = ["status", "tiny", "small", "json", "large"] + responseStreams.map(\.route)
let uploadRoutes = ["stream-upload-known", "stream-upload-chunked", "collect-upload-known", "collect-upload-chunked"]

/// Pull-based chunks avoid a producer task pre-buffering the entire upload.
private struct UploadChunks: AsyncSequence, Sendable {
    typealias Element = ByteBuffer
    private static let chunk = ByteBuffer(repeating: 120, count: 4096)

    struct AsyncIterator: AsyncIteratorProtocol {
        var remaining = 16

        mutating func next() async -> ByteBuffer? {
            guard remaining > 0 else { return nil }
            remaining -= 1
            return UploadChunks.chunk
        }
    }

    func makeAsyncIterator() -> AsyncIterator { AsyncIterator() }
}

/// Make a fresh stream for each request, so each iteration consumes the full upload.
func makeNetworkRequest(route: String, at baseURL: String) -> HTTPClientRequest {
    var request = HTTPClientRequest(url: baseURL + "/bench/" + route)
    if uploadRoutes.contains(route) {
        request.method = .POST
        request.body = .stream(UploadChunks(), length: route.hasSuffix("-known") ? .known(65536) : .unknown)
    }
    return request
}

/// CI executes every fixture once; these results are not performance measurements.
func configureSmokeRun() {
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
func validateResponse(route: String, at baseURL: String) async throws {
    let response = try await HTTPClient.shared.execute(
        makeNetworkRequest(route: route, at: baseURL), timeout: .seconds(5)
    )
    let body = try await response.body.collect(upTo: 131_072)
    if let workload = responseStreams.first(where: { $0.route == route }), workload.knownLength {
        precondition(response.headers.first(name: "content-length") == String(workload.chunkSize * workload.chunkCount), route)
    } else if route == "stream-chunked" || route.hasPrefix("stream-upload-") {
        precondition(response.headers.first(name: "content-length") == nil, route)
        precondition(response.headers.first(name: "transfer-encoding")?.lowercased() == "chunked", route)
    }
    try validateBody(
        route: route, status: Int(response.status.code), body: Data(body.readableBytesView),
        contentType: response.headers.first(name: "content-type"))
}

func validateBody(route: String, status: Int, body: Data, contentType: String?) throws {
    precondition(status == (route == "status" ? 204 : 200), route)
    if route == "json" {
        precondition(contentType?.hasPrefix("application/json") == true)
        let decoded = try JSONDecoder().decode(Payload.self, from: body)
        precondition(decoded == Payload(id: 1, name: "benchmark", tags: ["a", "b", "c"]))
    } else {
        let expected: String
        switch route {
        case "status": expected = ""
        case "tiny": expected = "OK"
        case "small": expected = String(repeating: "x", count: 1_024)
        case "large", "stream-upload-known", "stream-upload-chunked", "collect-upload-known", "collect-upload-chunked":
            expected = String(repeating: "x", count: 65_536)
        case "stream", "stream-chunked": expected = String(repeating: "y", count: 16_384)
        case "stream-coarse", "stream-fine": expected = String(repeating: "y", count: 65_536)
        default: preconditionFailure("Unknown fixture: \(route)")
        }
        precondition(body.elementsEqual(expected.utf8), route)
    }
}
