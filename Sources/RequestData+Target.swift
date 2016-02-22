//
//  RequestData+Target.swift
//  Vapor
//
//  Created by Logan Wright on 2/21/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import PureJsonSerializer

extension Request {
    public struct Data {
        public protocol Node {
            public var isNull: Bool { get }
            public var boolValue: Bool? { get }
            public var floatValue: Float? { get }
            public var doubleValue: Double? { get }
            public var intValue: Int? { get }
            public var uintValue: UInt? { get }
            public var stringValue: String? { get }
            public var arrayValue: [Node]? { get }
            public var objectValue: [String : Node]? { get }
        }
        
        // MARK: Initialization
        
        public let query: [String : String]
        public let json: Json?
        
        internal init(query: [String : String] = [:], bytes: [UInt8]) {
            self.query = query
            self.json = try? Json.deserialize(bytes)
        }
        
        // MARK: Subscripting

        public subscript(key: String) -> Node? {
            return query[key] ?? json?[key]
        }
        
        public subscript(idx: Int) -> Node? {
            return json?[idx]
        }
    }
}

extension Json : Request.Data.Node {
    public var isNull: Bool {
        switch self {
        case .NullValue:
            return true
        case .StringValue(let string) where string == "null":
            return true
        default:
            return false
        }
    }
    
    public var bool: Bool {
        switch  self {
        case .BooleanValue(let bool):
            return bool
        case .NumberValue(let number):
            return Int(number) > 0
        case .StringValue(let string):
            return Bool(string)
        case .ObjectValue(_), .ArrayValue(_), .NullValue:
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
        case .BooleanValue(let bool):
            return bool ? 1 : 0
        case .NumberValue(let number):
            return Double(number)
        case .StringValue(let string):
            return Double(string)
        case .NullValue:
            return 0
        case .ObjectValue(_), .ArrayValue(_):
            return nil
        }
    }
    
    public var string: String? {
        switch self {
        case .StringValue(let string):
            return string
        case .BooleanValue(let bool):
            return String(bool)
        case .NumberValue(let number):
            return String(number)
        case .NullValue:
            return "null"
        case .ArrayValue(let array):
            return array
                .flatMap { js in
                    return Node(js).string
                }
                .joinWithSeparator(",")
        case .ObjectValue(_):
            return nil
        }
    }
    
    public var array: [Node]? {
        guard case let .ArrayValue(array) = self else { return nil }
        return array
    }
    
    public var object: [String : Node]? {
        guard case let .ObjectValue(object) = self else { return nil }
        return object
    }
}

extension String : Request.Data.Node {
    public var isNull: Bool {
        return self == "null"
    }
    
    public var bool: Bool {
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
        return self.componentsSeparatedByString(",")
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
            .lowercaseString
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
