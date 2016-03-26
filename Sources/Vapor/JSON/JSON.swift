import JSON

public class Json {
    
    private var _json: JSON
    
    public init(_ value: JSON) {
        _json = value
    }
    
    public init(_ value: Bool) {
        _json = .booleanValue(value)
    }
    
    public init(_ value: Double) {
        _json = .numberValue(value)
    }
    
    public init(_ value: Int) {
        _json = .numberValue(Double(value))
    }
    
    public init(_ value: String) {
        _json = .stringValue(value)
    }
    
    public init(_ value: [JSON]) {
        _json = .arrayValue(value)
    }
    
    public init(_ value: [String: JSON]) {
        _json = .objectValue(value)
    }
    
    public init(_ value: [UInt8]) throws {
        let data: Data = Data(value)
        _json = try JSONParser().parse(data)
    }
    
    public var data: [UInt8] {
        return JSONSerializer().serialize(_json).bytes
        
    }
    
    public subscript(key: String) -> Node? {
        return object?[key]
    }
    
    public subscript(index: Int) -> Node? {
        return array?[index]
    }
}

extension Json: ResponseConvertible {
    public func response() -> Response {
        return Response(status: .OK, data: data, contentType: .Json)
    }
}

extension Json: Node {
    public var isNull: Bool {
        switch _json {
        case .nullValue:
            return true
        default:
            return false
        }
    }

    public var bool: Bool? {
        switch _json {
        case .booleanValue(let bool):
            return bool
        default:
            return nil
        }
    }

    public var int: Int? {
        switch _json {
        case .numberValue(let double):
            return Int(double)
        default:
            return nil
        }
    }

    public var uint: UInt? {
        return nil
    }

    public var float: Float? {
        return nil
    }

    public var double: Double? {
        return nil
    }

    public var string: String? {
        switch _json {
        case .stringValue(let string):
            return string
        default:
            return nil
        }
    }

    public var array: [Node]? {
        switch _json {
        case .arrayValue(let array):
            return array.map { json in
                return Json(json)
            }
        default:
            return nil
        }
    }

    public var object: [String : Node]? {
        switch _json {
        case .objectValue(let object):
            var mapped: [String: Node] = [:]
            object.forEach { key, json in
                mapped[key] = Json(json)
            }
            return mapped
        default:
            return nil
        }
    }
    
    public var json: Json? {
        return self
    }
}