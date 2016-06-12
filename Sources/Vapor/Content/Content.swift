@_exported import PathIndexable

public protocol RequestContentSubscript {}

extension String: RequestContentSubscript { }
extension Int: RequestContentSubscript {}

/**
    The data received from the request in json body or url query
*/
public struct Content {
    // MARK: Initialization
    let request: Request

    internal init(request: Request) {
        self.request = request
    }

    // MARK: Subscripting
    public subscript(index: Int) -> Polymorphic? {
        if let value = request.query["\(index)"] {
            return value
        } else if let value = request.json?.array?[index] {
            return value
        } else if let value = request.formURLEncoded?["\(index)"] {
            return value
        } else if let value = request.multipart?["\(index)"] {
            return value
        } else {
            return nil
        }
    }

    public subscript(key: String) -> Polymorphic? {
        if let value = request.query[key] {
            return value
        } else if let value = request.json?.object?[key] {
            return value
        } else if let value = request.formURLEncoded?[key] {
            return value
        } else if let value = request.multipart?[key] {
            return value
        } else {
            return nil
        }
    }

    public subscript(indexes: PathIndex...) -> Polymorphic? {
        return self[indexes]
    }

    public subscript(indexes: [PathIndex]) -> Polymorphic? {
        if let value = request.query[indexes] {
            return value
        } else if let value = request.json?[indexes] {
            return value
        } else if let value = request.formURLEncoded?[indexes] {
            return value
        } else {
            return nil
        }
    }
}
