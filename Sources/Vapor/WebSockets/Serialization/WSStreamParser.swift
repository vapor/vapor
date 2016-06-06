public final class MessageParser<O: OutputStream where O.Element == Byte> {
    private var buffer: O

    private init(_ inputStream: O) {
        self.buffer = inputStream
    }

    // MARK: Extractors

    private func extractByteZero() throws -> (fin: Bool, rsv1: Bool, rsv2: Bool, rsv3: Bool, opCode: WebSock.Message.OpCode) {
        guard let byteZero = try buffer.next() else {
            throw "479: WebSockets.Swift: MessageParser"
        }
        let fin = byteZero.containsMask(.fin)
        let rsv1 = byteZero.containsMask(.rsv1)
        let rsv2 = byteZero.containsMask(.rsv2)
        let rsv3 = byteZero.containsMask(.rsv3)

        let opCode = try WebSock.Message.OpCode(byteZero & .opCode)
        return (fin, rsv1, rsv2, rsv3, opCode)
    }

    private func extractByteOne() throws -> (maskKeyIncluded: Bool, payloadLength: Byte) {
        guard let byteOne = try buffer.next() else {
            throw "493: WebSockets.Swift: MessageParser"
        }
        let maskKeyIncluded = byteOne.containsMask(.maskKeyIncluded)
        let payloadLength = byteOne & .payloadLength
        return (maskKeyIncluded, payloadLength)
    }

    /**
     Returns UInt64 to encompass highest possible length. Length may be UInt16
     */
    private func extractExtendedPayloadLength(_ length: ExtendedPayloadByteLength) throws -> UInt64 {
        var bytes: [Byte] = []
        for _ in 1...length.rawValue {
            guard let next = try buffer.next() else {
                throw "522: WebSockets.Swift: MessageParser"
            }
            bytes.append(next)
        }
        return try UInt64.init(bytes)
    }

    private func extractMaskingKey() throws -> MaskingKey {
        guard
            let zero = try buffer.next(),
            let one = try buffer.next(),
            let two = try buffer.next(),
            let three = try buffer.next()
            else {
                throw "536: WebSockets.Swift: MessageParser"
        }

        return .key(zero: zero, one: one, two: two, three: three)
    }

    private func extractPayload(key: MaskingKey, length: UInt64) throws -> [Byte] {
        var count: UInt64 = 0
        var bytes: [UInt8] = []

        while count < length, let next = try buffer.next() {
            bytes.append(next)
            count += 1
        }

        return key.cypher(bytes)
    }
}

extension MessageParser where O: StreamBuffer {
    public static func parse(stream: Stream) throws -> WebSock.Message {
        let buffer = O.init(stream)
        return try parse(data: buffer)
    }
}

extension MessageParser {
    public static func parse(data: O) throws -> WebSock.Message {
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

        let payload = try parser.extractPayload(key: maskingKey, length: payloadLength)
        guard payload.count == Int(payloadLength) else {
            throw "598: WebSockets.Swift: MessageParser"
        }

//        public struct Header {
//            public let fin: Bool
//
//            /**
//             Definable flags.
//
//             If any flag is 'true' that is not explicitly defined, the socket MUST close: RFC
//             */
//            public let rsv1: Bool
//            public let rsv2: Bool
//            public let rsv3: Bool
//
//            public let opCode: OpCode
//
//            public let isMasked: Bool
//            public let payloadLength: UInt64
//            
//            public let maskingKey: MaskingKey
//        }
//        WebSock.Message.Header

        let header = WebSock.Message.Header(
            fin: fin,
            rsv1: rsv1,
            rsv2: rsv2,
            rsv3: rsv3,
            opCode: opCode,
            isMasked: isMasked,
            payloadLength: payloadLength,
            maskingKey: maskingKey
        )
        return WebSock.Message(header: header, payload: Data(payload))
    }
}
