public struct NodeExtraction: ErrorProtocol {}

extension Node {
    public func validated<
        T: ValidationSuite
        where T.InputType: NodeInitializable>(by suite: T.Type = T.self)
        throws -> Valid<T> {
            let value = try T.InputType.makeWith(self)
            return try value.validated(by: suite)
    }
}

// TODO:
/*
 var array: [Node]? { get }
 var object: [String : Node]? { get }
 var json: Json? { get }
 */


public protocol Extractable {
    associatedtype Wrapped
    func extract() throws -> Wrapped
}

extension Extractable where Wrapped == Node {
    public func validated<
        T: ValidationSuite
        where T.InputType: NodeInitializable>(by suite: T.Type = T.self)
        throws -> Valid<T> {
            let wrapped = try extract()
            let value = try T.InputType.makeWith(wrapped)
            return try value.validated(by: suite)
    }
}

extension Optional: Extractable {
    public func extract() throws -> Wrapped {
        guard let value = self else {
            // TODO: Better Error
            throw NodeExtraction()
        }
        return value
    }
}
