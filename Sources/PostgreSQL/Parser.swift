import Async
import Bits
import Crypto
import Foundation
import TCP

final class PSQLParser: Async.InputStream {
    typealias Input = ByteBuffer
    
    let credentials: Credentials
    let client: TCPClient
    let authenticated = Promise<Void>()
    
    init(client: TCPClient, credentials: Credentials) {
        self.client = client
        self.credentials = credentials
    }
    
    func onInput(_ input: ByteBuffer) {
        guard input.count >= 9, let pointer = input.baseAddress else {
            return onError(PSQLError())
        }
        
        switch pointer.pointee {
        case .R:
            onHandshake(for: input)
        default:
            return onError(PSQLError())
        }
    }
    
    func onHandshake(for input: ByteBuffer) {
        guard let pointer = input.baseAddress else {
            return onError(PSQLError())
        }
        
        // Handshake
        let (size, method) = pointer.advanced(by: 1).withMemoryRebound(to: Int32.self, capacity: 2) { pointer in
            return (pointer[0], pointer[1])
        }
        
        guard let mechanism = Mechanism(rawValue: method) else {
            return onError(PSQLError())
        }
        
        if mechanism == .ok {
            authenticated.complete()
            return
        }
        
        let salt: Data
        
        if mechanism == .md5 {
            guard size == 12 else {
                return onError(PSQLError())
            }
            
            salt = Data([
                pointer[8],
                pointer[9],
                pointer[10],
                pointer[11]
                ])
        } else {
            guard size == 8 else {
                return onError(PSQLError())
            }
            
            salt = Data()
        }
        
        mechanism.authenticate(with: credentials, to: client, salt: salt)
    }
    
    func onError(_ error: Error) {
        
    }
    
    func close() {}
    func onClose(_ onClose: ClosableStream) {}
}

extension Mechanism {
    func authenticate(with credentials: Credentials, to client: TCPClient, salt: Data) {
        switch self {
        case .ok:
            return
        case .cleartext, .md5:
            var data = Data([
                .p,
                0,0,0,0, // Message length
            ])
            
            if self == .md5 {
                let string = "md5" + MD5.hash(MD5.hash(credentials.password + credentials.user).hexString.utf8 + salt).hexString
                
                data.append(contentsOf: string.utf8)
            } else {
                data.append(contentsOf: credentials.password.cString)
            }
            
            data.withUnsafeMutableBytes { (pointer: MutableBytesPointer) in
                pointer.advanced(by: 1).withMemoryRebound(to: Int32.self, capacity: 1) { pointer in
                    pointer.pointee = numericCast(data.count - 1)
                }
            }
            
            data.withByteBuffer(client.onInput)
            
            return
        case .sasl:
            return
        case .saslContinue:
            return
        case .saslFinal:
            return
        }
    }
}

extension String {
    var cString: [UInt8] {
        return Array(self.utf8) + [0x00]
    }
}
