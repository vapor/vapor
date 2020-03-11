extension HTTPHeaders {
    /// `MediaType` specified by this message's `"Content-Type"` header.
    public var contentType: HTTPMediaType? {
        get { return self.first(name: .contentType).flatMap(HTTPMediaType.parse) }
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
    /// You can returns all `MediaType`s in this collection to check membership.
    ///
    ///     httpReq.accept.mediaTypes.contains(.html)
    ///
    /// Or you can compare preferences for two `MediaType`s.
    ///
    ///     let pref = httpReq.accept.comparePreference(for: .json, to: .html)
    ///
    public var accept: [HTTPMediaTypePreference] {
        return self.first(name: .accept).flatMap([HTTPMediaTypePreference].parse) ?? []
    }
}

extension HTTPHeaders: Codable {
    public init(from decoder: Decoder) throws {
        let dictionary = try decoder.singleValueContainer().decode([String: String].self)
        self.init()
        for (name, value) in dictionary {
            self.add(name: name, value: value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var dictionary: [String: String] = [:]
        for (name, value) in self {
            dictionary[name] = value
        }
        var container = encoder.singleValueContainer()
        try container.encode(dictionary)
    }
}
