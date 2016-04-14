
extension Node {
    public func validated<
        T: ValidationSuite
        where T.InputType: NodeInitializable>(by suite: T.Type = T.self)
        throws -> Validated<T> {
            let value = try T.InputType.makeWith(self)
            return try value.validated(by: suite)
    }
}

extension Optional where Wrapped: Node {
    public func validated<
        V: ValidationSuite
        where V.InputType: NodeInitializable>(by suite: V.Type = V.self)
        throws -> Validated<V> {
            guard let wrapped = self else {
                throw ValidationFailure<V>(input: nil)
            }
            let value = try V.InputType.makeWith(wrapped)
            return try value.validated(by: suite)
    }
}

// TODO:
/*
 var array: [Node]? { get }
 var object: [String : Node]? { get }
 var json: Json? { get }
 */
