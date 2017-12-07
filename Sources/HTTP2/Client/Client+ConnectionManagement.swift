import Async
import Service
import Bits
import TLS

extension HTTP2Client {
    /// Opens a new HTTP/2 stream
    func openStream() -> HTTP2Stream {
        return self.streamPool[nextStreamID]
    }
    
    /// Updates the client's settings
    func updateSettings(to settings: HTTP2Settings) {
        self.settings = settings
        self.updatingSettings = true
    }
    
    /// Connects to an HTTP/2 server using the knowledge that it's HTTP/2
    ///
    /// Requires an SSL driver with ALPN on your system
    public static func connect(
        to hostname: String,
        port: UInt16? = nil,
        settings: HTTP2Settings = HTTP2Settings(),
        on container: Container
    ) -> Future<HTTP2Client> {
        do {
            let tlsClient = try container.make(BasicSSLClient.self, for: HTTP2Client.self)
            
            guard let alpnSupporting = tlsClient.alpnSupporting else {
                // TODO: Fallback to HTTP/1.1
                return Future(error: HTTP2Error(.alpnNotSupported))
            }
            
            alpnSupporting.ALPNprotocols = ["h2", "http/1.1"]
            
            let client = HTTP2Client(client: tlsClient)
            
            // Connect the TLS client
            return try tlsClient.connect(hostname: hostname, port: port ?? 443).map {
                // On successful connection, send the preface
                Constants.staticPreface.withByteBuffer(tlsClient.onInput)
                
                // Send the settings, next
                client.updateSettings(to: settings)
                
                return client
            }
        } catch {
            return Future(error: error)
        }
    }
    
    /// Closes the HTTP/2 client by cleaning up
    public func close() {
        for stream in streamPool.streams.values {
            stream.close()
        }
        
        self.client.close()
    }
}
