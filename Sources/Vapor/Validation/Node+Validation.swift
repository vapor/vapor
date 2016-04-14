
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


// TODO: New File

extension Request {
    public func validated<
        T: ValidationSuite
        where T.InputType: NodeInitializable>(by suite: T.Type = T.self, key: String)
        throws -> Valid<T> {
            guard let node = data[key] else {
                throw ValidationFailure<T>(input: nil)
            }
            
            return try node.validated(by: suite)
    }
}
