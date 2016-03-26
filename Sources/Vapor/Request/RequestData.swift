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
            //FIXME
            //return query[key] ?? json?.object?[key]
            return nil
        }
        
        public subscript(idx: Int) -> Node? {
            return nil
            //return json?.array?[idx]
            //FIXME
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

//extension JsonNumber {
//    public var number: Double {
//        switch self {
//        case .JsonInt(let int):
//            return Double(int)
//        case .JsonDbl(let dbl):
//            return dbl
//        }
//    }
//}



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
