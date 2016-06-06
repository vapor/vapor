extension WebSock {
    public func send(_ msg: Frame) throws {
        // TODO: Throw if control frame greater than 125 byte PAYLOAD.
        try stream.send(msg)
    }

    // TODO: Not Masking etc. assumes Server to Client, consider strategy to support both
    public func send(_ text: String) throws {
        let payload = Data(text)
        let header = Frame.Header(
            fin: true,
            rsv1: false,
            rsv2: false,
            rsv3: false,
            opCode: .text,
            isMasked: false,
            payloadLength: UInt64(payload.count),
            maskingKey: .none
        )

        let msg = Frame(header: header, payload: payload)
        try send(msg)
    }

    public func send(_ binary: Data) throws {
        let payload = binary
        let header = Frame.Header(
            fin: true,
            rsv1: false,
            rsv2: false,
            rsv3: false,
            opCode: .binary,
            isMasked: false,
            payloadLength: UInt64(payload.count),
            maskingKey: .none
        )
        let msg = Frame(header: header, payload: payload)
        try send(msg)
    }
}

// MARK:

extension WebSock {
    public func ping(statusCode: UInt16? = nil, reason: String? = nil) throws {
        // Reason can _only_ exist if statusCode also exists
        // statusCode may exist _without_ a reason
        if statusCode != nil {

        }
        let payload: Data = []


        let header = Frame.Header(
            fin: true,
            rsv1: false,
            rsv2: false,
            rsv3: false,
            opCode: .ping,
            isMasked: false,
            payloadLength: UInt64(payload.count),
            maskingKey: .none
        )
        let msg = Frame(header: header, payload: payload)
        try stream.send(msg)
    }

    /**
     If we receive a .ping, we must .pong identical data

     Applications may opt to send unsolicited .pong messages as a sort of keep awake heart beat
     */
    public func pong(_ payload: Data) throws {
        let header = Frame.Header(
            fin: true,
            rsv1: false,
            rsv2: false,
            rsv3: false,
            opCode: .pong,
            isMasked: false,
            payloadLength: UInt64(payload.count),
            maskingKey: .none
        )
        let msg = Frame(header: header, payload: payload)
        try stream.send(msg)
    }
}

extension Stream {
    public func send(_ message: WebSock.Frame) throws {
        let serializer = MessageSerializer(message)
        let data = serializer.serialize()
        try send(Data(data))
    }
}

//extension WebSock.Test {}
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
    func serialize() -> [Byte] {
        switch self {
        case .none:
            return []
        case let .key(zero: zero, one: one, two: two, three: three):
            return [zero, one, two, three]
        }
    }
}

extension WebSock.Frame {
    public static func respondToClient(_ msg: String) -> WebSock.Frame {
        let payload = Data(msg)
        let header = WebSock.Frame.Header(
            fin: true,
            rsv1: false,
            rsv2: false,
            rsv3: false,
            opCode: .text,
            isMasked: false,
            payloadLength: UInt64(payload.count),
            maskingKey: .none
        )

        return WebSock.Frame(header: header, payload: payload)
    }
}

extension UnsignedInteger {
    func bytes() -> [Byte] {
        let byteMask: Self = 0b1111_1111
        let size = sizeof(Self)
        var copy = self
        var bytes: [Byte] = []
        (1...size).forEach { _ in
            let next = copy & byteMask
            let byte = Byte(next.toUIntMax())
            bytes.insert(byte, at: 0)
            copy.shiftRight(8)
        }
        return bytes
    }

    mutating func shiftRight(_ places: Int) {
        (1...places).forEach { _ in
            self /= 2
        }
    }
}

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

/*
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
extension Byte {
    static let finFlag: Byte = 0b1000_0000
    static let rsv1Flag: Byte = 0b0100_0000
    static let rsv2Flag: Byte = 0b0010_0000
    static let rsv3Flag: Byte = 0b0001_0000

    static let opCodeFlag: Byte = 0b0000_1111

    static let maskKeyIncludedFlag: Byte = 0b1000_0000
    static let payloadLengthFlag: Byte = 0b0111_1111

    /*
     Initial payload length comes as last 7 bits of byte at index 1

     If payload length is >= 126, additional bytes are allocated to express the length

     Value: 126
     UInt16 payload length, next two bytes

     Value: 127
     UInt64 payload length, next eight bytes
     */
    static let twoBytePayloadLength: Byte = 0b0111_1110
    static let eightBytePayloadLength: Byte = 0b0111_1111
}

internal enum PayloadLengthExtension: UInt8 {
    // If value is 126...UInt16.max -- next two bytes
    case two = 2

    // If value is UInt16.max...UInt64.max -- next eight bytes
    case eight = 8

    init?(_ byte: Byte) {
        // Payload extends if first length is 126 or 127. (max and max-1 @ 7 bits)
        switch byte {
        case 126:
            self = .two
        case 127:
            self = .eight
        default:
            return nil
        }
    }
}

extension String: ErrorProtocol {}

//func metadata(_ file: String = #file, _ function: String = #function, _ line: String = #line) -> String {
//    var str = "[Metadata]\n"
//    str += "\tFile: \(file.components(separatedBy: "/").last ?? "")\n"
//    str += "\tFunction: \(function)\n"
//    str += "\tLine: \(line)\n\n"
//    return str
//}

/*
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
// TODO: NOT UNIT TESTED
public final class MessageSerializer {
    private let message: WebSock.Frame

    private init(_ message: WebSock.Frame) {
        self.message = message
    }

    private func serialize() -> [Byte] {
        let header = serializeHeader()
        let payload = serializePayload()
        return header + payload
    }

    // MARK: Header

    private func serializeHeader() -> [Byte] {
        let zero = serializeByteZero()
        let maskAndLength = serializeMaskAndLength()
        let maskingKey = serializeMaskingKey()
        return zero + maskAndLength + maskingKey
    }

    func serializeByteZero() -> [Byte] {
        let header = message.header

        /*
         0 1 2 3 4 5 6 7
         f r r r o
         i s s s p
         n v v v
         1 2 3 c
         o
         d
         e
         */
        var byte: Byte = 0
        if header.fin {
            byte |= .finFlag
        }
        if header.rsv1 {
            byte |= .rsv1Flag
        }
        if header.rsv2 {
            byte |= .rsv2Flag
        }
        if header.rsv3 {
            byte |= .rsv3Flag
        }

        let op = header.opCode.serialize() & .opCodeFlag
        byte |= op

        return [byte]
    }

    func serializeMaskAndLength() -> [Byte] {
        let header = message.header

        // first length byte is bit 0: mask, bit 1...7: length or indicator of additional bytes
        var primaryByte: Byte = 0
        if header.isMasked {
            primaryByte |= Byte.maskKeyIncludedFlag
        }

        // 126 / 127 (max, max-1) indicate 2 & 8 byte extensions respectively
        if header.payloadLength < 126 {
            primaryByte |= UInt8(header.payloadLength)
            return [primaryByte] // lengths < 126 don't need additional bytes
        } else if header.payloadLength < UInt16.max.toUIntMax() {
            primaryByte |= 126 // 126 flags that 2 bytes are required
            let lengthBytes = UInt16(header.payloadLength).bytes()
            return [primaryByte] + lengthBytes
        } else {
            primaryByte |= 127 // 127 flags that 8 bytes are requred
            return [primaryByte] + header.payloadLength.bytes() // UInt64 == 8 bytes natively
        }
    }

    private func serializeMaskingKey() -> [Byte] {
        return message.header.maskingKey.serialize()
    }

    // MARK: Payload

    private func serializePayload() -> [Byte] {
        return message.header.maskingKey.cypher(message.payload)
    }
}

extension MessageSerializer {
    public static func serialize(_ message: WebSock.Frame) -> [Byte] {
        let serializer = MessageSerializer(message)
        return serializer.serialize()
    }
}

public protocol OutputStream {
    associatedtype Element
    mutating func next() throws -> Element?
}

extension IndexingIterator: OutputStream {}
extension AnyIterator: OutputStream {}
extension StreamBuffer: OutputStream {}
extension Array: OutputStream {
    public mutating func next() -> Element? {
        guard !isEmpty else { return nil }
        return removeFirst()
    }
}

extension MaskingKey {
    /*
     Octet i of the transformed data ("transformed-octet-i") is the XOR of
     octet i of the original data ("original-octet-i") with octet at index
     i modulo 4 of the masking key ("masking-key-octet-j"):

     j                   = i MOD 4
     transformed-octet-i = original-octet-i XOR masking-key-octet-j
     
     
     Cypher is same for masking and unmasking
     */
    func cypher<S: Sequence where S.Iterator.Element == Byte>(_ input: S) -> [Byte] {
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

//public final class _MessageParser<O: OutputStream where O.Element == Byte> {
//    private var buffer: O
//
//    private init(_ inputStream: O) {
//        self.buffer = inputStream
//    }
//
//    // MARK: Extractors
//
//    private func extractByteZero() throws -> (fin: Bool, rsv1: Bool, rsv2: Bool, rsv3: Bool, opCode: OpCode) {
//        guard let byteZero = try buffer.next() else {
//            throw "479: WebSockets.Swift: MessageParser"
//        }
//        let fin = byteZero.containsMask(.fin)
//        let rsv1 = byteZero.containsMask(.rsv1)
//        let rsv2 = byteZero.containsMask(.rsv2)
//        let rsv3 = byteZero.containsMask(.rsv3)
//
//        let opCode = try OpCode(byteZero & .opCode)
//        return (fin, rsv1, rsv2, rsv3, opCode)
//    }
//
//    private func extractByteOne() throws -> (maskKeyIncluded: Bool, payloadLength: Byte) {
//        guard let byteOne = try buffer.next() else {
//            throw "493: WebSockets.Swift: MessageParser"
//        }
//        let maskKeyIncluded = byteOne.containsMask(.maskKeyIncluded)
//        let payloadLength = byteOne & .payloadLength
//        return (maskKeyIncluded, payloadLength)
//    }
//
//    /**
//     Returns UInt64 to encompass highest possible length. Length may be UInt16
//     */
//    private func extractExtendedPayloadLength(_ length: ExtendedPayloadByteLength) throws -> UInt64 {
//        var bytes: [Byte] = []
//        for _ in 1...length.rawValue {
//            guard let next = try buffer.next() else {
//                throw "522: WebSockets.Swift: MessageParser"
//            }
//            bytes.append(next)
//        }
//        return try UInt64.init(bytes)
//    }
//
//    private func extractMaskingKey() throws -> MaskingKey {
//        guard
//            let zero = try buffer.next(),
//            let one = try buffer.next(),
//            let two = try buffer.next(),
//            let three = try buffer.next()
//            else {
//                throw "536: WebSockets.Swift: MessageParser"
//        }
//
//        return .key(zero: zero, one: one, two: two, three: three)
//    }
//
//    private func extractPayload(key: MaskingKey, length: UInt64) throws -> [Byte] {
//        var count: UInt64 = 0
//        var bytes: [UInt8] = []
//
//        while count < length, let next = try buffer.next() {
//            bytes.append(next)
//            count += 1
//        }
//        
//        return key.cypher(bytes)
//    }
//}
//
//extension _MessageParser where O: StreamBuffer {
//    public static func parse(stream: Stream) throws -> WebSocketMessage {
//        let buffer = O.init(stream)
//        return try parse(data: buffer)
//    }
//}
//
//extension _MessageParser {
//    public static func parse(data: O) throws -> WebSocketMessage {
//        let parser = _MessageParser(data)
//        let (fin, rsv1, rsv2, rsv3, opCode) = try parser.extractByteZero()
//        let (isMasked, payloadLengthInfo) = try parser.extractByteOne()
//
//        let payloadLength: UInt64
//        if let extended = ExtendedPayloadByteLength(payloadLengthInfo) {
//            payloadLength = try parser.extractExtendedPayloadLength(extended)
//        } else {
//            payloadLength = payloadLengthInfo.toUIntMax()
//        }
//
//        let maskingKey: MaskingKey
//        if isMasked {
//            maskingKey = try parser.extractMaskingKey()
//        } else {
//            maskingKey = .none
//        }
//
//        let payload = try parser.extractPayload(key: maskingKey, length: payloadLength)
//        guard payload.count == Int(payloadLength) else {
//            throw "598: WebSockets.Swift: MessageParser"
//        }
//
//        let header = WebSocketHeader(
//            fin: fin,
//            rsv1: rsv1,
//            rsv2: rsv2,
//            rsv3: rsv3,
//            isMasked: isMasked,
//            opCode: opCode,
//            maskingKey: maskingKey,
//            payloadLength: payloadLength
//        )
//        return WebSocketMessage(header: header, payload: Data(payload))
//    }
//}

extension UnsignedInteger {
    /*
     [0b1111_1011, 0b0000_1111]
     =>
     0b1111_1011_0000_1111
     */
    init(_ bytes: [Byte]) throws {
        // 8 bytes in UInt64
        guard bytes.count <= sizeof(Self) else {
            throw "626: WebSockets.Swift: UnsignedInteger"
        }
        var value: UIntMax = 0
        bytes.forEach { byte in
            value <<= 8 // 1 byte is 8 bits
            value |= byte.toUIntMax()
        }

        self.init(value)
    }
}

extension UnsignedInteger {
    // UNTESTED:
    public func containsMask(_ mask: Self) -> Bool {
        return (self & mask) == mask
    }
}