import Foundation
import Hummingbird
import Logging
import NIOCore
import NIOPosix

let port = Int(ProcessInfo.processInfo.environment["PERF_PORT"] ?? "") ?? 8080
let host = ProcessInfo.processInfo.environment["PERF_HOST"] ?? "127.0.0.1"

struct Payload: ResponseEncodable {
    var id: Int
    var name: String
    var tags: [String]
}

let small = String(repeating: "x", count: 1024)
let large = String(repeating: "x", count: 64 * 1024)
let chunk = String(repeating: "y", count: 1024)
let json = Payload(id: 1, name: "benchmark", tags: ["a", "b", "c"])
let filePath = ProcessInfo.processInfo.environment["PERF_FILE"] ?? NSTemporaryDirectory() + "vapor-perf-1MiB.bin"
if !FileManager.default.fileExists(atPath: filePath) {
    try Data(repeating: 0x7A, count: 1 << 20).write(to: URL(fileURLWithPath: filePath))
}

let router = Router()
router.get("bench/tiny") { _, _ in "OK" }
router.get("bench/small") { _, _ in small }
router.get("bench/large") { _, _ in large }
router.get("bench/json") { _, _ in json }
router.get("bench/stream") { _, _ in
    Response(status: .ok, body: .init(contentLength: 16 * 1024) { writer in
        for _ in 0..<16 {
            try await writer.write(ByteBuffer(string: chunk))
        }
        try await writer.finish(nil)
    })
}
let fileIO = FileIO()
router.get("bench/file") { _, context in
    Response(status: .ok, body: try await fileIO.loadFile(path: filePath, context: context, chunkLength: 128 * 1024))
}

var logger = Logger(label: "performance.hummingbird")
logger.logLevel = .error
let app = Application(
    router: router,
    configuration: .init(address: .hostname(host, port: port)),
    // Match Vapor's POSIX transport, including on macOS.
    eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
    logger: logger
)
try await app.runService()
