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

// TODO: Replace w/ real errors
extension String: ErrorProtocol {}
