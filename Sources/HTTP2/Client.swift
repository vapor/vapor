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
    
    fileprivate var _nextStreamID: Int32 = 1
    
    var nextStreamID: Int32 {
        defer {
            _nextStreamID = _nextStreamID &+ 2
            
            // When overflowing, reset to 1
            if _nextStreamID <= 0 {
                _nextStreamID = 1
            }
        }
        
        return _nextStreamID
    }
    
    var upgraded = false
    
    public internal(set) var remoteSettings = HTTP2Settings() {
        didSet {
            self.frameParser.settings = remoteSettings
        }
    }
    
    public internal(set) var settings = HTTP2Settings() {
        didSet {
            self.frameSerializer.inputStream(settings.frame)
        }
    }
    
    public var updatingSettings = false
    let streamPool: HTTP2StreamPool
    
    let promise = Promise<HTTP2Client>()
    
    var future: Future<HTTP2Client> {
        return promise.future
    }
    
    init(upgrading client: TLSClient) {
        self.client = client
        self.streamPool = HTTP2StreamPool(
            serializer: self.frameSerializer,
            parser: self.frameParser
        )
        
        client.drain(into: frameParser)
        frameSerializer.drain(into: client)
        
        frameParser.drain { frame in
            do {
                if frame.streamIdentifier == 0 {
                    try self.processTopLevelStream(from: frame)
                } else {
                    guard
                        frame.type == .windowUpdate || frame.type == .headers ||
                        frame.type == .pushPromise  || frame.type == .data
                    else {
                        throw Error(.invalidStreamIdentifier)
                    }
                    
                    self.streamPool[frame.streamIdentifier].inputStream(frame)
                }
            } catch {
                self.frameSerializer.inputStream(ResetFrame(code: .protocolError, stream: frame.streamIdentifier).frame)
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
}
