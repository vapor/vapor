import Core
import TCP
import Dispatch

enum Error: Swift.Error {
    case cannotCreateContext
    case writeError
    case contextAlreadyCreated
    case noSSLContext
    case sslError(Int32)
    case invalidCertificate
}

#if os(macOS) || os(iOS)
    import Core
    import Foundation
    import Security
    
    /// https://developer.apple.com/documentation/security/secure_transport
    public class AppleSSLSocket: TCP.Socket, Core.Stream {
        public typealias Output = ByteBuffer
        public typealias Input = ByteBuffer
        
        public var outputStream: OutputHandler?
        public var errorStream: ErrorHandler?
        
        var context: SSLContext?
        let socket: Socket
        public var outputBuffer = MutableByteBuffer(start: .allocate(capacity: Int(UInt16.max)), count: Int(UInt16.max))
        var descriptorCopy = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        private var source: DispatchSourceRead?
        
        deinit {
            descriptorCopy.deallocate(capacity: 1)
        }
        
        public init(socket: Socket) {
            self.socket = socket
        }
        
        func initialize(side: SSLProtocolSide) throws -> SSLContext {
            guard context == nil else {
                throw Error.contextAlreadyCreated
            }
            
            guard let context = SSLCreateContext(nil, side, .streamType) else {
                throw Error.cannotCreateContext
            }
            
            self.context = context
            
            descriptorCopy.pointee = self.socket.descriptor
            
            var status = SSLSetIOFuncs(context, readSSL, writeSSL)
                
            guard status == 0 else {
                throw Error.sslError(status)
            }
            
            status = SSLSetConnection(context, descriptorCopy)
            
            guard status == 0 else {
                throw Error.sslError(status)
            }
            
            return context
        }
        
        func handshake(for context: SSLContext) throws {
            var result: Int32
            
            repeat {
                result = SSLHandshake(context)
            } while result == errSSLWouldBlock
            
            guard result == errSecSuccess || result == errSSLPeerAuthCompleted else {
                throw Error.sslError(result)
            }
        }
        
        @discardableResult
        public override func write(max: Int, from buffer: ByteBuffer) throws -> Int {
            guard let context = self.context else {
                close()
                throw Error.noSSLContext
            }
            
            var processed = 0
            
            SSLWrite(context, buffer.baseAddress, buffer.count, &processed)
            
            return processed
        }
        
        @discardableResult
        public override func read(max: Int, into buffer: MutableByteBuffer) throws -> Int {
            guard let context = self.context else {
                close()
                throw Error.noSSLContext
            }
            
            var processed = 0
            
            SSLRead(context, buffer.baseAddress!, buffer.count, &processed)
            
            return processed
        }
        
        public func inputStream(_ input: ByteBuffer) {
            do {
                try self.write(max: input.count, from: input)
            } catch {
                self.errorStream?(error)
                self.close()
            }
        }
        
        public func setCertificate(to certificate: Data, for context: SSLContext) throws {
            guard let certificate = SecCertificateCreateWithData(nil, certificate as CFData) else {
                throw Error.invalidCertificate
            }
            
            var ref: SecIdentity?
            
            var error = SecIdentityCreateWithCertificate(nil, certificate, &ref)
            
            guard error == errSecSuccess else {
                throw Error.invalidCertificate
            }
            
            error = SSLSetCertificate(context, [ref as Any, certificate] as CFArray)
            
            guard error == errSecSuccess else {
                throw Error.invalidCertificate
            }
        }
        
        /// Starts receiving data from the client
        public func start(on queue: DispatchQueue) {
            let source = DispatchSource.makeReadSource(
                fileDescriptor: self.descriptor.raw,
                queue: queue
            )
            
            source.setEventHandler {
                let read: Int
                do {
                    read = try self.read(
                        max: self.outputBuffer.count,
                        into: self.outputBuffer
                    )
                } catch {
                    // any errors that occur here cannot be thrown,
                    // so send them to stream error catcher.
                    self.errorStream?(error)
                    return
                }
                
                guard read > 0 else {
                    // need to close!!! gah
                    self.close()
                    return
                }
                
                // create a view into the internal buffer and
                // send to the output stream
                let bufferView = ByteBuffer(
                    start: self.outputBuffer.baseAddress,
                    count: read
                )
                self.outputStream?(bufferView)
            }
            
            source.setCancelHandler {
                self.close()
            }
            
            source.resume()
            self.source = source
        }
        
        public override func close() {
            guard let context = context else {
                return
            }
            
            SSLClose(context)
            super.close()
        }
    }
    
    fileprivate func readSSL(ref: SSLConnectionRef, pointer: UnsafeMutableRawPointer, length: UnsafeMutablePointer<Int>) -> OSStatus {
        let socket = ref.assumingMemoryBound(to: Int32.self).pointee
        let lengthRequested = length.pointee
        
        var readCount = Darwin.recv(socket, pointer, lengthRequested, 0)
        
        defer { length.initialize(to: readCount) }
        if readCount == 0 {
            return OSStatus(errSSLClosedGraceful)
        } else if readCount < 0 {
            readCount = 0
            
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
        
        guard lengthRequested <= readCount else {
            return OSStatus(errSSLWouldBlock)
        }
        
        return noErr
    }
    
    fileprivate func writeSSL(ref: SSLConnectionRef, pointer: UnsafeRawPointer, length: UnsafeMutablePointer<Int>) -> OSStatus {
        let context = ref.bindMemory(to: Int32.self, capacity: 1).pointee
        let toWrite = length.pointee
        
        var writeCount = Darwin.send(context, pointer, toWrite, 0)
        
        defer { length.initialize(to: writeCount) }
        if writeCount == 0 {
            return OSStatus(errSSLClosedGraceful)
        } else if writeCount < 0 {
            writeCount = 0
            
            guard errno == EAGAIN else {
                return OSStatus(errSecIO)
            }
            
            return OSStatus(errSSLWouldBlock)
        }
        
        guard toWrite <= writeCount else {
            return Int32(errSSLWouldBlock)
        }
        
        return noErr
    }
#endif
