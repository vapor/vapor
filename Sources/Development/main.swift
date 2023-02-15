import Vapor
import Logging

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = Application(env)
defer { app.shutdown() }

try configure(app)

try app.start()

if #available(macOS 13, *) {
    do {
        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        let sseResponse: HTTPClientResponse = try await client.execute(
            HTTPClientRequest(url: "http://localhost:8080/sse"),
            deadline: .now() + .seconds(15)
        )
        
        for try await event in sseResponse.getServerSentEvents(allocator: app.allocator) {
            print(event)
        }
        
        try client.syncShutdown()
    } catch {
        print(error)
    }
}

try await app.running?.onStop.get()
