import C7

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
                self.json = try Json(bytes)
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
        
        public subscript(index: Int) -> Node? {
            return json?.array?[index]
        }
        
        /**
            Checks for form encoding of body if Json fails

            - parameter body: byte array from body

            - returns: a key value pair dictionary
        */
        static func parsePostData(body: [UInt8]) -> [String: String] {
            if let bodyString = String(data: body) {
                return bodyString.keyValuePairs()
            }
            
            return [:]
        }
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
    
    public var json: Json? {
        return Json(self)
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
