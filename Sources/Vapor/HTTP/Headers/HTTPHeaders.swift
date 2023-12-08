import NIOHTTP1

extension HTTPHeaders {
    /// `MediaType` specified by this message's `"Content-Type"` header.
    public var contentType: HTTPMediaType? {
        get {
            self.parseDirectives(name: .contentType).first.flatMap {
                HTTPMediaType(directives: $0)
            }
        }
        set {
            if let new = newValue?.serialize() {
                self.replaceOrAdd(name: .contentType, value: new)
            } else {
                self.remove(name: .contentType)
            }
        }
    }
    
    /// Returns a collection of `MediaTypePreference`s specified by this HTTP message's `"Accept"` header.
    ///
    /// You can access all `MediaType`s in this collection to check membership.
    ///
    ///     httpReq.accept.mediaTypes.contains(.html)
    ///
    /// Or you can compare preferences for two `MediaType`s.
    ///
    ///     let pref = httpReq.accept.comparePreference(for: .json, to: .html)
    ///
    public var accept: [HTTPMediaTypePreference] {
        self.parseDirectives(name: .accept).compactMap {
            HTTPMediaTypePreference(directives: $0)
        }
    }
}

extension HTTPHeaders: Codable {
    private enum CodingKeys: String, CodingKey { case name, value }
    
    public init(from decoder: any Decoder) throws {
        self.init()
        do {
            var container = try decoder.unkeyedContainer()
            
            while !container.isAtEnd {
                let nested = try container.nestedContainer(keyedBy: Self.CodingKeys.self)
                let name = try nested.decode(String.self, forKey: .name)
                let value = try nested.decode(String.self, forKey: .value)
                
                self.add(name: name, value: value)
            }
        } catch DecodingError.typeMismatch(let type, _) where "\(type)".starts(with: "Array<") {
            // Try the old format
            let container = try decoder.singleValueContainer()
            let dict = try container.decode([String: String].self)
            
            self.add(contentsOf: dict.map { ($0.key, $0.value) })
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        
        for (name, value) in self {
            var nested = container.nestedContainer(keyedBy: Self.CodingKeys.self)
            
            try nested.encode(name, forKey: .name)
            try nested.encode(value, forKey: .value)
        }
    }
}
