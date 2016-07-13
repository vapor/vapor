//import Jay
import Foundation

#if !os(Linux)
    private typealias NSData = Foundation.Data
#endif

#if os(Linux)
    extension NSData {
        var count: Int {
            return length
        }

        func copyBytes(to bytes: UnsafeMutablePointer<Void>, count: Int) {
            getBytes(bytes, length: count)
        }
    }

    typealias JSONSerialization = Foundation.NSJSONSerialization

    extension Foundation.NSMutableDictionary {
        public subscript(key: String) -> AnyObject {
            get {
                return self.objectForKey(NSString(string: key))
            }
            set {
                self.setObject(newValue, forKey: NSString(string: key))
            }
        }
    }

    extension Foundation.NSMutableArray {
        public func add(_ object: AnyObject) {
            self.addObject(object)
        }
    }
#endif

import struct Base.Bytes
import protocol Engine.HTTPResponseRepresentable

public enum JSON {
    public enum Number {
        case integer(Int)
        case double(Double)
    }

    case object([String: JSON])
    case array([JSON])
    case number(Number)
    case string(String)
    case bool(Bool)
    case null

    public init(_ string: String) {
        self = .string(string)
    }

    public init(_ array: [JSONRepresentable]) {
        self = .array(array.map { $0.makeJSON() })
    }

    public init(_ object: [String: JSONRepresentable]) {
        var json: [String: JSON] = [:]

        for (key, value) in object {
            json[key] = value.makeJSON()
        }

        self = .object(json)
    }

    public init(_ array: [JSON]) {
        self = .array(array)
    }

    public init(_ object: [String: JSON]) {
        self = .object(object)
    }

}

// MARK: Nasty Foundation code

extension JSON {
    public init(serialized: Bytes) throws {
        let data = NSData(bytes: serialized)
        let json = try JSONSerialization.jsonObject(with: data)

        self = JSON._cast(json)

        print(self)
    }

    private static func _cast(_ anyObject: Any) -> JSON {
        if let dict = anyObject as? [String: AnyObject] {
            var object: [String: JSON] = [:]
            for (key, val) in dict {
                object[key] = _cast(val)
            }
            return .object(object)
        } else if let array = anyObject as? [AnyObject] {
            return .array(array.map { _cast($0) })
        } else if let int = anyObject as? Int {
            return .number(.integer(int))
        } else if let double = anyObject as? Double {
            return .number(.double(double))
        } else if let string = anyObject as? String {
            return .string(string)
        } else if let bool = anyObject as? Bool {
            return .bool(bool)
        }
        return .null
    }

    public func serialize() throws -> Bytes {
        let object = JSON._uncast(self)
        let data = try JSONSerialization.data(withJSONObject: object)

        var buffer = Bytes(repeating: 0, count: data.count)
        data.copyBytes(to: &buffer, count: data.count)

        return buffer
    }

    private static func _uncast(_ json: JSON) -> AnyObject {
        switch json {
        case .object(let object):
            let dict = NSMutableDictionary()
            for (key, val) in object {
                dict[key] = _uncast(val)
            }
            return dict.copy()
        case .array(let array):
            let nsarray = NSMutableArray()
            for item in array {
                nsarray.add(_uncast(item))
            }
            return nsarray.copy()
        case .number(let number):
            switch number {
            case .double(let double):
                return NSNumber(floatLiteral: double)
            case .integer(let int):
                return NSNumber(integerLiteral: int)
            }
        case .string(let string):
            return NSString(string: string)
        case .bool(let bool):
            return NSNumber(booleanLiteral: bool)
        case .null:
            return NSNull()
        }
    }

}

public protocol JSONRepresentable: ResponseRepresentable {
    func makeJSON() -> JSON
}

extension JSON: ResponseRepresentable {
    public func makeResponse(for: Request) throws -> Response {
        return try Response(status: .ok, json: self)
    }
}

extension JSON: JSONRepresentable {
    public func makeJSON() -> JSON {
        return self
    }
}

extension Bool: JSONRepresentable {
    public func makeJSON() -> JSON {
        return .bool(self)
    }
}

extension String: JSONRepresentable {
    public func makeJSON() -> JSON {
        return .string(self)
    }
}

extension Int: JSONRepresentable {
    public func makeJSON() -> JSON {
        return .number(.integer(self))
    }
}

extension JSONRepresentable {
    ///Allows any JsonRepresentable to be returned through closures
    public func makeResponse(for request: Request) throws -> Response {
        return try makeJSON().makeResponse(for: request)
    }
}

// TODO: Fuzzy
extension JSON: Polymorphic {
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
            return false
        }
    }

    public var float: Float? {
        switch self {
        case .number(let number):
            switch number {
            case .double(let double):
                return Float(double)
            default:
                return nil
            }
        default:
            return nil
        }
    }

    public var double: Double? {
        switch self {
        case .number(let number):
            switch number {
            case .double(let double):
                return double
            default:
                return nil
            }
        default:
            return nil
        }
    }

    public var int: Int? {
        switch self {
        case .number(let number):
            switch number {
            case .integer(let int):
                return int
            default:
                return nil
            }
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
    public var pathIndexableObject: [String: JSON]? {
        switch self {
        case .object(let object):
            return object
        default:
            return nil
        }
    }

    public var pathIndexableArray: [JSON]? {
        switch self {
        case .array(let array):
            return array
        default:
            return nil
        }
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
