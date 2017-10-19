//import Dispatch
//import HTTP
//import Crypto
//import Bits
//import Foundation
//import Vapor
//import OpenSSL
//import AppleSSL
//import TCP
//import Routing
//import XCTest
//
//class ControllerTests: XCTestCase {
//    func appleSSLClient(to host: String, port: UInt16, message: Data) throws {
//        #if os(macOS)
//        let queue = DispatchQueue(label: "test")
//        
//        let clientSocket = try TCP.Socket()
//        let client = TCP.Client(socket: clientSocket, queue: .global())
//        let SSL = try AppleSSL.SSLStream(socket: client, descriptor: clientSocket.descriptor)
//        try clientSocket.connect(hostname: host, port: port)
//        try clientSocket.writable(queue: queue).blockingAwait()
//        try SSL.initializeClient(hostname: host)
//        
//        message.withUnsafeBytes { (pointer: BytesPointer) in
//            SSL.inputStream(ByteBuffer(start: pointer, count: message.count))
//        }
//        
//        SSL.start(on: queue)
//        #endif
//    }
//    
//    func openSSLClient(to host: String, port: UInt16, message: Data) throws {
//        let queue = DispatchQueue(label: "test")
//        
//        let clientSocket = try TCP.Socket()
//        let client = TCP.Client(socket: clientSocket, queue: .global())
//        let SSL = try OpenSSL.SSLStream(socket: client, descriptor: clientSocket.descriptor)
//        try clientSocket.connect(hostname: host, port: port)
//        try clientSocket.writable(queue: queue).blockingAwait()
//        try SSL.initializeClient(hostname: host)
//        
//        message.withUnsafeBytes { (pointer: BytesPointer) in
//            SSL.inputStream(ByteBuffer(start: pointer, count: message.count))
//        }
//        
//        SSL.start(on: queue)
//    }
//
//    func testSSL() throws {
//        let server = try TCP.Server()
//        
//        let cert = FileManager.default.contents(atPath: "/Users/joannisorlandos/Desktop/server.crt.bin")!
//        
//        var clients = [AppleSSL.SSLStream<TCP.Client>]()
//        
//        let clientQueue = DispatchQueue(label: "test.peer")
//        
//        let message = OSRandom().data(count: 20)
//        
//        server.drain { client in
//            do {
//                let client = try AppleSSL.SSLStream(socket: client, descriptor: client.socket.descriptor)
//                try client.initializePeer(signedBy: Certificate(raw: cert))
//                
//                client.drain { received in
//                    XCTAssertEqual(Data(received), message)
//                }
//                
//                client.start(on: clientQueue)
//                clients.append(client)
//            } catch {
//                client.close()
//            }
//        }
//        
//        try server.start(port: 8081)
//        
//        try appleSSLClient(to: "127.0.0.1", port: 8081, message: message)
//        try openSSLClient(to: "127.0.0.1", port: 8081, message: message)
//    }
//}

