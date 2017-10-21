import Async
import Bits
import TLS

extension HTTP2Client {
    func openStream() -> HTTP2Stream {
        return self.streamPool[nextStreamID]
    }
    
    public func updateSettings(to settings: HTTP2Settings) {
        self.settings = settings
        self.updatingSettings = true
    }
    
    public static func connect(hostname: String, port: UInt16 = 443, settings: HTTP2Settings = HTTP2Settings(), worker: Worker) throws -> Future<HTTP2Client> {
        let tlsClient = try TLSClient(worker: worker)
        tlsClient.protocols = ["h2", "http/1.1"]
        
        let client = HTTP2Client(upgrading: tlsClient)
        
        try tlsClient.connect(hostname: hostname, port: port).then {
            Constants.staticPreface.withUnsafeBytes { (pointer: BytesPointer) in
                let buffer = ByteBuffer(start: pointer, count: Constants.staticPreface.count)
                
                tlsClient.inputStream(buffer)
            }
            
            client.updateSettings(to: settings)
            }.catch(callback: client.promise.fail)
        
        return client.future
    }
    
    public func close() {
        self.client.close()
    }
}
