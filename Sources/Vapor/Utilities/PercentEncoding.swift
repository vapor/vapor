/**
    These are global functions because I can't extend array, and
    it's considerably easier than dealing with sequence or collection

    It is also helpful when parsing to percent encode without converting to string

    Wrappers around String can be built
*/

public func percentDecoded(
    _ input: ArraySlice<Byte>,
    transform: (Byte) -> (Byte) = { $0 }
) -> Data? {
    return percentDecoded(Data(input), transform: transform)
}

public func percentDecoded(
    _ input: Data,
    transform: (Byte) -> (Byte) = { $0 }
) -> Data? {
    guard let bytes = percentDecoded(input.bytes, transform: transform) else {
        return nil
    }

    return Data(bytes)
}

public func percentDecoded(
    _ input: [Byte],
    transform: (Byte) -> (Byte) = { $0 }
) -> [Byte]? {
    var idx = 0
    var group: [Byte] = []
    while idx < input.count {
        let next = input[idx]
        if next == .percent {
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
            let transformed = transform(next)
            group.append(transformed)
            idx += 1 // don't put outside of else
        }
    }
    return group
}

public func percentEncoded(
    _ input: [Byte],
    shouldEncode: (Byte) throws -> Bool = { _ in true }
) throws -> [Byte] {
    var group: [Byte] = []
    try input.forEach { byte in
        if try shouldEncode(byte) {
            let hex = String(byte, radix: 16).utf8
            group.append(.percent)
            if hex.count == 1 {
                group.append(.zero)
            }
            group.append(contentsOf: hex)
        } else {
            group.append(byte)
        }
    }
    return group
}
