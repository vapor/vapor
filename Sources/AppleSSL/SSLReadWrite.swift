import Bits
import Security
import Foundation
import Dispatch

extension AppleSSLStream {
    /// A helper that initializes SSL as either the client or server side
    func initialize() throws {
        // Sets the read/write functions
        var status = SSLSetIOFuncs(context, readSSL, writeSSL)
        
        guard status == 0 else {
            throw AppleSSLError(.sslError(status))
        }
        
        // Adds the file descriptor to this connection
        status = SSLSetConnection(context, self.descriptor)
        
        guard status == 0 else {
            throw AppleSSLError(.sslError(status))
        }
    }
    
    /// Writes to AppleSSL using the provided buffer
    ///
    /// If `allowWouldBlock` is true, when a "would block" occurs, the data will be appended to the writeQueue
    /// Otherwise an error will be thrown
    @discardableResult
    func write(from buffer: ByteBuffer, allowWouldBlock: Bool) throws -> Int {
        var processed = 0
        
        let status = SSLWrite(context, buffer.baseAddress, buffer.count, &processed)
        
        guard status > 0 else {
            // Clean close
            if status == 0 {
                self.close()
                return 0
            } else if status == errSSLWouldBlock {
                writeQueue.append(Data(buffer))
                
                // Wasn't already running
                if writeQueue.count == 1 {
                    writeSource.resume()
                }
                
                return buffer.count
                // Error
            } else {
                throw AppleSSLError(.sslError(status))
            }
        }
        
        return processed
    }
}

/// Fileprivate helper that reads from the SSL connection
fileprivate func readSSL(ref: SSLConnectionRef, pointer: UnsafeMutableRawPointer, length: UnsafeMutablePointer<Int>) -> OSStatus {
    // Reads the provided descriptor
    let socket = ref.assumingMemoryBound(to: UnsafeMutablePointer<Int32>.self).pointee.pointee
    
    let lengthRequested = length.pointee
    
    // read encrypted data
    var readCount = Darwin.recv(socket, pointer, lengthRequested, 0)
    
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
    return noErr
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
