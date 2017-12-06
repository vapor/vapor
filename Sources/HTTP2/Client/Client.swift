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
public final class HTTP2Client {
    /// HTTP/2 only runs over TLS
    let client: ClosableStream
    
    /// All streams share the connection and it's context
    let context: ConnectionContext
    
    /// A shorthand that helps keep track of the stream ID
    fileprivate var _nextStreamID: Int32 = 3
    
    var nextStreamID: Int32 {
        defer {
            _nextStreamID = _nextStreamID &+ 2
            
            // When overflowing, stop the connection (connection has existed too long)
            if _nextStreamID <= 0 {
                onError(HTTP2Error(.tooManyConnectionReuses))
                self.close()
            }
        }
        
        return _nextStreamID
    }
    
    /// Reads the remote's (server) settings
    public internal(set) var remoteSettings = HTTP2Settings() {
        didSet {
            self.context.parser.settings = remoteSettings
            self.context.serializer.maxLength = remoteSettings.maxFrameSize
        }
    }
    
    /// Reads the local (client) settings
    public internal(set) var settings = HTTP2Settings() {
        didSet {
            self.context.serializer.onInput(settings.frame)
            self.context.parser.maxFrameSize = settings.maxFrameSize
        }
    }
    
    /// If true, the settings are currently being updated
    ///
    /// TODO: Pause further stream execution?
    var updatingSettings = false
    
    /// Manages multiple streams within this connection
    let streamPool: HTTP2StreamPool
    
    ///
    let promise = Promise<HTTP2Client>()
    
    var future: Future<HTTP2Client> {
        return promise.future
    }
    
    /// Upgrades an existing TLSClient to use HTTP/2
    init<Client: ALPNSupporting>(client: Client) {
        self.client = client
        self.context = ConnectionContext(
            parser: FrameParser(maxFrameSize: settings.maxFrameSize),
            serializer: FrameSerializer(maxLength: remoteSettings.maxFrameSize)
        )
        
        self.streamPool = HTTP2StreamPool(
            context: context
        )
        
        client.stream(to: context.parser)
        context.serializer.stream(to: client)
        
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
                        throw HTTP2Error(.invalidStreamIdentifier)
                    }
                    
                    self.streamPool[frame.streamIdentifier].onInput(frame)
                }
            } catch {
                self.context.serializer.onInput(ResetFrame(code: .protocolError, stream: frame.streamIdentifier).frame)
                self.onError(error)
            }
        }.catch(onError: self.onError)
    }
    
    func onError(_ error: Error) {
        self.close()
    }
}
