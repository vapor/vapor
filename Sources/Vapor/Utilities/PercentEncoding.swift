public func percentDecoded(_ input: [Byte]) throws -> [Byte] {
    var idx = 0
    var group: [Byte] = []
    while idx < input.count {
        let next = input[idx]
        if next.equals(any: .percentSign) {
            // %  2  A
            // i +1 +2
            let firstHex = idx + 1
            let secondHex = idx + 2
            idx = secondHex + 1

            guard secondHex < input.count else { throw "invalid percent encoding" }
            let bytes = input[firstHex...secondHex].array
            let str = try bytes.toString()
            guard let encodedByte = Byte(str, radix: 16) else { throw "invalid percent encoding" }
            group.append(encodedByte)
        } else {
            group.append(next)
            idx += 1
        }
    }
    return group
}

public func percentEncoded(_ input: [Byte], shouldEncode: (Byte) throws -> Bool) throws -> [Byte] {
    var group: [Byte] = []
    try input.forEach { byte in
        if try shouldEncode(byte) {
            let hex = String(byte, radix: 16).utf8
            group.append(.percentSign)
            if hex.count == 1 {
                group.append(.zeroCharacter)
            }
            group.append(contentsOf: hex)
        } else {
            group.append(byte)
        }
    }
    return group
}
