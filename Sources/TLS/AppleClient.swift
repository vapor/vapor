import Security
import Core
import Dispatch

public final class AppleSSLClient: AppleSSLSocket, Core.Stream {
    public var outputBuffer = MutableByteBuffer(start: .allocate(capacity: Int(UInt16.max)), count: Int(UInt16.max))
    private var source: DispatchSourceRead?
    
    public typealias Output = ByteBuffer
    public typealias Input = ByteBuffer
    
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?
    
    public func inputStream(_ input: ByteBuffer) {
        do {
            try self.write(max: input.count, from: input)
        } catch {
            self.errorStream?(error)
            self.close()
        }
    }
    
    public func initializeSSLClient(hostname: String) throws {
        let context = try self.initialize(side: .clientSide)
        
        var hostname = [Int8](hostname.utf8.map { Int8($0) })
        let status = SSLSetPeerDomainName(context, &hostname, hostname.count)
        
        guard status == 0 else {
            throw Error.sslError(status)
        }
        
        try handshake(for: context)
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
}
