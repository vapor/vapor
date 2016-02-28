//
//  RequestData+Target.swift
//  Vapor
//
//  Created by Logan Wright on 2/21/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

/**
 *  This protocol defines a type of data received.
 *  these variables are used to access underlying
 *  values
 */
public protocol Node {
    var isNull: Bool { get }
    var bool: Bool { get }
    var float: Float? { get }
    var double: Double? { get }
    var int: Int? { get }
    var uint: UInt? { get }
    var string: String? { get }
    var array: [Node]? { get }
    var object: [String : Node]? { get }
}

public extension Request {
    
    /**
     *  The data received from the request in json body or url query
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
            return query[key] ?? json?[key]
        }
        
        public subscript(idx: Int) -> Node? {
            return json?[idx]
        }
        
        /**
         Checks for form encoding of body if Json fails
         
         - parameter body: byte array from body
         
         - returns: a key value pair dictionary
         */
        static func parsePostData(body: [UInt8]) -> [String: String] {
            if let bodyString = NSString(bytes: body, length: body.count, encoding: NSUTF8StringEncoding) {
                return bodyString.description.keyValuePairs()
            }
            
            return [:]
        }
    }
}

extension Json: Node {
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
                    return js.string
                }
                .joinWithSeparator(",")
        case .ObjectValue(_):
            return nil
        }
    }
    
    public var array: [Node]? {
        guard case let .ArrayValue(array) = self else { return nil }
        return array.map { $0 as Node }
    }
    
    public var object: [String : Node]? {
        guard case let .ObjectValue(object) = self else { return nil }
        var mapped: [String : Node] = [:]
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
        return self
            .componentsSeparatedByString(",")
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
