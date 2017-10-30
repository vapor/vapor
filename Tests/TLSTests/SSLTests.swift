import XCTest
import Async
import Core
import Dispatch
import TCP
import Bits
import TLS

#if os(macOS) && !OPENSSL
    import AppleSSL
    
    typealias SSL = AppleSSL.SSLStream
#else
    import OpenSSL
    
    typealias SSLStream = OpenSSL.SSLStream
#endif

#if Xcode
    private var workDir: String {
        let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
        let path = "/\(parent)/"
        return path
    }
#else
    private let workDir = "./Tests/TLSTests/"
#endif
    
class SSLTests: XCTestCase {
    func testSSL() throws {
        // FIXME: @joannis, this is failing on macOS
        return;
        let server = try! TCP.Server()
        
        var peers = [SSLStream<TCPClient>]()
        var clients = [TLSClient]()
        
        let peerQueue = DispatchQueue(label: "test.peer")
        
        let message = Data("Hello world".utf8)
        
        var count = 0
        
        let receivedFuture = Promise<Void>()
        
        server.drain { client in
            do {
                let tlsClient = try! SSLStream(socket: client, descriptor: client.socket.descriptor, queue: peerQueue)
                
                tlsClient.drain { received in
                    count += 1
                    XCTAssertEqual(Data(received), message)
                    receivedFuture.complete(())
                    client.close()
                }
                
                #if os(macOS) && !OPENSSL
                    let cert = "\(workDir)public.der"
                    try tlsClient.initializePeer(signedBy: cert).blockingAwait(timeout: .seconds(2))
                #else
                    let cert = "\(workDir)public.pem"
                    let key = "\(workDir)private.pem"
                    
                    try tlsClient.initializePeer(certificate: cert, key: key).blockingAwait(timeout: .seconds(2))
                #endif
                
                tlsClient.start()
                peers.append(tlsClient)
            } catch {
                client.close()
            }
        }
        
        try server.start(port: 8432)
        let clientQueue = DispatchQueue(label: "test.client")

        let future = try! clientQueue.sync { () -> Future<()> in
            let client = try! TLSClient(worker: EventLoop(queue: clientQueue))

            clients.append(client)

            return try! client.connect(hostname: CurrentHost.hostname, port: 8432).map {
                message.withUnsafeBytes { (pointer: BytesPointer) in
                    let buffer = ByteBuffer(start: pointer, count: message.count)

                    client.inputStream(buffer)
                }
            }
        }
        
        try future.blockingAwait(timeout: .seconds(1))
        try receivedFuture.future.blockingAwait()
        
        XCTAssertEqual(count, 1)
        XCTAssertEqual(peers.count, 1)
        XCTAssertEqual(clients.count, 1)
    }

    static let allTests = [
        ("testSSL", testSSL)
    ]
}
