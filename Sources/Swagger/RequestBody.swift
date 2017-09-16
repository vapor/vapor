public struct RequestBody: Encodable, ExpressibleByDictionaryLiteral {
    public var description: String?
    public var content = [String: MediaType]()
    public var required = false
    
    public init(dictionaryLiteral elements: (String, MediaType)...) {
        for (key, value) in elements {
            self.content[key] = value
        }
    }
}
