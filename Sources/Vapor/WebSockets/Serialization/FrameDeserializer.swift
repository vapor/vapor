public enum FrameParserError: ErrorProtocol {
    case missingByte
}

public final class FrameParser {
    private var stream: Stream

    public init(stream: Stream) {
        self.stream = stream
    }

    public func acceptFrame() throws -> WebSocket.Frame {
        let (fin, rsv1, rsv2, rsv3, opCode) = try extractByteZero()
        let (isMasked, payloadLengthInfo) = try extractByteOne()

        /**
         Returns UInt64 to encompass highest possible length. Length may be UInt16
         */
        let payloadLength: UInt64
        switch payloadLengthInfo {
        case Byte.twoBytePayloadLength:
            payloadLength = try extractTwoBytePayloadLengthExtension().toUIntMax()
        case Byte.eightBytePayloadLength:
            payloadLength = try extractEightBytePayloadLengthExtension()
        default:
            payloadLength = payloadLengthInfo.toUIntMax()
        }

        let maskingKey: WebSocket.Frame.MaskingKey
        if isMasked {
            maskingKey = try extractMaskingKey()
        } else {
            maskingKey = .none
        }

        let payload = try extractPayload(key: maskingKey, length: payloadLength)

        let header = WebSocket.Frame.Header(
            fin: fin,
            rsv1: rsv1,
            rsv2: rsv2,
            rsv3: rsv3,
            opCode: opCode,
            isMasked: isMasked,
            payloadLength: payloadLength,
            maskingKey: maskingKey
        )
        return WebSocket.Frame(header: header, payload: Data(payload))
    }

    // MARK: Private
    
    private func extractByteZero() throws -> (fin: Bool, rsv1: Bool, rsv2: Bool, rsv3: Bool, opCode: WebSocket.Frame.OpCode) {
        guard let byteZero = try stream.receive() else {
            throw FrameParserError.missingByte
        }
        let fin = byteZero.containsMask(.finFlag)
        let rsv1 = byteZero.containsMask(.rsv1Flag)
        let rsv2 = byteZero.containsMask(.rsv2Flag)
        let rsv3 = byteZero.containsMask(.rsv3Flag)

        let opCode = try WebSocket.Frame.OpCode(byteZero & .opCodeFlag)
        return (fin, rsv1, rsv2, rsv3, opCode)
    }

    private func extractByteOne() throws -> (maskKeyIncluded: Bool, payloadLength: Byte) {
        guard let byteOne = try stream.receive() else {
            throw FrameParserError.missingByte
        }
        let maskKeyIncluded = byteOne.containsMask(.maskKeyIncludedFlag)
        let payloadLength = byteOne & .payloadLengthFlag
        return (maskKeyIncluded, payloadLength)
    }

    /**
     Returns UInt64 to encompass highest possible length. Length will be UInt16
     */
    private func extractTwoBytePayloadLengthExtension() throws -> UInt64 {
        let two = try stream.receive(max: 2)
        return UInt64(two)
    }


    private func extractEightBytePayloadLengthExtension() throws -> UInt64 {
        let eight = try stream.receive(max: 8)
        return UInt64(eight)
    }

    private func extractMaskingKey() throws -> WebSocket.Frame.MaskingKey {
        guard
            let zero = try stream.receive(),
            let one = try stream.receive(),
            let two = try stream.receive(),
            let three = try stream.receive()
            else { throw FrameParserError.missingByte }

        return .key(zero: zero, one: one, two: two, three: three)
    }

    private func extractPayload(key: WebSocket.Frame.MaskingKey, length: UInt64) throws -> [Byte] {
        var count: UInt64 = 0
        var bytes: [UInt8] = []

        while count < length, let next = try stream.receive() {
            bytes.append(next)
            count += 1
        }

        return key.hash(bytes)
    }
}
