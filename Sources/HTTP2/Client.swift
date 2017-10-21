import Async
import Bits
import Foundation
import HTTP
import TCP
import TLS

enum Constants {
    static let staticPreface = Data("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".utf8)
}

public final class HTTP2Client: BaseStream {
    let client: TLSClient
    
    let frameParser = FrameParser()
    let frameSerializer = FrameSerializer()
    
    public var errorStream: ErrorHandler?
    
    var upgraded = false
    public private(set) var remoteSettings = HTTP2Settings() {
        didSet {
            self.frameParser.settings = remoteSettings
        }
    }
    
    public private(set) var settings = HTTP2Settings() {
        didSet {
            self.frameSerializer.inputStream(settings.frame)
        }
    }
    
    public var updatingSettings = false
    
    fileprivate let promise = Promise<HTTP2Client>()
    
    fileprivate var future: Future<HTTP2Client> {
        return promise.future
    }
    
    init(upgrading client: TLSClient) {
        self.client = client
        
        client.drain(into: frameParser)
        frameSerializer.drain(into: client)
        
        frameParser.drain { frame in
            do {
                switch frame.type {
                case .settings:
                    if frame.flags & 0x01 == 0x01 {
                        // Acknowledgement
                        self.updatingSettings = false
                    } else {
                        try self.remoteSettings.update(to: frame)
                        self.frameSerializer.inputStream(HTTP2Settings.acknowledgeFrame)
                        
                        if !self.future.isCompleted {
                            self.promise.complete(self)
                        }
                    }
                default:
                    print(frame)
                    print(frame.payload.data.count)
                }
            } catch {
                self.handleError(error: error)
            }
        }
        
        client.catch(self.handleError)
        frameParser.catch(self.handleError)
        frameSerializer.catch(self.handleError)
    }
    
    fileprivate func handleError(error: Swift.Error) {
        self.errorStream?(error)
        self.close()
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
