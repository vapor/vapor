public class Example: Encodable {
    public enum CodingKeys: String, CodingKey {
        case summary, description, value, externalValue
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(summary, forKey: .summary)
        try container.encode(description, forKey: .description)
        try container.encode(value, forKey: .value)
        try container.encode(externalValue, forKey: .externalValue)
    }
    
    public var summary: String?
    public var description: String?
    public var value: Encodable?
    public var externalValue: String?
    
    public init() {}
}
