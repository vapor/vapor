import JSON

public class Json {
    
    var json: JSON
    
    public init(_ value: JSON) {
        json = value
    }
    
    public init(_ value: Bool) {
        json = .booleanValue(value)
    }
    
    public init(_ value: Double) {
        json = .numberValue(value)
    }
    
    public init(_ value: Int) {
        json = .numberValue(Double(value))
    }
    
    public init(_ value: String) {
        json = .stringValue(value)
    }
    
    public init(_ value: [JSON]) {
        json = .arrayValue(value)
    }
    
    public init(_ value: [String: JSON]) {
        json = .objectValue(value)
    }
    
    public init(_ value: [UInt8]) throws {
        let data: Data = Data(value)
        json = try JSONParser().parse(data)
    }
    
    public var data: [UInt8] {
        return JSONSerializer().serialize(json).bytes
        
    }
}

extension Json: ResponseConvertible {
    public func response() -> Response {
        return Response(status: .OK, data: data, contentType: .Json)
    }
}

extension Json: Node {
    public var isNull: Bool {
        switch json {
        case .nullValue:
            return true
        default:
            return false
        }
    }

    public var bool: Bool? {
        switch json {
        case .booleanValue(let bool):
            return bool
        default:
            return nil
        }
    }

    public var int: Int? {
        switch json {
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
        switch json {
        case .stringValue(let string):
            return string
        default:
            return nil
        }
    }

    public var array: [Node]? {
        switch json {
        case .arrayValue(let array):
            return array.map { json in
                return Json(json)
            }
        default:
            return nil
        }
    }

    public var object: [String : Node]? {
        switch json {
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
}