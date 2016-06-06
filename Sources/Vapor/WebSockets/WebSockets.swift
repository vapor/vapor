

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

extension String: ErrorProtocol {}

//func metadata(_ file: String = #file, _ function: String = #function, _ line: String = #line) -> String {
//    var str = "[Metadata]\n"
//    str += "\tFile: \(file.components(separatedBy: "/").last ?? "")\n"
//    str += "\tFunction: \(function)\n"
//    str += "\tLine: \(line)\n\n"
//    return str
//}

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

