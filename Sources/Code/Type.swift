public enum Type: Encodable {
    case `class`(Class)
    case `struct`(Struct)
    case `enum`(Enum)

    /// See Encodable.encode
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .`class`(let c): try c.encode(to: encoder)
        case .`struct`(let s): try s.encode(to: encoder)
        case .`enum`(let e): try e.encode(to: encoder)
        }
    }
}

extension Type: CustomStringConvertible {
    /// See CustomStringConvertible.description
    public var description: String {
        switch self {
        case .`class`(let c): return c.description
        default: return "type"
        }
    }
}

