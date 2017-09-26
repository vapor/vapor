public final class Response: Encodable, ExpressibleByStringLiteral {
    public var description: String
    public var headers = [String: Header]()
    public var content = [String: MediaType]()
    // TODO:   public var links = [String: PossibleReference<Link>]()
    
    public init(stringLiteral value: String) {
        self.description = value
    }
}
