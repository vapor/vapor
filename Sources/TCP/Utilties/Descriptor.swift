/// A TCP socket descriptor.
public struct Descriptor: Hashable {
    /// The raw socket descriptor value
    public var raw: Int32

    /// Hashable.
    public var hashValue: Int {
        return Int(raw)
    }

    /// Equatable.
    public static func ==(lhs: Descriptor, rhs: Descriptor) -> Bool {
        return lhs.raw == rhs.raw
    }
}
