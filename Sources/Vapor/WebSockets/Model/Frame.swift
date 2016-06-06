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

extension WebSock.Frame {
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

        /*
         Octet i of the transformed data ("transformed-octet-i") is the XOR of
         octet i of the original data ("original-octet-i") with octet at index
         i modulo 4 of the masking key ("masking-key-octet-j"):

         j                   = i MOD 4
         transformed-octet-i = original-octet-i XOR masking-key-octet-j


         Cypher is same for masking and unmasking
         */
        func hash<S: Sequence where S.Iterator.Element == Byte>(_ input: S) -> [Byte] {
            switch self {
            case .none:
                return Array(input)
            case let .key(zero: zero, one: one, two: two, three: three):
                var count = UInt64(0)
                let keys = [zero, one, two, three]
                // don't use enumerated(). it returns `Int` which may lose precision
                return input.map { original in
                    let key = keys[Int(count % 4)]
                    count += 1
                    return original ^ key
                }
            }
        }
    }
}

extension WebSock.Frame {
    public enum Error: ErrorProtocol {
        case failed
    }
}

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
