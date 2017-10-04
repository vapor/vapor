import XCTest
import Async
import Dispatch
import TCP
import Bits
import Crypto
import TLS

#if os(macOS) && !OPENSSL
    import AppleSSL
    
    typealias SSL = AppleSSL.SSLStream
#else
    import OpenSSL
    
    typealias SSLStream = OpenSSL.SSLStream
#endif
    
class AppleTests: XCTestCase {
    func testSSL() throws {
        let server = try TCP.Server()
        
        var peers = [SSLStream<TCPClient>]()
        var clients = [TLSClient]()
        
        let peerQueue = DispatchQueue(label: "test.peer")
        
        let message = OSRandom().data(count: 20)
        var count = 0
        
        let receivedFuture = Promise<Void>()
        
        server.drain { client in
            do {
                let tlsClient = try SSLStream(socket: client, descriptor: client.socket.descriptor, queue: peerQueue)
                
                tlsClient.drain { received in
                    count += 1
                    XCTAssertEqual(Data(received), message)
                    receivedFuture.complete(())
                    client.close()
                }
                
                #if os(macOS) && !OPENSSL
                    let cert = "/Users/joannisorlandos/Desktop/server.crt.bin"
                    try tlsClient.initializePeer(signedBy: cert).blockingAwait(timeout: .seconds(2))
                #else
                    let cert = "/Users/joannisorlandos/Desktop/cert.pem"
                    let key = "/Users/joannisorlandos/Desktop/key.pem"
                    
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
        
        let future = try clientQueue.sync { () -> Future<()> in
            let client = try TLSClient(queue: clientQueue)
            
            clients.append(client)
            
            return try client.connect(hostname: "localhost", port: 8432).map {
                message.withUnsafeBytes { (pointer: BytesPointer) in
                    let buffer = ByteBuffer(start: pointer, count: message.count)
                    
                    client.inputStream(buffer)
                }
            }
        }
        
        try future.blockingAwait(timeout: .seconds(1))
        try receivedFuture.future.blockingAwait(timeout: .seconds(1))
        
        XCTAssertEqual(count, 1)
        XCTAssertEqual(peers.count, 1)
        XCTAssertEqual(clients.count, 1)
    }
}
