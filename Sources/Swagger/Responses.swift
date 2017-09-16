import HTTP

public final class Responses: Encodable {
    public var `default`: PossibleReference<Response>
    public var others = [Status: Response]()
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: SwaggerKeys.self)
        
        try container.encode(self.default, forKey: "default")
        
        for (status, response) in others {
            try container.encode(response, forKey: SwaggerKeys(stringLiteral: status.code.description))
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
