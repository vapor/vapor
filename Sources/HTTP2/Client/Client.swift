import Async
import Bits
import Foundation
import HTTP
import TCP
import TLS

enum Constants {
    /// The static preface must be sent before initializing an HTTP/2 connection
    static let staticPreface = Data("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n".utf8)
}

/// An HTTP/2 client is similar to an HTTP/1 client, only using another protocol with a slightly different set of features
public final class HTTP2Client: BaseStream {
    /// HTTP/2 only runs over TLS
    let client: TLSClient
    
    /// All streams share the connection and it's context
    let context: ConnectionContext
    
    /// See `BaseStream.errorStream`
    public var errorStream: ErrorHandler?
    
    /// A shorthand that helps keep track of the stream ID
    fileprivate var _nextStreamID: Int32 = 3
    
    var nextStreamID: Int32 {
        defer {
            _nextStreamID = _nextStreamID &+ 2
            
            // When overflowing, stop the connection (connection has existed too long)
            if _nextStreamID <= 0 {
                errorStream?(Error(.tooManyConnectionReuses))
                self.close()
            }
        }
        
        return _nextStreamID
    }
    
    public internal(set) var remoteSettings = HTTP2Settings() {
        didSet {
            self.context.parser.settings = remoteSettings
        }
    }
    
    public internal(set) var settings = HTTP2Settings() {
        didSet {
            self.context.serializer.inputStream(settings.frame)
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
        self.context = ConnectionContext(
            parser: FrameParser(),
            serializer: FrameSerializer()
        )
        self.streamPool = HTTP2StreamPool(
            context: context
        )
        
        client.drain(into: context.parser)
        context.serializer.drain(into: client)
        
        context.parser.drain { frame in
            do {
                if frame.streamIdentifier == 0 {
                    try self.processTopLevelStream(from: frame)
                } else {
                    guard
                        frame.type == .windowUpdate || frame.type == .headers ||
                        frame.type == .pushPromise  || frame.type == .data ||
                        frame.type == .reset
                    else {
                        throw Error(.invalidStreamIdentifier)
                    }
                    
                    self.streamPool[frame.streamIdentifier].inputStream(frame)
                }
            } catch {
                self.context.serializer.inputStream(ResetFrame(code: .protocolError, stream: frame.streamIdentifier).frame)
                self.handleError(error: error)
            }
        }
        
        client.catch(self.handleError)
        context.parser.catch(self.handleError)
        context.serializer.catch(self.handleError)
    }
    
    fileprivate func handleError(error: Swift.Error) {
        self.errorStream?(error)
        self.close()
    }
}
