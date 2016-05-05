extension Node {
    public func validated<
        T: ValidationSuite
        where T.InputType: NodeInitializable>(by suite: T.Type = T.self)
        throws -> Valid<T> {
            let value = try T.InputType.make(with: self)
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
    func extract() -> Wrapped?
}

extension Extractable where Wrapped == Node {
    public func validated<
        V: ValidationSuite
        where V.InputType: NodeInitializable>(by suite: V.Type = V.self)
        throws -> Valid<V> {
            guard let wrapped = extract() else {
                throw ValidationFailure(suite, input: nil)
            }
            let value = try V.InputType.make(with: wrapped)
            return try value.validated(by: suite)
    }
}

extension Optional: Extractable {
    public func extract() -> Wrapped? {
        return self
    }
}
