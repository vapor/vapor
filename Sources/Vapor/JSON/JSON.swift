import PureJson

// Exporting type w/o forcing import
public typealias Json = PureJson.Json

extension Json {
    public init(_ value: Int) {
        self = .number(Double(value))
    }

    public init(_ value: [JsonRepresentable]) {
        let array: [Json] = value.map { item in
            return item.makeJson()
        }
        self = .array(array)
    }

    public init(_ value: [String: JsonRepresentable]) {
        var object: [String: Json] = [:]

        value.forEach { (key, item) in
            object[key] = item.makeJson()
        }

        self = .object(object)
    }

    public init(_ value: Data) throws {
        self = try Json.deserialize(value.bytes)
    }

    public var data: Data {
        let bytes = serialize().utf8
        return Data(bytes)
    }
}

extension Json {
    public subscript(key: String) -> Node? {
        switch self {
        case .object(let object):
            return object[key]
        default:
            return nil
        }
    }

    public subscript(index: Int) -> Node? {
        switch self {
        case .array(let array):
            return array[index]
        default:
            return nil
        }
    }
}

extension Json {
    mutating func merge(with otherJson: Json) {
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

public protocol JsonRepresentable: ResponseRepresentable {
    func makeJson() -> Json
}


extension JsonRepresentable {
    ///Allows any JsonRepresentable to be returned through closures
    public func makeResponse() -> Response {
        return makeJson().makeResponse()
    }
}

extension Json: JsonRepresentable {
    public func makeJson() -> Json {
        return self
    }
}

extension String: JsonRepresentable {
    public func makeJson() -> Json {
        return Json(self)
    }
}

extension Int: JsonRepresentable {
    public func makeJson() -> Json {
        return Json(self)
    }
}

extension Double: JsonRepresentable {
    public func makeJson() -> Json {
        return Json(self)
    }
}

extension Bool: JsonRepresentable {
    public func makeJson() -> Json {
        return Json(self)
    }
}

extension Json: ResponseRepresentable {
    public func makeResponse() -> Response {
        return Response(status: .ok, json: self)
    }
}

extension Json: Node {
    public var array: [Node]? {
        switch self {
        case .array(let array):
            return array.map { item in
                return item
            }
        default:
            return nil
        }
    }

    public var object: [String : Node]? {
        switch self {
        case .object(let object):
            var dict: [String : Node] = [:]

            object.forEach { (key, val) in
                dict[key] = val
            }

            return dict
        default:
            return nil
        }
    }

    public var json: Json? {
        return self
    }
}
