import NIOWebSocket

/// Collects WebSocket frame sequences.
///
/// See https://tools.ietf.org/html/rfc6455#section-5 below.
///
/// 5.  Data Framing
/// 5.1.  Overview
///
/// In the WebSocket Protocol, data is transmitted using a sequence of
/// frames.  To avoid confusing network intermediaries (such as
/// intercepting proxies) and for security reasons that are further
/// discussed in Section 10.3, a client MUST mask all frames that it
/// sends to the server (see Section 5.3 for further details).  (Note
/// that masking is done whether or not the WebSocket Protocol is running
/// over TLS.)  The server MUST close the connection upon receiving a
/// frame that is not masked.  In this case, a server MAY send a Close
/// frame with a status code of 1002 (protocol error) as defined in
/// Section 7.4.1.  A server MUST NOT mask any frames that it sends to
/// the client.  A client MUST close a connection if it detects a masked
/// frame.  In this case, it MAY use the status code 1002 (protocol
/// error) as defined in Section 7.4.1.  (These rules might be relaxed in
/// a future specification.)
///
/// The base framing protocol defines a frame type with an opcode, a
/// payload length, and designated locations for "Extension data" and
/// "Application data", which together define the "Payload data".
/// Certain bits and opcodes are reserved for future expansion of the
/// protocol.
///
/// A data frame MAY be transmitted by either the client or the server at
/// any time after opening handshake completion and before that endpoint
/// has sent a Close frame (Section 5.5.1).
struct WebSocketFrameSequence {
    var binaryBuffer: ByteBuffer?
    var textBuffer: String
    var type: WebSocketOpcode
    
    init(type: WebSocketOpcode) {
        self.binaryBuffer = nil
        self.textBuffer = .init()
        self.type = type
    }
    
    mutating func append(_ frame: WebSocketFrame) {
        var data = frame.unmaskedData
        switch type {
        case .binary:
            if var existing = self.binaryBuffer {
                existing.writeBuffer(&data)
                self.binaryBuffer = existing
            } else {
                self.binaryBuffer = data
            }
        case .text: textBuffer.append(data.readString(length: data.readableBytes) ?? "")
        default: break
        }
    }
}
