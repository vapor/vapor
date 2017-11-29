import Async
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
    public static func connect(hostname: String, port: UInt16 = 443, settings: HTTP2Settings = HTTP2Settings(), worker: Worker) throws -> Future<HTTP2Client> {
        let tlsClient = try TLSClient(on: worker)
        tlsClient.protocols = ["h2", "http/1.1"]
        
        let client = HTTP2Client(upgrading: tlsClient)
        
        // Connect the TLS client
        try tlsClient.connect(hostname: hostname, port: port).do {
            // On successful connection, send the preface
            Constants.staticPreface.withUnsafeBytes { (pointer: BytesPointer) in
                let buffer = ByteBuffer(start: pointer, count: Constants.staticPreface.count)
                
                tlsClient.onInput(buffer)
            }
            
            // Send the settings, next
            client.updateSettings(to: settings)
        }.catch(client.promise.fail)
        
        return client.future
    }
    
    /// Closes the HTTP/2 client by cleaning up
    public func close() {
        for stream in streamPool.streams.values {
            stream.close()
        }
        
        self.client.close()
    }
}
