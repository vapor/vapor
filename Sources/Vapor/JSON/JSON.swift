import JSON

public enum Json {
    case null
    case bool(Bool)
    case double(Double)
    case int(Int)
    case string(String)
    case array([Json])
    case object([String: Json])

    public init(_ value: JSON) {
        switch value {
        case .nullValue:
            self = .null
        case .booleanValue(let bool):
            self = .bool(bool)
        case .numberValue(let number):
            if floor(number) == number {
                self = .int(Int(number))
            } else {
                self = .double(number)
            }
        case .stringValue(let string):
            self = .string(string)
        case .objectValue(let object):
            var mapped: [String: Json] = [:]
            object.forEach { (key, value) in
                mapped[key] = Json(value)
            }
            self = .object(mapped)
        case .arrayValue(let array):
            let mapped: [Json] = array.map { item in
                return Json(item)
            }

            self = .array(mapped)
        }
    }

    public init(_ value: Bool) {
        self = .bool(value)
    }

    public init(_ value: Double) {
        self = .double(value)
    }

    public init(_ value: Int) {
        self = .int(value)
    }

    public init(_ value: String) {
        self = .string(value)
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
        let json = try JSONParser().parse(data: value)
        self.init(json)
    }

    public var data: Data {
        return JSONSerializer().serialize(json: makeZewoJson())
    }

    private func makeZewoJson() -> JSON {
        switch self {
        case .null:
            return .nullValue
        case .bool(let bool):
            return .booleanValue(bool)
        case .int(let int):
            return .numberValue(Double(int))
        case .double(let double):
            return .numberValue(double)
        case .string(let string):
            return .stringValue(string)
        case .object(let object):
            var mapped: [String: JSON] = [:]
            object.forEach { (key, value) in
                mapped[key] = value.makeZewoJson()
            }

            return .objectValue(mapped)
        case .array(let array):
            let mapped: [JSON] = array.map { item in
                return item.makeZewoJson()
            }

            return .arrayValue(mapped)
        }
    }

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

extension JSON: JsonRepresentable {
    public func makeJson() -> Json {
        return Json(self)
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

extension Json: CustomStringConvertible {
    public var description: String {
        return makeZewoJson().description
    }
}

extension Json: ResponseRepresentable {
    public func makeResponse() -> Response {
        return Response(status: .ok, json: self)
    }
}

extension Json: Node {
    public var isNull: Bool {
        switch self {
        case .null:
            return true
        default:
            return false
        }
    }

    public var bool: Bool? {
        switch self {
        case .bool(let bool):
            return bool
        default:
            return nil
        }
    }

    public var int: Int? {
        switch self {
        case .int(let int):
            return Int(int)
        default:
            return nil
        }
    }

    public var uint: UInt? {
        switch self {
        case .int(let int):
            return UInt(int)
        default:
            return nil
        }
    }

    public var float: Float? {
        switch self {
        case .double(let double):
            return Float(double)
        default:
            return nil
        }
    }

    public var double: Double? {
        switch self {
        case .double(let double):
            return Double(double)
        default:
            return nil
        }
    }

    public var string: String? {
        switch self {
        case .string(let string):
            return string
        default:
            return nil
        }
    }

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
