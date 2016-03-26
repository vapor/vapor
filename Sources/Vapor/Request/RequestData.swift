import Jay

/**
    This protocol defines a type of data received.
    these variables are used to access underlying
    values
*/
public protocol Node {
    var isNull: Bool { get }
    var bool: Bool? { get }
    var float: Float? { get }
    var double: Double? { get }
    var int: Int? { get }
    var uint: UInt? { get }
    var string: String? { get }
    var array: [Node]? { get }
    var object: [String : Node]? { get }
}

public enum NodeError: ErrorProtocol {
    
    /**
     When converting to a value from Json, if there is a type conflict, this will throw an error
     
     - param Json   the json that was unable to map
     - param String a string description of the type that was attempting to map
     */
    case UnableToConvert(node: Node, toType: String)
}

public extension Request {
    
    /**
        The data received from the request in json body or url query
    */
    public struct Data {
        // MARK: Initialization
        public let query: [String : String]
        public let json: Json?
        
        internal init(query: [String : String] = [:], bytes: [UInt8]) {
            var mutableQuery = query
            
            do {
                self.json = try Json.deserialize(bytes)
            } catch {
                self.json = nil
                
                // Will overwrite keys if they are duplicated from `query`
                Data.parsePostData(bytes).forEach { key, val in
                    mutableQuery[key] = val
                }
            }
            
            self.query = mutableQuery
        }
        
        // MARK: Subscripting
        public subscript(key: String) -> Node? {
            return query[key] ?? json?.object?[key]
        }
        
        public subscript(idx: Int) -> Node? {
            return json?.array?[idx]
        }
        
        /**
            Checks for form encoding of body if Json fails

            - parameter body: byte array from body

            - returns: a key value pair dictionary
        */
        static func parsePostData(body: [UInt8]) -> [String: String] {
            if let bodyString = String(pointer: body, length: body.count) {
                return bodyString.keyValuePairs()
            }
            
            return [:]
        }
    }
}

extension JsonNumber {
    public var number: Double {
        switch self {
        case .JsonInt(let int):
            return Double(int)
        case .JsonDbl(let dbl):
            return dbl
        }
    }
}

extension Json: Node {
    public var isNull: Bool {
        switch self {
        case .Null:
            return true
        default:
            return false
        }
    }
    
    public var bool: Bool? {
        switch  self {
        case .Boolean(let bool):
            return bool == .True
        case .Number(let number):
            return number.number > 0
        case .String(let string):
            return Bool(string)
        case .Object(_), .Array(_), .Null:
            return false
        }
    }
    
    public var int: Int? {
        guard let double = double else { return nil }
        return Int(double)
    }
    
    public var uint: UInt? {
        guard let double = double else { return nil }
        return UInt(double)
    }
    
    public var float: Float? {
        guard let double = double else { return nil }
        return Float(double)
    }
    
    public var double: Double? {
        switch self {
        case .Boolean(let bool):
            return bool == .True ? 1 : 0
        case .Number(let number):
            return number.number
        case .String(let string):
            return Double(string)
        case .Null:
            return 0
        case .Object(_), .Array(_):
            return nil
        }
    }
    
    public var string: Swift.String? {
        switch self {
        case .String(let string):
            return string
        case .Boolean(let bool):
            return Swift.String(bool)
        case .Number(let number):
            return number.number.description
        case .Null:
            return "null"
        case .Array(let array):
            let flat = array
                .flatMap { js in
                    return js.string
                }
            #if swift(>=3.0)
                return flat.joined(separator: ",")
            #else
                return flat.joinWithSeparator(",")
            #endif
        case .Object(_):
            return nil
        }
    }
    
    public var array: [Node]? {
        guard case let .Array(array) = self else { return nil }
        return array.map { $0 as Node }
    }
    
    public var object: [Swift.String : Node]? {
        guard case let .Object(object) = self else { return nil }
        var mapped: [Swift.String : Node] = [:]
        object.forEach { key, val in
            mapped[key] = val as Node
        }
        return mapped
    }
}

extension String: Node {
    public var isNull: Bool {
        return self == "null"
    }
    
    public var bool: Bool? {
        return Bool(self)
    }
    
    public var int: Int? {
        guard let double = double else { return nil }
        return Int(double)
    }
    
    public var uint: UInt? {
        guard let double = double else { return nil }
        return UInt(double)
    }
    
    public var float: Float? {
        guard let double = double else { return nil }
        return Float(double)
    }
    
    public var double: Double? {
        return Double(self)
    }
    
    public var string: String? {
        return self
    }
    
    public var array: [Node]? {
        return self
            .split(",")
            .map { $0 as Node }
    }
    
    public var object: [String : Node]? {
        return nil
    }
}

extension Bool {
    /**
        This function seeks to replicate the expected behavior of `var boolValue: Bool` on `NSString`.  Any variant of `yes`, `y`, `true`, `t`, or any numerical value greater than 0 will be considered `true`
    */
    public init(_ string: String) {
        let cleaned = string
            .lowercased()
            .characters
            .first ?? "n"
        
        switch cleaned {
        case "t", "y", "1":
            self = true
        default:
            if let int = Int(String(cleaned)) where int > 0 {
                self = true
            } else {
                self = false
            }
            
        }
    }
}
