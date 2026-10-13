import AsyncHTTPClient
import NIOCore
import NIOFoundationEssentialsCompat
import NIOHTTP1
import RoutingKit
import Testing
import Vapor
import VaporTesting

@Suite("Task-local request context")
struct TaskLocalRequestContextTests {
    @Test("Requests inherit the serving scope, not the registration or client scope", .timeLimit(.minutes(1)), arguments: [false, true])
    func servingScope(bindWhileServing: Bool) async throws {
        try await withApp { app in
            app.serverConfiguration.address = .hostname("127.0.0.1", port: 0)

            Context.$name.withValue("registration") {
                let captured = Context.name ?? "missing"
                app.get("task-context") { _ -> String in
                    "\(captured)|\(Context.name ?? "none")"
                }
            }
            #expect(Context.name == nil)

            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    if bindWhileServing {
                        try await Context.$name.withValue("serving") {
                            try await app.run()
                        }
                    } else {
                        try await app.run()
                    }
                }
                defer { group.cancelAll() }

                let address = try await app.server.listeningAddress
                let port = try #require(address.port)
                try await Context.$name.withValue("client") {
                    let response = try await HTTPClient.shared.execute(
                        HTTPClientRequest(url: "http://127.0.0.1:\(port)/task-context"), timeout: .seconds(10))
                    #expect(response.status == .ok)
                    let body = try await response.body.collect(upTo: 1024)
                    #expect(body.string == (bindWhileServing ? "registration|serving" : "registration|none"))
                }
            }
        }
    }

    private enum Context {
        @TaskLocal static var name: String?
    }
}
