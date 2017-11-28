import Async
import Bits
import Crypto
import Foundation
import TCP

public final class PSQLConnection {
    let client: TCPClient
    let parser: PSQLParser
    
    var authenticated: Future<Void> {
        return parser.authenticated.future
    }
    
    init(credentials: Credentials, worker: Worker) throws {
        let socket = try TCPSocket()
        let client = TCPClient(socket: socket, worker: worker)
        
        self.client = client
        self.parser = PSQLParser(client: client, credentials: credentials)
        
        client.stream(to: parser)
    }
    
    public static func makeConnection(hostname: String, port: UInt16 = 5432, credentials: Credentials, database: String, on worker: Worker) throws -> Future<PSQLConnection> {
        let connection = try PSQLConnection(credentials: credentials, worker: worker)
            
        try connection.client.socket.connect(hostname: hostname, port: port)
            
        return connection.client.socket.writable(queue: worker.eventLoop.queue).then { _ -> Future<PSQLConnection> in
            var data = Data([
                0,0,0,0, // length of message
                0,0,0,0, // Protocol version
                ])
            
            data.withUnsafeMutableBytes { (pointer: UnsafeMutablePointer<Int32>) in
                pointer[1] = 196608 // constant current supported protocol version
            }
            
            data.append(contentsOf: "user".cString)
            data.append(contentsOf: credentials.user.cString)
            
            data.append(contentsOf: "database".cString)
            data.append(contentsOf: credentials.database.cString)
            
            data.withUnsafeMutableBytes { (pointer: UnsafeMutablePointer<Int32>) in
                pointer.pointee = numericCast(data.count)
            }
            
            connection.client.inputStream(data)
            
            return connection.authenticated.map { connection }
        }
    }
}

enum Mechanism: Int32 {
    case ok = 0
    case cleartext = 3
    case md5 = 5
    case sasl = 10
    case saslContinue = 11
    case saslFinal = 12
}

public struct Credentials {
    var user: String
    var password: String
    var database: String
}

extension UnsafeBufferPointer where Element == UInt8 {
    internal var isAuthenticationOK: Bool {
        guard self.count == 9 && self.baseAddress?.pointee == .R else {
            return false
        }
        
        return self.baseAddress?.advanced(by: 5).withMemoryRebound(to: Int32.self, capacity: 1) { pointer in
            return pointer.pointee == 0
        } == true
    }
}

public struct PSQLError: Error {
    init(_ data: ByteBuffer) {}
    init() {}
}
