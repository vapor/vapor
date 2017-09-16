public struct Reference: Encodable {
    public enum CodingKeys: String, CodingKey {
        case ref = "$ref"
    }
    
    var ref: String
}

public enum PossibleReference<T: Encodable>: Encodable {
    case direct(T)
    case reference(Reference)
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .direct(let t):
            try t.encode(to: encoder)
        case .reference(let reference):
            try reference.encode(to: encoder)
        }
    }
}
