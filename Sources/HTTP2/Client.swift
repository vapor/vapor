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
    
    let requestSerializer = RequestSerializer()
    let responseParser = ResponseParser()
    
    public var errorStream: ErrorHandler?
    
    var upgraded = false
    
    init(upgrading client: TLSClient) {
        self.client = client
        
        client.drain(into: responseParser)
        
        frameSerializer.drain(into: client)
        requestSerializer.drain { data in
            data.withUnsafeBytes { (pointer: BytesPointer) in
                let buffer = ByteBuffer(start: pointer, count: data.count)
                client.inputStream(buffer)
            }
        }
        
        requestSerializer.catch(self.handleError)
        responseParser.catch(self.handleError)
        client.catch(self.handleError)
        frameParser.catch(self.handleError)
        frameSerializer.catch(self.handleError)
    }
    
    fileprivate func handleError(error: Swift.Error) {
        self.errorStream?(error)
        self.close()
    }
    
    public func close() {
        self.client.close()
    }
    
    public static func connect(hostname: String, port: UInt16 = 443, settings: HTTP2Settings = HTTP2Settings(), worker: Worker) throws -> Future<HTTP2Client> {
        let tlsClient = try TLSClient(worker: worker)
        let client = HTTP2Client(upgrading: tlsClient)
        
        return try tlsClient.connect(hostname: hostname, port: port).flatten {
            let promise = Promise<HTTP2Client>()
            
            client.catch(promise.fail)
            
            client.responseParser.drain { response in
                guard response.status == 101 else {
                    promise.complete(client)
                    return
                }
                
                client.upgraded = true
                tlsClient.drain(into: client.frameParser)
                client.frameSerializer.inputStream(settings.frame)
            }
            
            
            
            return promise.future
        }
    }
}
