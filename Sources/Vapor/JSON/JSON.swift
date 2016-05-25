import PureJSON

// Exporting type w/o forcing import
public typealias JSON = PureJSON.JSON

extension JSON {
    public init(_ value: Int) {
        self = .number(JSON.Number.integer(value))
    }

    public init(_ value: [JSONRepresentable]) {
        let array: [JSON] = value.map { item in
            return item.makeJson()
        }
        self = .array(array)
    }

    public init(_ value: [String: JSONRepresentable]) {
        var object: [String: JSON] = [:]

        value.forEach { (key, item) in
            object[key] = item.makeJson()
        }

        self = .object(object)
    }

    public init(_ value: Data) throws {
        self = try JSON.deserialize(value.bytes)
    }

    public var data: Data {
        let bytes = serialize().utf8
        return Data(bytes)
    }
}

extension JSON {
    public subscript(key: String) -> Polymorphic? {
        switch self {
        case .object(let object):
            return object[key]
        default:
            return nil
        }
    }

    public subscript(index: Int) -> Polymorphic? {
        switch self {
        case .array(let array):
            return array[index]
        default:
            return nil
        }
    }
}

extension JSON {
    mutating func merge(with otherJson: JSON) {
        switch self {
        case .object(let object):
            guard case let .object(otherObject) = otherJson else {
                self = otherJson
                return
            }

            var merged = object

            for (key, value) in otherObject {
                if let original = object[key] {
                    var newValue = original
                    newValue.merge(with: value)
                    merged[key] = newValue
                } else {
                    merged[key] = value
                }
            }

            self = .object(merged)
        case .array(let array):
            guard case let .array(otherArray) = otherJson else {
                self = otherJson
                return
            }

            self = .array(array + otherArray)
        default:
            self = otherJson
        }
    }
}

public protocol JSONRepresentable: ResponseRepresentable {
    func makeJson() -> JSON
}


extension JSONRepresentable {
    ///Allows any JsonRepresentable to be returned through closures
    public func makeResponse() -> Response {
        return makeJson().makeResponse()
    }
}

extension JSON: JSONRepresentable {
    public func makeJson() -> JSON {
        return self
    }
}

extension String: JSONRepresentable {
    public func makeJson() -> JSON {
        return JSON(self)
    }
}

extension Int: JSONRepresentable {
    public func makeJson() -> JSON {
        return JSON(self)
    }
}

extension Double: JSONRepresentable {
    public func makeJson() -> JSON {
        return JSON(self)
    }
}

extension Bool: JSONRepresentable {
    public func makeJson() -> JSON {
        return JSON(self)
    }
}

extension JSON: ResponseRepresentable {
    public func makeResponse() -> Response {
        return Response(status: .ok, json: self)
    }
}

extension JSON: Polymorphic {
    public var array: [Polymorphic]? {
        switch self {
        case .array(let array):
            return array.map { item in
                return item
            }
        default:
            return nil
        }
    }

    public var object: [String : Polymorphic]? {
        switch self {
        case .object(let object):
            var dict: [String : Polymorphic] = [:]

            object.forEach { (key, val) in
                dict[key] = val
            }

            return dict
        default:
            return nil
        }
    }
}
