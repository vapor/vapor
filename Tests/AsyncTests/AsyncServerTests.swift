import XCTVapor
@testable import Vapor
import AsyncHTTPClient

final class AsyncServerTests: XCTestCase {
    func testDoesNotHitAssertionWhenWritingOffEventLoop() throws {
        let app = Application(.testing)
        defer { app.shutdown() }

        final class Context {
            var server: [String]
            var client: [String]
            init() {
                self.server = []
                self.client = []
            }
        }
        let context = Context()

        app.on(.POST, "echo", body: .stream) { request -> Response in
            Response(body: .init(stream: { writer in
                request.body.drain { body in
                    switch body {
                    case .buffer(let buffer):
                        context.server.append(buffer.string)
                        return app.eventLoopGroup.next().makeFutureWithTask {
                            Task {
                                writer.write(.buffer(buffer))
                            }
                        }
                    case .error(let error):
                        return writer.write(.error(error))
                    case .end:
                        return writer.write(.end)
                    }
                }
            }))
        }

        app.http.server.configuration.port = 0
        app.environment.arguments = ["serve"]
        try app.start()
        
        guard let localAddress = app.http.server.shared.localAddress, let port = localAddress.port else {
            XCTFail("couldn't get port from \(app.http.server.shared.localAddress.debugDescription)")
            return
        }

        let request = try HTTPClient.Request(
            url: "http://localhost:\(port)/echo",
            method: .POST,
            headers: [
                "transfer-encoding": "chunked"
            ],
            body: .stream(length: nil, { stream in
                stream.write(.byteBuffer(.init(string: "foo"))).flatMap {
                    stream.write(.byteBuffer(.init(string: "bar")))
                }.flatMap {
                    stream.write(.byteBuffer(.init(string: "baz")))
                }
            })
        )

        final class ResponseDelegate: HTTPClientResponseDelegate {
            typealias Response = HTTPClient.Response

            let context: Context
            init(context: Context) {
                self.context = context
            }

            func didReceiveBodyPart(
                task: HTTPClient.Task<HTTPClient.Response>,
                _ buffer: ByteBuffer
            ) -> EventLoopFuture<Void> {
                self.context.client.append(buffer.string)
                return task.eventLoop.makeSucceededFuture(())
            }

            func didFinishRequest(task: HTTPClient.Task<HTTPClient.Response>) throws -> HTTPClient.Response {
                .init(host: "", status: .ok, version: .init(major: 1, minor: 1), headers: [:], body: nil)
            }
        }
        let response = ResponseDelegate(context: context)
        _ = try app.http.client.shared.execute(
            request: request,
            delegate: response
        ).wait()

        XCTAssertEqual(context.server, ["foo", "bar", "baz"])
        XCTAssertEqual(context.client, ["foo", "bar", "baz"])
    }
}
