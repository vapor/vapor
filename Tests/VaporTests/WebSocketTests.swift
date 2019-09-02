import NIO
import Vapor
import XCTest

final class WebSocketTests: XCTestCase {
    func testClientPingPong() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let echoServer = WebSocketEchoServer()
        defer {
            try! group.syncShutdownGracefully()
            echoServer.shutdown()
        }

        let promise = group.next().makePromise(of: Data?.self)
        WebSocket.connect(to: .init(string: "ws://localhost:\(echoServer.port)"), on: group) { ws in
            ws.onPong { ws, buf in
                let data = buf.getData(at: 0, length: buf.readableBytes)
                promise.succeed(data)
                _ = ws.close().cascadeFailure(to: promise)
            }

            ws.send(raw: [UInt8](Data("foo".utf8)), opcode: .ping)
        }.cascadeFailure(to: promise)

        let data = try promise.futureResult.wait()
        XCTAssertEqual(data, Data("foo".utf8))
    }
}
