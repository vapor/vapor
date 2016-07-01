import Jay

// Exporting type w/o forcing import
public typealias JSON = C7.JSON

extension JSON {
    public static var parse: (Bytes) throws -> JSON = { try Jay().typesafeJsonFromData($0) }
    public static var serialize: (JSON) throws -> Bytes = { try Jay(formatting: .minified).dataFromJson(json: $0) }
}

extension JSON {
    public init(_ value: Int) {
        self = .number(JSON.Number.integer(value))
    }

    public init(_ value: [JSONRepresentable]) {
        let array: [JSON] = value.map { item in
            return item.makeJSON()
        }
        self = .array(array)
    }

    public init(_ value: [String: JSONRepresentable]) {
        var object: [String: JSON] = [:]

        value.forEach { (key, item) in
            object[key] = item.makeJSON()
        }

        self = .object(object)
    }

    public init(_ value: Data) throws {
        self = try JSON.parse(value.bytes)
    }

    public var data: Data {
        do {
            let bytes = try JSON.serialize(self)
            return Data(bytes)
        } catch {
            return Data()
        }
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
    func makeJSON() -> JSON
}


extension JSONRepresentable {
    ///Allows any JsonRepresentable to be returned through closures
    public func makeResponse() throws -> Response {
        return try makeJSON().makeResponse()
    }
}

extension JSON: JSONRepresentable {
    public func makeJSON() -> JSON {
        return self
    }
}

extension String: JSONRepresentable {
    public func makeJSON() -> JSON {
        return JSON(self)
    }
}

extension Int: JSONRepresentable {
    public func makeJSON() -> JSON {
        return JSON(self)
    }
}

extension Double: JSONRepresentable {
    public func makeJSON() -> JSON {
        return JSON(self)
    }
}

extension Bool: JSONRepresentable {
    public func makeJSON() -> JSON {
        return JSON(self)
    }
}

extension JSON: ResponseRepresentable {
    public func makeResponse() throws -> Response {
        return try Response(status: .ok, json: self)
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

// MARK: Path Indexable

@_exported import PathIndexable
extension JSON: PathIndexable {
    public var pathIndexableObject: [String : JSON]? {
        return self.dictionary
    }
    public var pathIndexableArray: [JSON]? {
        return self.array
    }
}

extension JSON.Number {
    public var double: Double {
        switch self {
        case let .double(d):
            return d
        case let .integer(i):
            return Double(i)
        case let .unsignedInteger(u):
            return Double(u)
        }
    }

    public var int: Int {
        switch self {
        case let .double(d):
            return Int(d)
        case let .integer(i):
            return i
        case let .unsignedInteger(u):
            if u < UInt(Int.max) {
                return Int(u)
            } else {
                return Int.max
            }
        }
    }

    public var uint: UInt {
        switch self {
        case let .double(d) where d >= 0:
            return UInt(d)
        case let .integer(i) where i >= 0:
            return UInt(i)
        case let .unsignedInteger(u):
            return u
        default:
            return 0
        }
    }
}

extension JSON.Number: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .double(d):
            if d.truncatingRemainder(dividingBy: 1) == 0 {
                return Int(d).description
            } else {
                return d.description
            }
        case let .integer(i):
            return i.description
        case let .unsignedInteger(u):
            return u.description
        }
    }
}

extension JSON.Number: Equatable {}

public func == (lhs: JSON.Number, rhs: JSON.Number) -> Bool {
    switch lhs {
    case let .double(d):
        return d == rhs.double
    case let .integer(i):
        return i == rhs.int
    case let .unsignedInteger(u):
        return u == rhs.uint
    }
}

// MARK: Initialization

extension JSON {
    public init(_ value: Bool) {
        self = .boolean(value)
    }

    public init(_ value: Double) {
        self = .number(.double(value))
    }

    public init(_ value: String) {
        self = .string(value)
    }

    public init(_ value: [String : JSON]) {
        self = .object(value)
    }

    public init<T: SignedInteger>(_ value: T) {
        let int = Int(value.toIntMax())
        self = .number(.integer(int))
    }

    public init<T: UnsignedInteger>(_ value: T) {
        let uint = UInt(value.toUIntMax())
        self = .number(.unsignedInteger(uint))
    }

    public init<T : Sequence where T.Iterator.Element == JSON>(_ value: T) {
        let array = [JSON](value)
        self = .array(array)
    }

    public init<T : Sequence where T.Iterator.Element == (key: String, value: JSON)>(_ seq: T) {
        var obj: [String : JSON] = [:]
        seq.forEach { key, val in
            obj[key] = val
        }
        self = .object(obj)
    }
}

// MARK: Convenience

extension JSON {
    public var isNull: Bool {
        switch self {
        case .null:
            return true
        case let .string(s) where s.lowercased() == "null":
            return true
        default:
            return false
        }
    }
}

extension JSON {
    public var bool: Bool? {
        switch self {
        case let .boolean(b):
            return b
        case let .string(s):
            return Bool(s)
        case let .number(n) where n.double == 0 || n.double == 1:
            return n.double == 1
        case .null:
            return false
        default:
            return nil
        }
    }
}

extension JSON {
    public var number: Double? {
        switch self {
        case let .number(n):
            return n.double
        case let .string(s):
            return Double(s)
        case let .boolean(b):
            return b ? 1 : 0
        case .null:
            return 0
        default:
            return nil
        }
    }

    public var double: Double? {
        return self.number
    }

    public var float: Float? {
        return self.number.flatMap(Float.init)
    }

}

extension JSON {
    public var int: Int? {
        switch self {
        case let .number(n):
            return n.int
        case let .string(s):
            return Int(s)
        case let .boolean(b):
            return b ? 1 : 0
        case .null:
            return 0
        default:
            return nil
        }
    }
}

extension JSON {
    public var uint: UInt? {
        switch self {
        case let .number(n):
            return n.uint
        case let .string(s):
            return UInt(s)
        case let .boolean(b):
            return b ? 1 : 0
        case .null:
            return 0
        default:
            return nil
        }
    }
}

extension JSON {
    public var string: String? {
        switch self {
        case let .string(s):
            return s
        case let .number(n):
            return n.description
        case let .boolean(b):
            return b.description
        case .null:
            return "null"
        default:
            return nil
        }
    }
}

extension JSON: CustomStringConvertible {
    public var description: String {
        do {
            return try JSON.serialize(self).string
        } catch {
            return "Unable to serialize: \(error)"
        }
    }
}

extension JSON: CustomDebugStringConvertible {
    public var debugDescription: String {
        return description
    }
}

// MARK: Literal Convertibles

extension JSON: NilLiteralConvertible {
    public init(nilLiteral value: Void) {
        self = .null
    }
}

extension JSON: ArrayLiteralConvertible {
    public init(arrayLiteral elements: JSON...) {
        self = .array(elements)
    }
}

extension JSON: DictionaryLiteralConvertible {
    public init(dictionaryLiteral elements: (String, JSON)...) {
        var object = [String : JSON](minimumCapacity: elements.count)
        elements.forEach { key, value in
            object[key] = value
        }
        self = .object(object)
    }
}
