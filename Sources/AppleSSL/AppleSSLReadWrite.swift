#if os(macOS) || os(iOS)
    import Core
    import Security
    import Dispatch
    
    extension AppleSSLStream {
        /// A helper that initializes SSL as either the client or server side
        func initialize(side: SSLProtocolSide) throws -> SSLContext {
            guard context == nil else {
                throw Error.contextAlreadyCreated
            }
            
            guard let context = SSLCreateContext(nil, side, .streamType) else {
                throw Error.cannotCreateContext
            }
            
            self.context = context
            
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
    }
    
    /// Fileprivate helper that reads from the SSL connection
    fileprivate func readSSL(ref: SSLConnectionRef, pointer: UnsafeMutableRawPointer, length: UnsafeMutablePointer<Int>) -> OSStatus {
        // Reads the provided descriptor
        let socket = ref.assumingMemoryBound(to: Int32.self).pointee
        
        let lengthRequested = length.pointee
        
        // read encrypted data
        var readCount = Darwin.recv(socket, pointer, lengthRequested, 0)
        
        // The length pointer needs to be updated to indicate the received bytes
        length.initialize(to: readCount)
        
        // If there's no error, no data
        if readCount == 0 {
            return OSStatus(errSSLClosedGraceful)
            
        // On error
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
        
        // TODO: Is this right?
        guard lengthRequested <= readCount else {
            return OSStatus(errSSLWouldBlock)
        }
        
        // No errors, requested data
        return noErr
    }
    
    /// Fileprivate helper that writes to the SSL connection
    fileprivate func writeSSL(ref: SSLConnectionRef, pointer: UnsafeRawPointer, length: UnsafeMutablePointer<Int>) -> OSStatus {
        // Reads the provided descriptor
        let context = ref.bindMemory(to: Int32.self, capacity: 1).pointee
        let toWrite = length.pointee
        
        // Sends the encrypted data
        var writeCount = Darwin.send(context, pointer, toWrite, 0)
        
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
#endif
