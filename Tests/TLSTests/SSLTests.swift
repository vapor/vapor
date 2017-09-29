//import XCTest
//import TCP
//import TLS
//
//class AppleTests: XCTestCase {
//    func testExample() throws {
//        let server = try TCP.Server()
//
//        let cert = FileManager.default.contents(atPath: "/Users/joannisorlandos/Desktop/server.crt.bin")!
//
//        var clients = [SSLStream<TCP.Client>]()
//
//        server.drain { client in
//            do {
//                let client = try SSLStream(socket: client)
//                try client.initializePeer(signedBy: Certificate(raw: cert))
//
//                let parser = RequestParser(queue: .global())
//                let serializer = ResponseSerializer()
//
//                serializer.drain { message in
//                    message.message.withUnsafeBytes { (pointer: BytesPointer) in
//                        client.inputStream(ByteBuffer(start: pointer, count: message.message.count))
//                    }
//                }
//
//                client.stream(to: parser).drain { _ in
//                    serializer.inputStream(Response())
//                }
//
//                client.start(on: .global())
//                clients.append(client)
//            } catch {
//                client.close()
//            }
//        }
//
//        try server.start(port: 8081)
//        try client(to: "localhost", port: 8081)
//    }
//}
//
