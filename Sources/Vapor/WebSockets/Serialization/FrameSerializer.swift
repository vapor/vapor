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

    public init(_ message: WebSock.Frame) {
        self.message = message
    }

    public func serialize() -> [Byte] {
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
