// **** Hummingbird Notes
/*
 - Made socket final
 - `recv` should possibly be renamed to `read` or `receive` we're not saving anything w/ shorter.
 - Add this somewhere `If you want to listen for requests use bind; if you want to connect to a server use connect`
 - Using `!closed` because "It's possible the passed in socket is already open, such as the case with the accept flow"
 Possible
 - `recv` should return just `[UInt8]`. String overload requires types always where it's not worth it, like `let str: [UInt8] = try socket.receive()`
 */
// ****

// MARK: TEMPORARY INCLUSION FOR COMPILER ISSUES

//
//  Socket.swift
//  Hummingbird
//
//  Created by James Richard on 2/8/16.
//
//

//import Strand

#if os(Linux)
    import Glibc
let sockStream = Int32(SOCK_STREAM.rawValue)
let systemAccept = Glibc.accept
let systemClose = Glibc.close
let systemListen = Glibc.listen
let systemRecv = Glibc.recv
let systemSend = Glibc.send
let systemBind = Glibc.bind
let systemConnect = Glibc.connect
let systemGetHostByName = Glibc.gethostbyname
#else
    import Darwin.C
let sockStream = SOCK_STREAM
let systemAccept = Darwin.accept
let systemClose = Darwin.close
let systemListen = Darwin.listen
let systemRecv = Darwin.recv
let systemSend = Darwin.send
let systemBind = Darwin.bind
let systemConnect = Darwin.connect
let systemGetHostByName = Darwin.gethostbyname
#endif

public enum SocketError: ErrorType {
    case AcceptConsecutivelyFailing(code: Int, message: String?)
    case BindingFailed(code: Int, message: String?)
    case CloseFailed(code: Int, message: String?)
    case ListenFailed(code: Int, message: String?)
    case RecvFailed(code: Int, message: String?)
    case ConnectFailed(code: Int, message: String?)
    case HostInformationIncomplete(message: String)
    case InvalidData
    case InvalidPort
    case SendFailed(code: Int, message: String?, sent: Int)
    case ObtainingAddressInformationFailed(code: Int, message: String?)
    case SocketCreationFailed(code: Int, message: String?)
    case SocketConfigurationFailed(code: Int, message: String?)
    case SocketClosed
    case StringTranscodingFailed
    case FailedToGetIPFromHostname(code: Int, message: String?)
}


public struct Hummingbird {
    // Here to simulate module version for testing
    //public struct Hummingbird {
    /// A `Socket` represents a socket descriptor.
    public final class Socket {
        let socketDescriptor: Int32
        private var closed = false
        
        /**
         Initialize a `Socket` with a given socket descriptor. The socket descriptor must be open, and further operations on
         the socket descriptor should be through the `Socket` class to properly manage open state.
         
         - parameter    socketDescriptor:   An open socket file descriptor.
         */
        public init(socketDescriptor: Int32) {
            self.socketDescriptor = socketDescriptor
        }
        
        /**
         Creates a new IPv4 TCP socket.
         
         - throws: `SocketError.SocketCreationFailed` if creating the socket failed.
         */
        public class func streamSocket() throws -> Socket {
            #if os(Linux)
                let sd = socket(AF_INET, sockStream, 0)
            #else
                let sd = socket(AF_INET, sockStream, IPPROTO_TCP)
            #endif
            
            guard sd >= 0 else {
                throw SocketError.SocketCreationFailed(code: Int(errno), message: String.fromCString(strerror(errno)))
            }
            
            return Socket(socketDescriptor: sd)
        }
        
        deinit {
            if !closed {
                systemClose(socketDescriptor)
            }
        }
        
        /**
         Binds the socket to a given address and port.
         
         The socket must be open, and must not already be binded.
         
         - parameter    address:    The address to bind to. If no address is given, use any address.
         - parameter    port:       The port to bind it. If no port is given, bind to a random port.
         - throws:      `SocketError.SocketClosed` if the socket is closed.
         `SocketError.SocketConfigurationFailed` when setting SO_REUSEADDR on the socket fails.
         `SocketError.InvalidPort` when converting the port to `in_port_t` fails.
         `SocketError.BindingFailed` if the system bind command fails.
         */
        public func bind(address: String?, port: String?) throws {
            guard !closed else { throw SocketError.SocketClosed }
            var optval: Int = 1;
            
            guard setsockopt(socketDescriptor, SOL_SOCKET, SO_REUSEADDR, &optval, socklen_t(sizeof(Int))) != -1 else {
                systemClose(socketDescriptor)
                closed = true
                throw SocketError.SocketConfigurationFailed(code: Int(errno), message: String.fromCString(strerror(errno)))
            }
            
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            
            if let port = port {
                guard let convertedPort = in_port_t(port) else {
                    throw SocketError.InvalidPort
                }
                
                addr.sin_port = in_port_t(htons(convertedPort))
            }
            
            if let address = address {
                addr.sin_addr = in_addr(s_addr: address.withCString { inet_addr($0) })
            }
            
            addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
            
            let len = socklen_t(UInt8(sizeof(sockaddr_in)))
            guard systemBind(socketDescriptor, sockaddr_cast(&addr), len) != -1 else {
                throw SocketError.BindingFailed(code: Int(errno), message: String.fromCString(strerror(errno)))
            }
        }
        
        /**
         Connect to a given address and port.
         
         The socket must be open, and not already connected or binded.
         
         - parameter    address:    The address to connect to. This can be an IPv4 address, or a hostname that
         can be resolved to an IPv4 address.
         - parameter    port:       The port to connect to.
         - throws:      `SocketError.SocketClosed` if the socket is closed.
         `SocketError.InvalidPort` when converting the port to `in_port_t` fails.
         `SocketError.FailedToGetIPFromHostname` when obtaining an IP from a hostname fails.
         `SocketError.HostInformationIncomplete` if the IP information obtained is incomplete or incompatible.
         `SocketError.ConnectFailed` if the system connect fall fails.
         */
        public func connect(address: String, port: String) throws {
            guard !closed else { throw SocketError.SocketClosed }
            
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            
            guard let convertedPort = in_port_t(port) else {
                throw SocketError.InvalidPort
            }
            
            if inet_pton(AF_INET, address, &addr.sin_addr) != 1 {
                addr.sin_addr = try getAddrFromHostname(address)
            }
            
            addr.sin_port = in_port_t(htons(convertedPort))
            addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
            
            let len = socklen_t(UInt8(sizeof(sockaddr_in)))
            
            guard systemConnect(socketDescriptor, sockaddr_cast(&addr), len) >= 0 else {
                throw SocketError.ConnectFailed(code: Int(errno), message: String.fromCString(strerror(errno)))
            }
        }
        
        /**
         Listen for connections.
         
         - parameter    backlog:    The maximum length for the queue of pending connections.
         - throws:      `SocketError.SocketClosed` if the socket is closed.
         `SocketError.ListenFailed` if the system listen fails.
         */
        public func listen(backlog: Int = 100) throws {
            guard !closed else { throw SocketError.SocketClosed }
            
            if systemListen(socketDescriptor, Int32(backlog)) != 0 {
                throw SocketError.ListenFailed(code: Int(errno), message: String.fromCString(strerror(errno)))
            }
        }
        
        /**
         Begin accepting connections. When a connection is accepted, a new thread is created by the system `accept` command.
         
         - parameter    maximumConsecutiveFailures:     The maximum number of failures the system accept can have consecutively.
         Passing a negative number means an unlimited number of consecutive errors.
         Defaults to SOMAXCONN.
         - parameter    connectionHandler:              The closure executed when a connection is established.
         - throws:      `SocketError.SocketClosed` if the socket is closed.
         `SocketError.AcceptConsecutivelyFailing` if a the system accept fails a consecutive number of times that
         exceeds a positive `maximumConsecutiveFailures`.
         */
        public func accept(maximumConsecutiveFailures: Int = Int(SOMAXCONN), connectionHandler: (Socket) -> Void) throws {
            guard !closed else { throw SocketError.SocketClosed }
            
            var consecutiveFailedAccepts = 0
            ACCEPT_LOOP: while true {
                var connectedAddrInfo = sockaddr_in()
                var connectedAddrInfoLength = socklen_t(sizeof(sockaddr_in))
                
                let requestDescriptor = systemAccept(socketDescriptor, sockaddr_cast(&connectedAddrInfo), &connectedAddrInfoLength)
                
                if requestDescriptor == -1 {
                    consecutiveFailedAccepts += 1
                    guard maximumConsecutiveFailures >= 0 && consecutiveFailedAccepts < maximumConsecutiveFailures else {
                        throw SocketError.AcceptConsecutivelyFailing(code: Int(errno), message: String.fromCString(strerror(errno)))
                    }
                    continue
                }
                
                consecutiveFailedAccepts = 0
                
                _ = try Strand {
                    connectionHandler(Socket(socketDescriptor: requestDescriptor))
                }
            }
        }
        
        /**
         Sends a sequence of data to the socket. The system send call may be called numberous times to send all of the data
         contained in the sequence.
         
         - parameter        data:       The sequence of data to send.
         - throws:          `SocketError.SocketClosed` if the socket is closed.
         `SocketError.SendFailed` if any invocation of the system send fails.
         */
        public func send<DataSequence: SequenceType where DataSequence.Generator.Element == UInt8>(data: DataSequence) throws {
            guard !closed else { throw SocketError.SocketClosed }
            
            #if os(Linux)
                let flags = Int32(MSG_NOSIGNAL)
            #else
                let flags = Int32(0)
            #endif
            
            let dataArray = [UInt8](data)
            
            try dataArray.withUnsafeBufferPointer { buffer in
                var sent = 0
                while sent < dataArray.count {
                    let s = systemSend(socketDescriptor, buffer.baseAddress + sent, dataArray.count - sent, flags)
                    
                    if s == -1 {
                        throw SocketError.SendFailed(code: Int(errno), message: String.fromCString(strerror(errno)), sent: sent)
                    }
                    
                    sent += s
                }
            }
        }
        
        /**
         Sends a `String` to the socket. The string is sent in its UTF8 representation. The system send call may
         be called numberous times to send all of the data contained in the sequence.
         
         - parameter        string:     The string to send.
         - throws:          `SocketError.SocketClosed` if the socket is closed.
         `SocketError.SendFailed` if any invocation of the system send fails.
         */
        public func send(string: String) throws {
            try send(string.utf8)
        }
        
        //    /**
        //     Receives a `String` from the socket. The data being sent must be UTF8-encoded data that can be
        //     transcoded into a `String`.
        //
        //     - parameter    bufferSize:     The amount of space allocated to read data into.
        //     - returns:     A `String` representing the data received.
        //     - throws:      `SocketError.SocketClosed` if the socket is closed.
        //     `SocketError.RecvFailed` when the system recv call fails.
        //     `SocketError.StringTranscodingFailed` if the received data could not be transcoded.
        //     */
        //    public func recv(bufferSize: Int = 1024) throws -> String {
        //        guard let transcodedString = String(utf8: try recv(bufferSize)) else { throw SocketError.StringTranscodingFailed }
        //        return transcodedString
        //    }
        
        /**
         Receives an array of `UInt8` values from the socket.
         
         - parameter    bufferSize:     The amount of space allocated to read data into.
         - returns:     The received array of UInt8 values.
         - throws:      `SocketError.SocketClosed` if the socket is closed.
         `SocketError.RecvFailed` when the system recv call fails.
         */
        public func recv(bufferSize: Int = 1024) throws -> [UInt8] {
            guard !closed else { throw SocketError.SocketClosed }
            let buffer = UnsafeMutablePointer<UInt8>.alloc(bufferSize)
            
            defer { buffer.dealloc(bufferSize) }
            
            let bytesRead = systemRecv(socketDescriptor, buffer, bufferSize, 0)
            
            if bytesRead == -1 {
                throw SocketError.RecvFailed(code: Int(errno), message: String.fromCString(strerror(errno)))
            }
            
            guard bytesRead != 0 else {
                return []
            }
            
            var readData = [UInt8]()
            for i in 0 ..< bytesRead {
                readData.append(buffer[i])
            }
            
            return readData
        }
        
        /**
         Closes the socket.
         
         - throws:  `SocketError.SocketClosed` if the socket is already closed.
         `SocketError.CloseFailed` when the system close command fials
         */
        public func close() throws {
            guard !closed else { throw SocketError.SocketClosed }
            guard systemClose(socketDescriptor) != -1 else {
                throw SocketError.CloseFailed(code: Int(errno), message: String.fromCString(strerror(errno)))
            }
            closed = true
        }
        
        // MARK: - Host resolution
        private func getAddrFromHostname(hostname: String) throws -> in_addr {
            let hostInfoPointer = systemGetHostByName(hostname)
            
            guard hostInfoPointer != nil else {
                throw SocketError.FailedToGetIPFromHostname(code: Int(errno), message: String.fromCString(strerror(errno)))
            }
            
            let hostInfo = hostInfoPointer.memory
            
            guard hostInfo.h_addrtype == AF_INET else {
                throw SocketError.HostInformationIncomplete(message: "No IPv4 address")
            }
            
            guard hostInfo.h_addr_list != nil else {
                throw SocketError.HostInformationIncomplete(message: "List is empty")
            }
            
            let addrStruct = sockadd_list_cast(hostInfo.h_addr_list)[0].memory
            return addrStruct
        }
        
        
        // MARK: - Utility casts
        private func htons(value: CUnsignedShort) -> CUnsignedShort {
            return (value << 8) + (value >> 8)
        }
        
        private func sockaddr_cast(p: UnsafeMutablePointer<Void>) -> UnsafeMutablePointer<sockaddr> {
            return UnsafeMutablePointer<sockaddr>(p)
        }
        
        private func sockaddr_in_cast(p: UnsafeMutablePointer<sockaddr_in>) -> UnsafeMutablePointer<sockaddr> {
            return UnsafeMutablePointer<sockaddr>(p)
        }
        
        private func sockadd_list_cast(p: UnsafeMutablePointer<UnsafeMutablePointer<Int8>>) -> UnsafeMutablePointer<UnsafeMutablePointer<in_addr>> {
            return UnsafeMutablePointer<UnsafeMutablePointer<in_addr>>(p)
        }
    }
}
//}

extension Hummingbird.Socket: Hashable {
    public var hashValue: Int { return Int(socketDescriptor) }
}

public func ==(lhs: Hummingbird.Socket, rhs: Hummingbird.Socket) -> Bool {
    return lhs.socketDescriptor == rhs.socketDescriptor
}

// MARK: More temporary until I can figure out compiler issue

//
//  Strand.swift
//  Strand
//
//  Created by James Richard on 3/1/16.
//

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

public enum StrandError: ErrorType {
    case ThreadCreationFailed
    case ThreadCancellationFailed(Int)
    case ThreadJoinFailed(Int)
}

public class Strand {
    #if os(Linux)
    private var pthread: pthread_t = 0
    #else
    private var pthread: pthread_t = nil
    #endif
    
    public init(closure: () -> Void) throws {
        let holder = Unmanaged.passRetained(StrandClosure(closure: closure))
        let pointer = UnsafeMutablePointer<Void>(holder.toOpaque())
        
        guard pthread_create(&pthread, nil, runner, pointer) == 0 else { throw StrandError.ThreadCreationFailed }
        pthread_detach(pthread)
    }
    
    public func join() throws {
        let status = pthread_join(pthread, nil)
        if status != 0 {
            throw StrandError.ThreadJoinFailed(Int(status))
        }
    }
    
    public func cancel() throws {
        let status = pthread_cancel(pthread)
        if status != 0 {
            throw StrandError.ThreadCancellationFailed(Int(status))
        }
    }
    
    #if swift(>=3.0)
    public class func exit(code: inout Int) {
        pthread_exit(&code)
    }
    #else
    public class func exit(inout code: Int) {
    pthread_exit(&code)
    }
    #endif
}

private func runner(arg: UnsafeMutablePointer<Void>) -> UnsafeMutablePointer<Void> {
    let unmanaged = Unmanaged<StrandClosure>.fromOpaque(COpaquePointer(arg))
    unmanaged.takeUnretainedValue().closure()
    unmanaged.release()
    return UnsafeMutablePointer<Void>()
}

private class StrandClosure {
    let closure: () -> Void
    
    init(closure: () -> Void) {
        self.closure = closure
    }
}

