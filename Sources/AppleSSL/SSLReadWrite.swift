import Bits
import Security
import Foundation
import Dispatch

//extension AppleTLSSocket {
//
//}

//extension AppleSSLStream {
//    /// A helper that initializes SSL as either the client or server side
//    func initialize() throws {
//        // Sets the read/write functions
//        var status = SSLSetIOFuncs(context, readSSL, writeSSL)
//
//        guard status == 0 else {
//            throw AppleSSLError(.sslError(status))
//        }
//
//        // Adds the file descriptor to this connection
//        status = SSLSetConnection(context, self.descriptor)
//
//        guard status == 0 else {
//            throw AppleSSLError(.sslError(status))
//        }
//    }
//
//    func read(into buffer: MutableByteBuffer) -> Int {
//        var processed = 0
//        SSLRead(context, buffer.baseAddress!, buffer.count, &processed)
//
//        if processed == 0 {
//            self.close()
//        }
//
//        return processed
//    }
//
//    /// Writes to AppleSSL using the provided buffer
//    ///
//    /// If `allowWouldBlock` is true, when a "would block" occurs, the data will be appended to the writeQueue
//    /// Otherwise an error will be thrown
//    @discardableResult
//    func write(from buffer: ByteBuffer, allowWouldBlock: Bool = true) throws -> Int {
//        var processed = 0
//
//        let status = SSLWrite(context, buffer.baseAddress, buffer.count, &processed)
//
//        guard status == 0 else {
//            if status == errSSLWouldBlock {
//                writeQueue.append(Data(buffer))
//
//                // Wasn't already running
//                if writeQueue.count == 1 {
//                    writeSource.resume()
//                }
//
//                return buffer.count
//                // Error
//            } else {
//                throw AppleSSLError(.sslError(status))
//            }
//        }
//
//        return processed
//    }
//}
