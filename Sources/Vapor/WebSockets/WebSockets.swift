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

// TODO: Bit or Bool?
public enum Bit {
    case one, zero
}

extension Bit: Boolean {
    public var boolValue: Bool { return self == .one }
}

extension Bit: BooleanLiteralConvertible {
    public init(booleanLiteral value: Bool) {
        self = value ? .one : .zero
    }
}

public struct Reserved {
    /*
     MUST be 0 unless an extension is negotiated that defines meanings
     for non-zero values.  If a nonzero value is received and none of
     the negotiated extensions defines the meaning of such a nonzero
     value, the receiving endpoint MUST _Fail the WebSocket
     Connection_.
     */
    public let one: Bool
    public let two: Bool
    public let three: Bool
}

extension OpCode {
    public enum Error: ErrorProtocol { case invalid, reserved }
}

public enum OpCode {
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
    case continuation
    case text
    case binary
    case nonControlExtension(NonControlFrameExtension)
    case connectionClose
    case ping
    case pong
    case controlExtension(ControlFrameExtension)

    // 4 bytes
    init(_ i: Byte) throws {
        switch i {
        case 0:
            self = .continuation
        case 1:
            self = .text
        case 2:
            self = .binary
        case 3...7: // reserved non-control frame
            let ncf = try NonControlFrameExtension(i)
            self = .nonControlExtension(ncf)
        case 8:
            self = .connectionClose
        case 9:
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

extension OpCode: Equatable {}

public func == (lhs: OpCode, rhs: OpCode) -> Bool {
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

extension OpCode {
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

extension WebSocketHeader {
    /*
     Control frame CAN NOT be fragmented, but can be injected in between a fragmented message
     */
    public var isControlFrame: Bool {
        return opCode.isControlFrame
    }
}

// TODO: Rename => Frame? matches RFC better
// Frame usually refers to Header, maybe Header == Frame
extension WebSocketMessage {
    public var isControlFrame: Bool {
        return header.isControlFrame
    }
}

extension OpCode {
    public enum NonControlFrameExtension: UInt8 {
        case three, four, five, six, seven
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
    public enum ControlFrameExtension {
        case b, c, d, e, f
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

public struct WebSocketHeader {
    let fin: Bool

    /**
     Definable flags.
     
     If any flag is 'true' that is not explicitly defined, the socket MUST close: RFC
    */
    let rsv1: Bool
    let rsv2: Bool
    let rsv3: Bool

    let isMasked: Bool
    let opCode: OpCode

    let maskingKey: MaskingKey
    let payloadLength: UInt64
}


extension WebSocketMessage {
    public enum Error: ErrorProtocol {
        case failed
    }
}

//extension IteratorProtocol where Element == Byte {
//    mutating func extractHeader() throws -> WebSocketHeader {
//        /*
//         0
//         0 1 2 3 4 5 6 7
//         +-+-+-+-+-------+
//         |F|R|R|R| opcode|
//         |I|S|S|S|  (4)  |
//         |N|V|V|V|       |
//         | |1|2|3|       |
//         +-+-+-+-+-------+
//
//         */
//        guard let zero = next() else { throw WebSocketMessage.Error.failed }
//    }
//}

enum Payload {
//    case continuation
//    case text
//    case binary
//    //    case nonControl(NonControlFrame)
//    case connectionClose
//    case ping
//    case pong
    //    case con

    case text(String)
    case binary([Byte])

}

// https://tools.ietf.org/html/rfc6455#section-5.2
public struct WebSocketMessage {
    let header: WebSocketHeader
    // TODO: OpCode defines how to parse, I think this should be an enum ie: Payload above
    // for now while testing ... Data
    public let payload: Data
}

extension WebSocketMessage {
//    func makeForClient(_ text: String) -> Data {
//        let bytes = text.toBytes()
//        let header = WebSocketHeader(
//            fin: true,
//            rsv1: false,
//            rsv2: false,
//            rsv3: false,
//            isMasked: false,
//            opCode: .text,
//            maskingKey: .none,
//            payloadLength: UInt64(bytes.count)
//        )
//        let mockHeader
//
//        let message = WebSocketMessage(header: header, payload: Data(bytes))
//        return Data()
//    }
}

/*
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






 Fette & Melnikov             Standards Track                   [Page 34]

 RFC 6455                 The WebSocket Protocol            December 2011


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

extension WebSocketMessage {
    var isFragment: Bool {
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
    var isFragmentHeader: Bool {
        return !header.fin && header.opCode != .continuation
    }

    var isFragmentBody: Bool {
        return !header.fin && header.opCode == .continuation
    }

    var isFragmentFooter: Bool {
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
extension UInt8 {
    static let fin: Byte = 0b1000_0000
    static let rsv1: Byte = 0b0100_0000
    static let rsv2: Byte = 0b0010_0000
    static let rsv3: Byte = 0b0001_0000

    static let opCode: Byte = 0b0000_1111

    static let maskKeyIncluded: Byte = 0b1000_0000
    static let payloadLength: Byte = 0b0111_1111
}

extension String: ErrorProtocol {}

//func metadata(_ file: String = #file, _ function: String = #function, _ line: String = #line) -> String {
//    var str = "[Metadata]\n"
//    str += "\tFile: \(file.components(separatedBy: "/").last ?? "")\n"
//    str += "\tFunction: \(function)\n"
//    str += "\tLine: \(line)\n\n"
//    return str
//}

public final class MessageParser {
    private var iterator: AnyIterator<Byte>

    private init<S: Sequence where S.Iterator.Element == Byte>(_ data: S) {
        var sequenceIterator = data.makeIterator()
        iterator = AnyIterator { sequenceIterator.next() }
    }

    // MARK: Extractors

    private func extractByteZero() throws -> (fin: Bool, rsv1: Bool, rsv2: Bool, rsv3: Bool, opCode: OpCode) {
        guard let byteZero = iterator.next() else {
            throw "479: WebSockets.Swift: MessageParser"
        }
        let fin = byteZero.containsMask(.fin)
        let rsv1 = byteZero.containsMask(.rsv1)
        let rsv2 = byteZero.containsMask(.rsv2)
        let rsv3 = byteZero.containsMask(.rsv3)

        let opCode = try OpCode(byteZero & .opCode)
        return (fin, rsv1, rsv2, rsv3, opCode)
    }

    private func extractByteOne() throws -> (maskKeyIncluded: Bool, payloadLength: Byte) {
        guard let byteOne = iterator.next() else {
            throw "493: WebSockets.Swift: MessageParser"
        }
        let maskKeyIncluded = byteOne.containsMask(.maskKeyIncluded)
        let payloadLength = byteOne & .payloadLength
        return (maskKeyIncluded, payloadLength)
    }

    private enum ExtendedPayloadByteLength: UInt8 {
        case two = 2
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

    /**
     Returns UInt64 to encompass highest possible length. Length may be UInt16
     */
    private func extractExtendedPayloadLength(_ length: ExtendedPayloadByteLength) throws -> UInt64 {
        var bytes: [Byte] = []
        for _ in 1...length.rawValue {
            guard let next = iterator.next() else {
                throw "522: WebSockets.Swift: MessageParser"
            }
            bytes.append(next)
        }
        return try UInt64.init(bytes)
    }

    private func extractMaskingKey() throws -> MaskingKey {
        guard
            let zero = iterator.next(),
            let one = iterator.next(),
            let two = iterator.next(),
            let three = iterator.next()
            else {
                throw "536: WebSockets.Swift: MessageParser"
            }

        return .key(zero: zero, one: one, two: two, three: three)
    }

    private func extractPayload(key: MaskingKey) throws -> [Byte] {
        var bytes: [UInt8] = []

        switch key {
        case .none:
            while let next = iterator.next() {
                bytes.append(next)
            }
        case let .key(zero: zero, one: one, two: two, three: three):
            /*
             Octet i of the transformed data ("transformed-octet-i") is the XOR of
             octet i of the original data ("original-octet-i") with octet at index
             i modulo 4 of the masking key ("masking-key-octet-j"):

             j                   = i MOD 4
             transformed-octet-i = original-octet-i XOR masking-key-octet-j
             */

            // needs to be UInt64 because that's max payload length and we need the space
            var count = UInt64(0)
            let keys = [zero, one, two, three]
            while let original = iterator.next() {
                let key = keys[Int(count % 4)]
                let transformed = original ^ key
                bytes.append(transformed)
                count += 1
            }

        }

        return bytes
    }
}

extension MessageParser {
    public static func parseInput<S: Sequence where S.Iterator.Element == Byte>(_ data: S) throws -> WebSocketMessage {
        let parser = MessageParser(data)
        let (fin, rsv1, rsv2, rsv3, opCode) = try parser.extractByteZero()
        let (isMasked, payloadLengthInfo) = try parser.extractByteOne()

        let payloadLength: UInt64
        if let extended = ExtendedPayloadByteLength(payloadLengthInfo) {
            payloadLength = try parser.extractExtendedPayloadLength(extended)
        } else {
            payloadLength = payloadLengthInfo.toUIntMax()
        }

        let maskingKey: MaskingKey
        if isMasked {
            maskingKey = try parser.extractMaskingKey()
        } else {
            maskingKey = .none
        }

        let payload = try parser.extractPayload(key: maskingKey)
        guard payload.count == Int(payloadLength) else {
            throw "598: WebSockets.Swift: MessageParser"
        }

        let header = WebSocketHeader(
            fin: fin,
            rsv1: rsv1,
            rsv2: rsv2,
            rsv3: rsv3,
            isMasked: isMasked,
            opCode: opCode,
            maskingKey: maskingKey,
            payloadLength: payloadLength
        )


        return WebSocketMessage(header: header, payload: Data(payload))
    }
}


public final class StreamMessageParser {
//    private var iterator: AnyIterator<Byte>
    private let stream: Stream
    private init(_ stream: Stream) {
        self.stream = stream
//        print("next: \(next)")
//        var sequenceIterator = data.makeIterator()
//        iterator = AnyIterator { sequenceIterator.next() }
    }

    // TODO: Parsing single bytes here
    // Use chunking the way we did on other
    // part
    //
    // This section is not call / response, so chunking needs to be more accurate
    private func next() throws -> Byte? {
        return try stream.receive(upTo: 1).bytes.first
    }

    // MARK: Extractors

    private func extractByteZero() throws -> (fin: Bool, rsv1: Bool, rsv2: Bool, rsv3: Bool, opCode: OpCode) {
        guard let byteZero = try next() else {
            throw "479: WebSockets.Swift: MessageParser"
        }
        let fin = byteZero.containsMask(.fin)
        let rsv1 = byteZero.containsMask(.rsv1)
        let rsv2 = byteZero.containsMask(.rsv2)
        let rsv3 = byteZero.containsMask(.rsv3)

        let opCode = try OpCode(byteZero & .opCode)
        return (fin, rsv1, rsv2, rsv3, opCode)
    }

    private func extractByteOne() throws -> (maskKeyIncluded: Bool, payloadLength: Byte) {
        guard let byteOne = try next() else {
            throw "493: WebSockets.Swift: MessageParser"
        }
        let maskKeyIncluded = byteOne.containsMask(.maskKeyIncluded)
        let payloadLength = byteOne & .payloadLength
        return (maskKeyIncluded, payloadLength)
    }

    private enum ExtendedPayloadByteLength: UInt8 {
        case two = 2
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

    /**
     Returns UInt64 to encompass highest possible length. Length may be UInt16
     */
    private func extractExtendedPayloadLength(_ length: ExtendedPayloadByteLength) throws -> UInt64 {
        var bytes: [Byte] = []
        for _ in 1...length.rawValue {
            guard let next = try next() else {
                throw "522: WebSockets.Swift: MessageParser"
            }
            bytes.append(next)
        }
        return try UInt64.init(bytes)
    }

    private func extractMaskingKey() throws -> MaskingKey {
        guard
            let zero = try next(),
            let one = try next(),
            let two = try next(),
            let three = try next()
            else {
                throw "536: WebSockets.Swift: MessageParser"
        }

        return .key(zero: zero, one: one, two: two, three: three)
    }

    private func extractPayload(key: MaskingKey, length: UInt64) throws -> [Byte] {
        var count: UInt64 = 0
        var bytes: [UInt8] = []

        switch key {
        case .none:
            while count < length, let next = try next() {
                bytes.append(next)
                count += 1
            }
        case let .key(zero: zero, one: one, two: two, three: three):
            /*
             Octet i of the transformed data ("transformed-octet-i") is the XOR of
             octet i of the original data ("original-octet-i") with octet at index
             i modulo 4 of the masking key ("masking-key-octet-j"):

             j                   = i MOD 4
             transformed-octet-i = original-octet-i XOR masking-key-octet-j
             */

            // needs to be UInt64 because that's max payload length and we need the space
//            var count = UInt64(0)
            let keys = [zero, one, two, three]
            while count < length, let original = try next() {
                let key = keys[Int(count % 4)]
                let transformed = original ^ key
                bytes.append(transformed)
                count += 1
            }

        }

        return bytes
    }
}

extension StreamMessageParser {
    public static func parseInput(_ stream: Stream) throws -> WebSocketMessage {
        let parser = StreamMessageParser(stream)
        let (fin, rsv1, rsv2, rsv3, opCode) = try parser.extractByteZero()
        let (isMasked, payloadLengthInfo) = try parser.extractByteOne()

        let payloadLength: UInt64
        if let extended = ExtendedPayloadByteLength(payloadLengthInfo) {
            payloadLength = try parser.extractExtendedPayloadLength(extended)
        } else {
            payloadLength = payloadLengthInfo.toUIntMax()
        }

        let maskingKey: MaskingKey
        if isMasked {
            maskingKey = try parser.extractMaskingKey()
        } else {
            maskingKey = .none
        }

        let payload = try parser.extractPayload(key: maskingKey, length: payloadLength)
        guard payload.count == Int(payloadLength) else {
            throw "762: WebSockets.Swift: MessageParser"
        }

        let header = WebSocketHeader(
            fin: fin,
            rsv1: rsv1,
            rsv2: rsv2,
            rsv3: rsv3,
            isMasked: isMasked,
            opCode: opCode,
            maskingKey: maskingKey,
            payloadLength: payloadLength
        )
        
        
        return WebSocketMessage(header: header, payload: Data(payload))
    }
}

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

//internal struct LeftRightBitIterator {
//    private var iterator: AnyIterator<Bit>
//    init(_ byte: Byte) {
//        var mask: Byte = 0b1000_0000
//        iterator = AnyIterator {
//            guard mask > 0 else { return nil }
//            let next = byte.containsMask(mask)
//            mask >>= 1
//            return next ? .one : .zero
//        }
//    }
//
//    mutating func next(_ count: )
//}

private extension Byte {
    subscript(idx: Int) -> Bit {
        var zero: Byte = 0b1
        for _ in 0..<idx {
            zero <<= 1
        }
        return self.containsMask(zero) ? .one : .zero
    }
}

extension UnsignedInteger {
    public func containsMask(_ mask: Self) -> Bool {
        return (self & mask) == mask
    }
}

/*
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