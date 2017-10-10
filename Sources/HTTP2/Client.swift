import Async
import Bits
import Foundation
import HTTP
import TCP
import TLS

enum Constants {
    fileprivate static let staticPreface = Data("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".utf8)
}

public struct HTTP2Settings {
    public init() {}
    
    public var awaitHandshake = true
    
    
    var data: Data {
        return Data()
    }
}

public final class HTTP2Client: Async.Stream, ClosableStream {
    enum Stage {
        case preface
    }
    
    public typealias Input = Frame
    public typealias Output = Frame
    
    let client: TLSClient
    var stage = Stage.preface
    
    let parser = FrameParser()
    let serializer = FrameSerializer()
    
    public var outputStream: OutputHandler? {
        get {
            return parser.outputStream
        }
        set {
            parser.outputStream = newValue
        }
    }
    
    public var errorStream: ErrorHandler?
    public var onClose: CloseHandler?
    
    init(upgrading client: TLSClient) {
        self.client = client
        
        client.drain(into: parser)
        serializer.drain(into: client)
        
        parser.catch(self.handleError)
        client.catch(self.handleError)
        serializer.catch(self.handleError)
    }
    
    public func inputStream(_ input: Frame) {
        serializer.inputStream(input)
    }
    
    fileprivate func handleError(error: Swift.Error) {
        self.errorStream?(error)
    }
    
    public func close() {
        self.client.close()
    }
    
//    public static func upgrading(_ httpClient: HTTPClient) -> Future<HTTP2Client> {
//        httpClient.
//    }
//
//    public static func upgrading(_ httpsClient: HTTPSClient) -> Future<HTTP2Client> {
//        httpsClient.
//    }
    
    public static func connect(hostname: String, port: UInt16 = 443, settings: HTTP2Settings = HTTP2Settings(), worker: Worker) throws -> Future<HTTP2Client> {
        let tlsClient = try TLSClient(worker: worker)
        
        return try tlsClient.connect(hostname: hostname, port: port).flatten {
            let promise = Promise<HTTP2Client>()
            
            let client = HTTP2Client(upgrading: tlsClient)
            
            tlsClient.catch { error in
                promise.fail(error)
            }
            
            client.drain { response in
                guard client.stage == .preface else {
                    promise.fail(Error(.invalidUpgrade))
                    return
                }
                
                
                
                promise.complete(client)
            }
            
            let handshake = Constants.staticPreface + settings.data
            
            handshake.withUnsafeBytes { (pointer: BytesPointer) in
                let prefaceBuffer = ByteBuffer(start: pointer, count: handshake.count)
                
                tlsClient.inputStream(prefaceBuffer)
            }
            
            if !settings.awaitHandshake {
                promise.complete(client)
            }
            
            return promise.future
        }
    }
}
