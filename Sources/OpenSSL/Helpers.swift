import Async
import Bits
import COpenSSL
import Dispatch

enum OpenSSLSide {
    case client
    case server(certificate: String, key: String)
}

enum OpenSSLMethod {
    case ssl23
    case tls1_0
    case tls1_1
    case tls1_2
    
    func method(side: OpenSSLSide) -> UnsafePointer<SSL_METHOD> {
        switch side {
        case .client:
            switch self {
            case .ssl23: return SSLv23_client_method()
            case .tls1_0: return TLSv1_client_method()
            case .tls1_1: return TLSv1_1_client_method()
            case .tls1_2: return TLSv1_2_client_method()
            }
        case .server(_, _):
            switch self {
            case .ssl23: return SSLv23_server_method()
            case .tls1_0: return TLSv1_server_method()
            case .tls1_1: return TLSv1_1_server_method()
            case .tls1_2: return TLSv1_2_server_method()
            }
        }
    }
}

func assert(_ error: Int32) throws {
    guard error > 0 else {
        throw OpenSSLError(.sslError(error))
    }
}

extension OpenSSLStream {
    /// Sets up the read and write handlers
    func initializeDispatchSources() {
        self.writeSource.setEventHandler {
            guard self.connected.future.isCompleted else {
                self.writeSource.suspend()
                self.handshake()
                return
            }
            
            guard self.writeQueue.count > 0 else {
                self.writeSource.suspend()
                return
            }
            
            let data = self.writeQueue[0]
            
            let processed = data.withUnsafeBytes { (pointer: BytesPointer) -> Int in
                return numericCast(SSL_write(self.ssl, pointer, numericCast(data.count)))
            }
            
            if processed == data.count {
                _ = self.writeQueue.removeFirst()
            } else {
                self.writeQueue[0].removeFirst(processed)
            }
            
            guard self.writeQueue.count > 0 else {
                self.writeSource.suspend()
                return
            }
        }
        
        self.readSource.setEventHandler {
            guard self.connected.future.isCompleted else {
                self.handshake()
                return
            }
            
            let read: Int
            
            do {
                read = try self.read(into: self.outputBuffer)
            } catch {
                self.onError(error)
                self.close()
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
            
            self.outputStream.onInput(bufferView)
        }
        
        self.readSource.setCancelHandler {
            self.close()
        }
    }
}
