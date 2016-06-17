@_exported import PathIndexable

public protocol RequestContentSubscript {}

extension String: RequestContentSubscript { }
extension Int: RequestContentSubscript {}

/**
    The data received from the request in json body or url query
*/
public struct Content {
    // MARK: Initialization
    private weak var message: HTTP.Message?

    internal init(_ message: HTTP.Message) {
        self.message = message
    }

    // MARK: Subscripting
    public subscript(index: Int) -> Polymorphic? {
        if let value = message?.query["\(index)"] {
            return value
        } else if let value = message?.json?.array?[index] {
            return value
        } else if let value = message?.formURLEncoded?["\(index)"] {
            return value
        } else if let value = message?.multipart?["\(index)"] {
            return value
        } else {
            return nil
        }
    }

    public subscript(key: String) -> Polymorphic? {
        if let value = message?.query[key] {
            return value
        } else if let value = message?.json?.object?[key] {
            return value
        } else if let value = message?.formURLEncoded?[key] {
            return value
        } else if let value = message?.multipart?[key] {
            return value
        } else {
            return nil
        }
    }

    public subscript(indexes: PathIndex...) -> Polymorphic? {
        return self[indexes]
    }

    public subscript(indexes: [PathIndex]) -> Polymorphic? {
        if let value = message?.query[indexes] {
            return value
        } else if let value = message?.json?[indexes] {
            return value
        } else if let value = message?.formURLEncoded?[indexes] {
            return value
        } else {
            return nil
        }
    }
}
