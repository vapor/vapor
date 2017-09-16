public final class Header: Encodable, ExpressibleByStringLiteral {
    public var name: String
    public var description: String?
    public var externalDocs: ExternalDocumentation?
    
    public init(stringLiteral value: String) {
        self.name = value
    }
}
