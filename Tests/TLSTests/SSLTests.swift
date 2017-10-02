#if os(macOS)
    import XCTest
    import Async
    import TCP
    import Bits
    import Crypto
    import AppleSSL
    import TLS
    
    class AppleTests: XCTestCase {
        func testSSL() throws {
            let server = try TCP.Server()
            
            let cert = FileManager.default.contents(atPath: "/Users/joannisorlandos/Desktop/server.crt.bin")!
            
            var clients = [AppleSSL.SSLStream<TCP.Client>]()
            
            let peerQueue = DispatchQueue(label: "test.peer")
            
            let message = OSRandom().data(count: 20)
            var count = 0
            
            let receivedFuture = Promise<Void>()
            
            server.drain { client in
                do {
                    let client = try AppleSSL.SSLStream(socket: client, descriptor: client.socket.descriptor, queue: peerQueue)
                    try client.initializePeer(signedBy: Certificate(raw: cert)).blockingAwait(timeout: .seconds(2))
                    
                    client.drain { received in
                        count += 1
                        XCTAssertEqual(Data(received), message)
                        receivedFuture.complete(())
                    }
                    
                    client.start()
                    clients.append(client)
                } catch {
                    client.close()
                }
            }
            
            try server.start(port: 8081)
            let clientQueue = DispatchQueue(label: "test.client")
            
            let future = try clientQueue.sync { () -> Future<()> in
                let client = try TLSClient(queue: clientQueue)
                return try client.connect(hostname: "127.0.0.1", port: 8081).map {
                    message.withUnsafeBytes { (pointer: BytesPointer) in
                        let buffer = ByteBuffer(start: pointer, count: message.count)
                        
                        client.inputStream(buffer)
                    }
                }
            }
            
            try future.blockingAwait(timeout: .seconds(15))
            try receivedFuture.future.blockingAwait(timeout: .seconds(5))
            
            XCTAssertEqual(count, 1)
        }
    }
#endif
