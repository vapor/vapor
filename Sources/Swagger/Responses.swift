import HTTP

public final class Responses: Encodable {
    public struct CodingKeys: CodingKey, ExpressibleByStringLiteral {
        public var stringValue: String
        
        public init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        public var intValue: Int?
        
        public init?(intValue: Int) {
            return nil
        }
        
        public typealias StringLiteralType = String
        
        public init(stringLiteral value: String) {
            self.stringValue = value
        }
    }
    
    public var `default`: PossibleReference<Response>
    public var others = [Status: Response]()
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.default, forKey: "default")
        
        for (status, response) in others {
            try container.encode(response, forKey: CodingKeys(stringLiteral: status.code.description))
        }
    }
    
    public init(response: Response) {
        self.default = .direct(response)
    }
}

extension Status: Hashable {
    public var hashValue: Int {
        return self.code
    }
}
