public final class MediaType: Encodable {
    public enum CodingKeys: String, CodingKey {
        case schema, example, examples, encoding
    }
    
    public var schema: PossibleReference<Schema>?
    public var example: Encodable?
    public var examples = [String: PossibleReference<Example>]()
    public var encoding = [String: Encoding]()
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(schema, forKey: .schema)
        try container.encode(example, forKey: .example)
        try container.encode(examples, forKey: .examples)
        try container.encode(encoding, forKey: .encoding)
    }
}
