import Foundation

import struct Core.Bytes
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
        let data = Data(bytes: serialized)
        let json = try JSONSerialization.jsonObject(with: data)

        self = JSON._cast(json)
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
        } else if let dict = anyObject as? [String: Any] {
            var object: [String: JSON] = [:]
            for (key, val) in dict {
                object[key] = _cast(val)
            }
            return .object(object)
        } else if let array = anyObject as? [Any] {
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
