/**
 These are global functions because I can't extend array, and 
 it's considerably easier than dealing with sequence or collection

 It is also helpful when parsing to percent encode without converting to string
 
 Wrappers around String can be built
 */

public func percentDecoded(_ input: [Byte]) -> [Byte]? {
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

            guard secondHex < input.count else { return nil }
            let bytes = input[firstHex...secondHex].array
            guard let str = try? bytes.toString() else { return nil }
            guard let encodedByte = Byte(str, radix: 16) else { return nil }
            group.append(encodedByte)
        } else {
            group.append(next)
            idx += 1
        }
    }
    return group
}

public func percentEncoded(_ input: [Byte], shouldEncode: (Byte) throws -> Bool = { _ in true }) throws -> [Byte] {
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
