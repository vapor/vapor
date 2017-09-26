public final class PathItem: Encodable {
    public enum CodingKeys: String, CodingKey {
        case ref = "$ref"
        case summary
        case description
        case get, put, post, delete, options, head, patch, trace
        case parameters
    }
    
    public var ref: String?
    public var summary: String?
    public var description: String?
    
    public var get: Operation?
    public var put: Operation?
    public var post: Operation?
    public var delete: Operation?
    public var options: Operation?
    public var head: Operation?
    public var patch: Operation?
    public var trace: Operation?
    
    // TODO: public var servers
    
    public var parameters = [PossibleReference<Parameter>]()
    
    public init() {}
}
