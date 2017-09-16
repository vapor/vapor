import Foundation

public final class OpenAPI: Encodable {
    public let openapi = "3.0.0"
    public var info: Info
    public var paths = Paths()
    
    public init(named name: String) {
        self.info = Info(named: name)
    }
    
    public func serialize() throws -> String? {
        return String(bytes: try JSONEncoder().encode(self), encoding: .utf8)
    }
}

public enum Error: Swift.Error {
    case pathIsRequired
    case unacceptableStyle(in: Parameter.In)
}

public class Schema: Encodable {
    
}
