extension FixedWidthInteger {
    public static func random() -> Self {
        return Self.random(in: .min ... .max)
    }

    public static func random<T>(using generator: inout T) -> Self
        where T : RandomNumberGenerator
    {
        return Self.random(in: .min ... .max, using: &generator)
    }
}

extension Array where Element: FixedWidthInteger {
    public static func random(count: Int) -> [Element] {
        var array: [Element] = .init(repeating: 0, count: count)
        (0..<count).forEach { array[$0] = Element.random() }
        return array
    }

    public static func random<T>(count: Int, using generator: inout T) -> [Element]
        where T: RandomNumberGenerator
    {
        var array: [Element] = .init(repeating: 0, count: count)
        (0..<count).forEach { array[$0] = Element.random() }
        return array
    }
}

extension Array where Element == UInt8 {
    public var base64: String {
        Data(self).base64EncodedString()
    }
}
