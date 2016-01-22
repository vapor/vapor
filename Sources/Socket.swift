//
// Based on HttpSocket from Swifter (https://github.com/glock45/swifter) by Damian Kołakowski.
//

#if os(Linux)
    import Glibc
#else
    import Foundation
#endif

enum SocketError: ErrorType {
    case SocketCreationFailed(String)
    case SocketSettingReUseAddrFailed(String)
    case BindFailed(String)
    case ListenFailed(String)
    case WriteFailed(String)
    case GetPeerNameFailed(String)
    case ConvertingPeerNameFailed
    case GetNameInfoFailed(String)
    case AcceptFailed(String)
    case RecvFailed(String)
}

class Socket: Hashable, Equatable {
    
    class func tcpSocketForListen(port: in_port_t, maxPendingConnection: Int32 = SOMAXCONN) throws -> Socket {
        
        #if os(Linux)
            let socketFileDescriptor = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #else
            let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        #endif
        
        if socketFileDescriptor == -1 {
            throw SocketError.SocketCreationFailed(Socket.descriptionOfLastError())
        }
        
        var value: Int32 = 1
        if setsockopt(socketFileDescriptor, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(sizeof(Int32))) == -1 {
            let details = Socket.descriptionOfLastError()
            Socket.release(socketFileDescriptor)
            throw SocketError.SocketSettingReUseAddrFailed(details)
        }
        Socket.setNoSigPipe(socketFileDescriptor)
        
        #if os(Linux)
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = Socket.htonsPort(port)
            addr.sin_addr = in_addr(s_addr: in_addr_t(0))
            addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        #else
            var addr = sockaddr_in()
            addr.sin_len = __uint8_t(sizeof(sockaddr_in))
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = Socket.htonsPort(port)
            addr.sin_addr = in_addr(s_addr: inet_addr("0.0.0.0"))
            addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        #endif
        
        var bind_addr = sockaddr()
        memcpy(&bind_addr, &addr, Int(sizeof(sockaddr_in)))
        
        if bind(socketFileDescriptor, &bind_addr, socklen_t(sizeof(sockaddr_in))) == -1 {
            let details = Socket.descriptionOfLastError()
            Socket.release(socketFileDescriptor)
            throw SocketError.BindFailed(details)
        }
        
        if listen(socketFileDescriptor, maxPendingConnection ) == -1 {
            let details = Socket.descriptionOfLastError()
            Socket.release(socketFileDescriptor)
            throw SocketError.ListenFailed(details)
        }
        return Socket(socketFileDescriptor: socketFileDescriptor)
    }
    
    private let socketFileDescriptor: Int32
    
    init(socketFileDescriptor: Int32) {
        self.socketFileDescriptor = socketFileDescriptor
    }
    
    var hashValue: Int { return Int(self.socketFileDescriptor) }
    
    func release() {
        Socket.release(self.socketFileDescriptor)
    }
    
    func shutdwn() {
        Socket.shutdwn(self.socketFileDescriptor)
    }
    
    func acceptClientSocket() throws -> Socket {
        var addr = sockaddr()        
        var len: socklen_t = 0
        let clientSocket = accept(self.socketFileDescriptor, &addr, &len)
        if clientSocket == -1 {
            throw SocketError.AcceptFailed(Socket.descriptionOfLastError())
        }
        Socket.setNoSigPipe(clientSocket)
        return Socket(socketFileDescriptor: clientSocket)
    }
    
    func writeUTF8(string: String) throws {
        try writeUInt8([UInt8](string.utf8))
    }
    
    func writeUInt8(data: [UInt8]) throws {
        try data.withUnsafeBufferPointer {
            var sent = 0
            while sent < data.count {
                #if os(Linux)
                    let s = send(self.socketFileDescriptor, $0.baseAddress + sent, Int(data.count - sent), Int32(MSG_NOSIGNAL))
                #else
                    let s = write(self.socketFileDescriptor, $0.baseAddress + sent, Int(data.count - sent))
                #endif
                if s <= 0 {
                    throw SocketError.WriteFailed(Socket.descriptionOfLastError())
                }
                sent += s
            }
        }
    }
    
    func read() throws -> UInt8 {
        var buffer = [UInt8](count: 1, repeatedValue: 0)
        let next = recv(self.socketFileDescriptor as Int32, &buffer, Int(buffer.count), 0)
        if next <= 0 {
            throw SocketError.RecvFailed(Socket.descriptionOfLastError())
        }
        return buffer[0]
    }
    
    private static let CR = UInt8(13)
    private static let NL = UInt8(10)
    
    func readLine() throws -> String {
        var characters: String = ""
        var n: UInt8 = 0
        repeat {
            n = try self.read()
            if n > Socket.CR { characters.append(Character(UnicodeScalar(n))) }
        } while n != Socket.NL
        return characters
    }
    
    func peername() throws -> String {
        var addr = sockaddr(), len: socklen_t = socklen_t(sizeof(sockaddr))
        if getpeername(self.socketFileDescriptor, &addr, &len) != 0 {
            throw SocketError.GetPeerNameFailed(Socket.descriptionOfLastError())
        }
        var hostBuffer = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
        if getnameinfo(&addr, len, &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST) != 0 {
            throw SocketError.GetNameInfoFailed(Socket.descriptionOfLastError())
        }
        guard let name = String.fromCString(hostBuffer) else {
            throw SocketError.ConvertingPeerNameFailed
        }
        return name
    }
    
    private class func descriptionOfLastError() -> String {
        return String.fromCString(UnsafePointer(strerror(errno))) ?? "Error: \(errno)"
    }
    
    private class func setNoSigPipe(socket: Int32) {
        #if os(Linux)
            // There is no SO_NOSIGPIPE in Linux (nor some other systems). You can instead use the MSG_NOSIGNAL flag when calling send(),
            // or use signal(SIGPIPE, SIG_IGN) to make your entire application ignore SIGPIPE.
        #else
            // Prevents crashes when blocking calls are pending and the app is paused ( via Home button ).
            var no_sig_pipe: Int32 = 1
            setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &no_sig_pipe, socklen_t(sizeof(Int32)))
        #endif
    }
    
    private class func shutdwn(socket: Int32) {
        #if os(Linux)
            shutdown(socket, Int32(SHUT_RDWR))
        #else
            Darwin.shutdown(socket, SHUT_RDWR)
        #endif
    }
    
    private class func release(socket: Int32) {
        #if os(Linux)
            shutdown(socket, Int32(SHUT_RDWR))
        #else
            Darwin.shutdown(socket, SHUT_RDWR)
        #endif
        close(socket)
    }
    
    private class func htonsPort(port: in_port_t) -> in_port_t {
        #if os(Linux)
            return htons(port)
        #else
            let isLittleEndian = Int(OSHostByteOrder()) == OSLittleEndian
            return isLittleEndian ? _OSSwapInt16(port) : port
        #endif
    }
}

func ==(socket1: Socket, socket2: Socket) -> Bool {
    return socket1.socketFileDescriptor == socket2.socketFileDescriptor
}