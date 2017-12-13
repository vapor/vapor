import Security
import TCP
import TLS

/// A TLS client implemented by Apple security module.
public struct AppleTLSClient: TLSClient {
    /// The TLS socket.
    public let socket: AppleTLSSocket

    /// See TLSClient.settings
    public let settings: TLSClientSettings

    /// Underlying TCP client.
    private let tcp: TCPClient

    /// Create a new AppleTLSClient from an AppleTLSSocket.
    /// Use the static `AppleTLSClient.upgrade` method to do this.
    public init(tcp: TCPClient, using settings: TLSClientSettings) throws {
        let socket = try AppleTLSSocket(tcp: tcp.socket, protocolSide: .clientSide)

        if let clientCertificate = settings.clientCertificate {
            try socket.context.setCertificate(to: clientCertificate)
        }

        if let peerDomainName = settings.peerDomainName {
            try assert(status: SSLSetPeerDomainName(socket.context, peerDomainName, peerDomainName.count))
        }

        self.tcp = tcp
        self.settings = settings
        self.socket = socket
    }

    /// Connects and handshakes to the remote server
    public func connect(hostname: String, port: UInt16) throws {
        try tcp.connect(hostname: hostname, port: port)
    }

    /// See TLSClient.close
    public func close() {
        socket.close()
        tcp.close()
    }
}


//import Async
//import Bits
//import Security
//import Foundation
//import Dispatch
//import TLS
//import TCP
//
///// An SSL Client connection that makes use of Apple's Security libraries
//public final class AppleSSLClient: AppleSSLStream, SSLClient {
//    public typealias Output = ByteBuffer
//    
//    /// The underlying socket
//    var socket: TCPSocket
//    
//    /// A buffer of all data that still needs to be written
//    var writeQueue: [Data]
//    
//    /// Keeps a strong reference to the DispatchSourceWrite so it can keep writing
//    var writeSource: DispatchSourceWrite
//    
//    /// Keeps a strong reference to the DispatchSourceRead so it keeps reading
//    var readSource: DispatchSourceRead
//    
//    /// The SSL client's settings
//    public var settings: SSLClientSettings
//    
//    /// The remote peer's domain name
//    public var peerDomainName: String?
//    
//    /// Keeps track of the successful or unsuccessful handshake and connection phase
//    let connected = Promise<Void>()
//    
//    /// A pointer to the descriptor to be used for the SSLContext
//    var descriptor: UnsafeMutablePointer<Int32>
//    
//    /// The `SSLContext` that manages this stream
//    let context: SSLContext
//    
//    /// The queue to read on
//    var queue: DispatchQueue
//    
//    /// A buffer storing all deciphered data received from the remote
//    let outputBuffer = MutableByteBuffer(
//        start: .allocate(capacity: Int(UInt16.max)),
//        count: Int(UInt16.max)
//    )
//    
//    /// Use a basic output stream to implement socket output stream.
//    var outputStream = BasicStream<ByteBuffer>()
//    
//    /// Connects and handshakes to the remote server
//    public func connect(hostname: String, port: UInt16) throws -> Future<Void> {
//        if let peerDomainName = peerDomainName {
//            try assert(status: SSLSetPeerDomainName(context, peerDomainName, peerDomainName.count))
//        }
//        
//        try socket.connect(hostname: hostname, port: port)
//        
//        try self.initialize()
//        
//        return connected.future
//    }
//    
//    /// Creates a new SSL connection
//    public convenience init(settings: SSLClientSettings, on eventLoop: EventLoop) throws {
//        let socket = try TCPSocket()
//        
//        try self.init(upgrading: socket, settings: settings, on: eventLoop)
//    }
//    
//    /// Upgrades an existing TCP socket
//    init(upgrading socket: TCPSocket, settings: SSLClientSettings, on eventLoop: EventLoop) throws {
//        self.socket = socket
//        self.settings = settings
//        self.writeQueue = []
//        
//        guard let context = SSLCreateContext(nil, .clientSide, .streamType) else {
//            throw AppleSSLError(.cannotCreateContext)
//        }
//        
//        self.context = context
//        self.queue = eventLoop.queue
//        
//        self.readSource = DispatchSource.makeReadSource(
//            fileDescriptor: socket.descriptor,
//            queue: eventLoop.queue
//        )
//        
//        self.writeSource = DispatchSource.makeWriteSource(fileDescriptor: socket.descriptor, queue: queue)
//        
//        self.descriptor = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
//        self.descriptor.pointee = self.socket.descriptor
//        
//        if let clientCertificate = settings.clientCertificate {
//            try self.setCertificate(to: clientCertificate, for: context)
//        }
//        
//        self.initializeDispatchSources()
//        
//        self.readSource.resume()
//        self.writeSource.resume()
//    }
//    
//    deinit {
//        outputBuffer.baseAddress?.deallocate(capacity: outputBuffer.count)
//        self.descriptor.deallocate(capacity: 1)
//    }
//}

