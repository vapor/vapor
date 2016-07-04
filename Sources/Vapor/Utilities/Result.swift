public enum Result<T> {
    case success(T)
    case failure(ErrorProtocol)
}

extension Result {
    public func extract() throws -> T {
        switch self {
        case .success(let val):
            return val
        case .failure(let e):
            throw e
        }
    }
}

extension Result {
    public var value: T? {
        guard case let .success(val) = self else { return nil }
        return val
    }

    public var error: ErrorProtocol? {
        guard case let .failure(err) = self else { return nil }
        return err
    }
}

extension Result {
    public var succeeded: Bool {
        return value != nil
    }
}
