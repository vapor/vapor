import Async
import Bits
import Foundation
import Security

extension SSLStream {
    /// Runs the SSL handshake, regardless of client or server
    func handshake(for context: SSLContext) throws -> Future<Void> {
        var result = SSLHandshake(context)
        
        // If the success is immediate
        if result == errSecSuccess || result == errSSLPeerAuthCompleted {
            return Future(())
        }
        
        // Otherwise set up a readsource
        let readSource = DispatchSource.makeReadSource(fileDescriptor: self.descriptor, queue: self.queue)
        let promise = Promise<Void>()
        
        // Listen for input
        readSource.setEventHandler {
            // On input, continue the handshake
            result = SSLHandshake(context)
            
            if result == errSSLWouldBlock {
                return
            }
            
            // If it's not blocking and not a success, it's an error
            guard result == errSecSuccess || result == errSSLPeerAuthCompleted else {
                readSource.cancel()
                promise.fail(Error(.sslError(result)))
                return
            }
            
            readSource.cancel()
            promise.complete(())
        }
        
        // Now that the async stuff's et up, let's start your engines
        readSource.resume()
        
        let future = promise.future
        
        future.addAwaiter { _ in
            self.readSource = nil
        }
        
        self.readSource = readSource
        
        return future
    }
    
    /// Starts receiving data from the client, reads on the provided queue
    public func start() {
        let source = DispatchSource.makeReadSource(
            fileDescriptor: self.descriptor,
            queue: self.queue
        )
        
        source.setEventHandler {
            let read: Int
            do {
                read = try self.read(into: self.outputBuffer)
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
            if let context = self.context {
                SSLClose(context)
            }
            
            self.close()
        }
        
        source.resume()
        self.readSource = source
    }
}
