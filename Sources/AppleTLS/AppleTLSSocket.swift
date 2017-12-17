import Async
import Bits
import Dispatch
import Foundation
import Security
import TCP
import TLS

/// Apple Security implemented TLS socket.
public final class AppleTLSSocket: TLSSocket {
    /// See DispatchSocket.descriptor
    public var descriptor: Int32 {
        return tcp.descriptor
    }

    /// Underlying TCP socket.
    public let tcp: TCPSocket

    /// The `SSLContext` that manages this stream
    public let context: SSLContext

    /// The connection reference
    private let ref: UnsafeMutablePointer<Int32>

    /// True if the handshake has completed
    private var handshakeCompleted: Bool

    /// True if the socket has been initialized
    private var initCompleted: Bool

    /// Creates an SSL socket
    public init(tcp: TCPSocket, protocolSide: SSLProtocolSide) throws {
        guard let context = SSLCreateContext(nil, protocolSide, .streamType) else {
            throw AppleTLSError(identifier: "cannotCreateContext", reason: "Could not create SSL context")
        }
        self.tcp = tcp
        self.context = context

        let ref = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        ref.pointee = tcp.descriptor
        self.ref = ref
        self.handshakeCompleted = false
        self.initCompleted = false
    }

    /// See TLSSocket.read
    public func read(into buffer: MutableByteBuffer) throws -> Int {
        var processed = 0
        SSLRead(context, buffer.baseAddress!, buffer.count, &processed)
        if processed == 0 {
            self.close()
        }
        return processed
    }

    /// See TLSSocket.write
    public func write(from buffer: ByteBuffer) throws -> Int {
        var processed: Int = 0
        let status = SSLWrite(self.context, buffer.baseAddress!, buffer.count, &processed)
        switch status {
        case 0: break
        case errSSLWouldBlock:
            print("write: errSSLWouldBlock")
        default: throw AppleTLSError.secError(status)
        }

        return processed
    }

    /// See TLSSocket.close
    public func close() {
        SSLClose(context)
        tcp.close()
    }

    /// See DispatchSocket.isPrepared
    public var isPrepared: Bool {
        return handshakeCompleted
    }

    /// See DispatchSocket.prepareSocket
    public func prepareSocket() throws {
        try handshake()
    }

    /// Runs the SSL handshake, regardless of client or server
    private func handshake() throws {
        if !initCompleted {
            try initialize()
            initCompleted = true
        }

        let result = SSLHandshake(context)
        switch result {
        case errSecSuccess:
            handshakeCompleted = true
        case errSSLWouldBlock: break
        default:
            self.close()
            throw AppleTLSError.secError(result)
        }

    }

    /// A helper that initializes SSL as either the client or server side
    private func initialize() throws {
        // Sets the read/write functions
        var status = SSLSetIOFuncs(context, readSSL, writeSSL)

        guard status == 0 else {
            throw AppleTLSError.secError(status)
        }

        // Adds the file descriptor to this connection
        status = SSLSetConnection(context, ref)
        guard status == 0 else {
            throw AppleTLSError.secError(status)
        }
    }

    deinit {
        ref.deinitialize()
        ref.deallocate(capacity: 1)
    }
}

/// Fileprivate helper that reads from the SSL connection
fileprivate func readSSL(ref: SSLConnectionRef, pointer: UnsafeMutableRawPointer, length: UnsafeMutablePointer<Int>) -> OSStatus {
    // Reads the provided descriptor
    let socket = ref.assumingMemoryBound(to: Int32.self).pointee
    let lengthRequested = length.pointee

    // read encrypted data
    var readCount = Darwin.read(socket, pointer, lengthRequested)

    // The length pointer needs to be updated to indicate the received bytes
    length.initialize(to: readCount)

    // If there's no error, no data
    if readCount == 0 {
        length.initialize(to: 0)
        return OSStatus(errSSLClosedGraceful)

        // On error
    } else if readCount < 0 {
        readCount = 0
        length.initialize(to: 0)

        switch errno {
        case ENOENT:
            return OSStatus(errSSLClosedGraceful)
        case EAGAIN:
            return OSStatus(errSSLWouldBlock)
        case EWOULDBLOCK:
            return OSStatus(errSSLWouldBlock)
        case ECONNRESET:
            return OSStatus(errSSLClosedAbort)
        default:
            return OSStatus(errSecIO)
        }
    }

    length.initialize(to: readCount)

    // No errors, requested data
    return readCount == lengthRequested ? errSecSuccess : errSSLWouldBlock
}

/// Fileprivate helper that writes to the SSL connection
fileprivate func writeSSL(ref: SSLConnectionRef, pointer: UnsafeRawPointer, length: UnsafeMutablePointer<Int>) -> OSStatus {
    // Reads the provided descriptor
    let socket = ref.assumingMemoryBound(to: Int32.self).pointee
    let toWrite = length.pointee

    // Sends the encrypted data
    var writeCount = Darwin.send(socket, pointer, toWrite, 0)

    // Updates the written byte count
    length.initialize(to: writeCount)

    // When the connection is closed
    if writeCount == 0 {
        return OSStatus(errSSLClosedGraceful)

        // On error
    } else if writeCount < 0 {
        writeCount = 0

        guard errno == EAGAIN else {
            return OSStatus(errSecIO)
        }

        return OSStatus(errSSLWouldBlock)
    }

    // TODO: Is this right?
    guard toWrite <= writeCount else {
        return Int32(errSSLWouldBlock)
    }

    return noErr
}

