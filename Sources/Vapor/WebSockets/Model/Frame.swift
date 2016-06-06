// MARK:

extension WebSock {
    /* https://tools.ietf.org/html/rfc6455#section-5.2
     0               1               2               3
     0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
     +-+-+-+-+-------+-+-------------+-------------------------------+
     |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
     |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
     |N|V|V|V|       |S|             |   (if payload len==126/127)   |
     | |1|2|3|       |K|             |                               |
     +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
     |     Extended payload length continued, if payload len == 127  |
     + - - - - - - - - - - - - - - - +-------------------------------+
     |                               |Masking-key, if MASK set to 1  |
     +-------------------------------+-------------------------------+
     | Masking-key (continued)       |          Payload Data         |
     +-------------------------------- - - - - - - - - - - - - - - - +
     :                     Payload Data continued ...                :
     + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
     |                     Payload Data continued ...                |
     +---------------------------------------------------------------+
     */
    public final class Frame {
        public let header: Header
        public let payload: Data

        // TODO: Should we cypher here?
        public init(header: Header, payload: Data) {
            self.header = header
            self.payload = payload
        }
    }
}

extension WebSock.Frame {
    /* https://tools.ietf.org/html/rfc6455#section-5.2
     0               1               2               3
     0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
     +-+-+-+-+-------+-+-------------+-------------------------------+
     |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
     |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
     |N|V|V|V|       |S|             |   (if payload len==126/127)   |
     | |1|2|3|       |K|             |                               |
     +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
     |     Extended payload length continued, if payload len == 127  |
     + - - - - - - - - - - - - - - - +-------------------------------+
     |                               |Masking-key, if MASK set to 1  |
     +-------------------------------+-------------------------------+
     | Masking-key (continued)       |          Payload Data         |
     +-------------------------------- - - - - - - - - - - - - - - - +
     :                     Payload Data continued ...                :
     + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
     |                     Payload Data continued ...                |
     +---------------------------------------------------------------+
     */
    public struct Header {
        public let fin: Bool

        /**
         Definable flags.

         If any flag is 'true' that is not explicitly defined, the socket MUST close: RFC
         */
        public let rsv1: Bool
        public let rsv2: Bool
        public let rsv3: Bool

        public let opCode: OpCode

        public let isMasked: Bool
        public let payloadLength: UInt64

        public let maskingKey: MaskingKey
    }
}

extension WebSock.Frame {
    /*
     Defines the interpretation of the "Payload data".  If an unknown
     opcode is received, the receiving endpoint MUST _Fail the
     WebSocket Connection_.  The following values are defined.

     *  %x0 denotes a continuation frame

     *  %x1 denotes a text frame

     *  %x2 denotes a binary frame

     *  %x3-7 are reserved for further non-control frames

     *  %x8 denotes a connection close

     *  %x9 denotes a ping

     *  %xA denotes a pong

     *  %xB-F are reserved for further control frames
     */
    public enum OpCode {
        /*
         // MARK: NON CONTROL FRAMES

         May be fragmented
         */
        case continuation
        case text
        case binary
        case nonControlExtension(NonControlFrameExtension)

        /*
         // MARK: CONTROL FRAMES

         All control frames MUST have a payload length of 125 bytes or less
         and MUST NOT be fragmented.

         // TODO: Implement these checks
         */
        case connectionClose
        case ping
        case pong
        case controlExtension(ControlFrameExtension)

        // 4 bytes
        init(_ i: Byte) throws {
            switch i {
            case 0x00:
                self = .continuation
            case 0x01:
                self = .text
            case 0x02:
                self = .binary
            case 0x03...0x07: // reserved non-control frame
                let ncf = try NonControlFrameExtension(i)
                self = .nonControlExtension(ncf)
            case 0x08:
                self = .connectionClose
            case 0x09:
                self = .ping
            case 0xA:
                self = .pong
            case 0xb...0xf: // reserved control frame
                let cf = try ControlFrameExtension(i)
                self = .controlExtension(cf)
            default:
                throw Error.invalid
            }
        }
    }
}

extension WebSock.Frame.OpCode {
    public enum Error: ErrorProtocol { case invalid }
}

extension WebSock.Frame.OpCode {
    public enum NonControlFrameExtension: UInt8 {
        case three = 3, four, five, six, seven
        init<I: UnsignedInteger>(_ i: I) throws {
            switch i {
            case 3:
                self = .three
            case 4:
                self = .four
            case 5:
                self = .five
            case 6:
                self = .six
            case 7:
                self = .seven
            default:
                throw Error.invalid
            }
        }
    }
    public enum ControlFrameExtension: UInt8 {
        case b = 0x0B, c, d, e, f
        init<I: UnsignedInteger>(_ i: I) throws {
            switch i {
            case 0xB:
                self = .b
            case 0xC:
                self = .c
            case 0xD:
                self = .d
            case 0xE:
                self = .e
            default:
                throw Error.invalid
            }
        }
    }
}

/*

 // MARK: - A Note on Extensions

 Reserved bits:


 The protocol is designed to allow for extensions, which will add
 capabilities to the base protocol.  The endpoints of a connection
 MUST negotiate the use of any extensions during the opening
 handshake.  This specification provides opcodes 0x3 through 0x7 and
 0xB through 0xF, the "Extension data" field, and the frame-rsv1,
 frame-rsv2, and frame-rsv3 bits of the frame header for use by
 extensions.  The negotiation of extensions is discussed in further
 detail in Section 9.1.  Below are some anticipated uses of
 extensions.  This list is neither complete nor prescriptive.

 o  "Extension data" may be placed in the "Payload data" before the
 "Application data".

 o  Reserved bits can be allocated for per-frame needs.

 o  Reserved opcode values can be defined.

 o  Reserved bits can be allocated to the opcode field if more opcode
 values are needed.

 o  A reserved bit or an "extension" opcode can be defined that
 allocates additional bits out of the "Payload data" to define
 larger opcodes or more per-frame bits.


 */
extension WebSock.Frame.OpCode {
    // 4 bits
    // TODO: Is it worth building UInt4?
    //
    func serialize() -> Byte {
        switch self {
        case .continuation:
            return 0x00
        case .text:
            return 0x01
        case .binary:
            return 0x02
        case let .nonControlExtension(nce): // 3...7
            return nce.rawValue
        case .connectionClose:
            return 0x08
        case .ping:
            return 0x09
        case .pong:
            return 0x0A
        case let .controlExtension(ce):
            return ce.rawValue
        }
    }
}

extension WebSock.Frame.OpCode: Equatable {}

public func == (lhs: WebSock.Frame.OpCode, rhs: WebSock.Frame.OpCode) -> Bool {
    switch (lhs, rhs) {
    case (.continuation, .continuation): return true
    case (.text, .text): return true
    case (.binary, .binary): return true
    case let (.nonControlExtension(l), .nonControlExtension(r)): return l == r
    case (.connectionClose, .connectionClose): return true
    case (.ping, .ping): return true
    case (.pong, .pong): return true
    case let (.controlExtension(l), .controlExtension(r)): return l == r
    default: return false
    }
}

extension WebSock.Frame.OpCode {
    /*
     Control frames are identified by opcodes where the most significant
     bit of the opcode is 1.

     4 bytes (4...7)

     9...15

     */
    public var isControlFrame: Bool {
        switch self {
        case .ping, .pong, .controlExtension(_):
            return true
        default:
            return false
        }
    }
}

extension WebSock.Frame.Header {
    /*
     Control frame CAN NOT be fragmented, but can be injected in between a fragmented message
     */
    public var isControlFrame: Bool {
        return opCode.isControlFrame
    }
}

// TODO: Rename => Frame? matches RFC better
// Frame usually refers to Header, maybe Header == Frame
extension WebSock.Frame {
    public var isControlFrame: Bool {
        return header.isControlFrame
    }
}

/*
 Client to Server MUST be masked

 Only set if mask bit is '1'

 The masking key is a 32-bit value chosen at random by the client.
 When preparing a masked frame, the client MUST pick a fresh masking
 key from the set of allowed 32-bit values.  The masking key needs to
 be unpredictable; thus, the masking key MUST be derived from a strong
 source of entropy, and the masking key for a given frame MUST NOT
 make it simple for a server/proxy to predict the masking key for a
 subsequent frame.  The unpredictability of the masking key is
 essential to prevent authors of malicious applications from selecting
 the bytes that appear on the wire.  RFC 4086 [RFC4086] discusses what
 entails a suitable source of entropy for security-sensitive
 applications.

 Cyphered one byte at a time MOD 4
 */
public enum MaskingKey {
    case none
    case key(zero: UInt8, one: UInt8, two: UInt8, three: UInt8)
}

extension MaskingKey {
    // TODO: Don't serialize here? and put it all to serializer?
    func serialize() -> [Byte] {
        switch self {
        case .none:
            return []
        case let .key(zero: zero, one: one, two: two, three: three):
            return [zero, one, two, three]
        }
    }
}

// TODO: => +UnsignedInteger.swift

extension WebSock.Frame {
    public enum Error: ErrorProtocol {
        case failed
    }
}


/*

 // MARK: Fragmentation

 The following rules apply to fragmentation:

 o  An unfragmented message consists of a single frame with the FIN
 bit set (Section 5.2) and an opcode other than 0.

 o  A fragmented message consists of a single frame with the FIN bit
 clear and an opcode other than 0, followed by zero or more frames
 with the FIN bit clear and the opcode set to 0, and terminated by
 a single frame with the FIN bit set and an opcode of 0.  A
 fragmented message is conceptually equivalent to a single larger
 message whose payload is equal to the concatenation of the
 payloads of the fragments in order; however, in the presence of
 extensions, this may not hold true as the extension defines the
 interpretation of the "Extension data" present.  For instance,
 "Extension data" may only be present at the beginning of the first
 fragment and apply to subsequent fragments, or there may be
 "Extension data" present in each of the fragments that applies
 only to that particular fragment.  In the absence of "Extension
 data", the following example demonstrates how fragmentation works.

 EXAMPLE: For a text message sent as three fragments, the first
 fragment would have an opcode of 0x1 and a FIN bit clear, the
 second fragment would have an opcode of 0x0 and a FIN bit clear,
 and the third fragment would have an opcode of 0x0 and a FIN bit
 that is set.

 o  Control frames (see Section 5.5) MAY be injected in the middle of
 a fragmented message.  Control frames themselves MUST NOT be
 fragmented.

 o  Message fragments MUST be delivered to the recipient in the order
 sent by the sender.

 o  The fragments of one message MUST NOT be interleaved between the
 fragments of another message unless an extension has been
 negotiated that can interpret the interleaving.

 o  An endpoint MUST be capable of handling control frames in the
 middle of a fragmented message.

 o  A sender MAY create fragments of any size for non-control
 messages.

 o  Clients and servers MUST support receiving both fragmented and
 unfragmented messages.

 o  As control frames cannot be fragmented, an intermediary MUST NOT
 attempt to change the fragmentation of a control frame.

 o  An intermediary MUST NOT change the fragmentation of a message if
 any reserved bit values are used and the meaning of these values
 is not known to the intermediary.

 o  An intermediary MUST NOT change the fragmentation of any message
 in the context of a connection where extensions have been
 negotiated and the intermediary is not aware of the semantics of
 the negotiated extensions.  Similarly, an intermediary that didn't
 see the WebSocket handshake (and wasn't notified about its
 content) that resulted in a WebSocket connection MUST NOT change
 the fragmentation of any message of such connection.

 o  As a consequence of these rules, all fragments of a message are of
 the same type, as set by the first fragment's opcode.  Since
 control frames cannot be fragmented, the type for all fragments in
 a message MUST be either text, binary, or one of the reserved
 opcodes.
 */

extension WebSock.Frame {
    public var isFragment: Bool {
        /*
         An unfragmented message consists of a single frame with the FIN
         bit set (Section 5.2) and an opcode other than 0.
         */
        if !header.fin || header.opCode == .continuation {
            return true
        } else {
            return false
        }
    }

    /*
     A fragmented message consists of a single frame with the FIN bit
     clear and an opcode other than 0, followed by zero or more frames
     with the FIN bit clear and the opcode set to 0, and terminated by
     a single frame with the FIN bit set and an opcode of 0.
     */
    // TODO: Rename Leading -- first ... header is used elsewhere to mean other things
    public var isFragmentHeader: Bool {
        return !header.fin && header.opCode != .continuation
    }

    public var isFragmentBody: Bool {
        return !header.fin && header.opCode == .continuation
    }

    // TODO: Rename to match rename of header, possibly trailing or last
    public var isFragmentFooter: Bool {
        return header.fin && header.opCode == .continuation
    }
}
