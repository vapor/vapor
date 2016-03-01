//
//  Vapor+Json.swift
//  Vapor
//
//  Created by Logan Wright on 2/19/16.
//  Copyright © 2016 Tanner Nelson. All rights reserved.
//

import Foundation

// MARK: Response

extension Json: ResponseConvertible {
    public func response() -> Response {
        do {
            let data = try serialize()
            return Response(status: .OK, data: data, contentType: .Json)
        } catch {
            //return error!
            let errorString = "\(error)"
            //TODO: which response? 500? 400? should we be leaking the error?
            return Response(error: errorString)
        }
    }
}

// MARK: Request Json

extension Request {

    /**
     If the body can be serialized as Json, the value will be returned here
     */
    public var json: Json? {
        return try? Json.deserialize(body)
    }
}

// MARK: Json Convertible 

public enum JsonError: ErrorType {
    
    /**
     *  When converting to a value from Json, if there is a type conflict, this will throw an error
     *
     *  @param Json   the json that was unable to map
     *  @param String a string description of the type that was attempting to map
     */
    case UnableToConvert(json: Json, toType: String)
}

/**
 *  An umbrella protocol used to define behavior to and from Json
 */
public protocol JsonConvertible {
    
    /**
     This function will be used to create an instance of the type from Json
     
     - parameter json: the json to use in initialization
     
     - throws: a potential error.  ie: invalid json type
     
     - returns: an initialized object
     */
    static func newInstance(json: Json) throws -> Self
    
    /**
     Used to convert the object back to its Json representation
     
     - throws: a potential conversion error
     
     - returns: the object as a Json representation
     */
    func jsonRepresentation() throws -> Json
}

// MARK: Json Convertible Initializers

extension Json {
    
    /**
     Create Json from any convertible type
     
     - parameter any: the convertible type
     
     - throws: a potential conversion error
     
     - returns: initialized Json
     */
    public init<T: JsonConvertible>(_ any: T) throws {
        self = try any.jsonRepresentation()
    }
    
    public init<T: JsonConvertible>(_ any: [T]) throws {
        let mapped = try any.map(Json.init)
        self.init(mapped)
    }
    
    public init<T: JsonConvertible>(_ any: [[T]]) throws {
        let mapped = try any.map(Json.init)
        self.init(mapped)
    }
    
    public init<T: JsonConvertible>(_ any: Set<T>) throws {
        let mapped = try any.map(Json.init)
        self.init(mapped)
    }
    
    public init<T: JsonConvertible>(_ any: [String : T]) throws {
        var mapped: [String : Json] = [:]
        try any.forEach { key, val in
            mapped[key] = try Json(val)
        }
        self.init(mapped)
    }
    
    public init<T: JsonConvertible>(_ any: [String : [T]]) throws {
        var mapped: [String : Json] = [:]
        try any.forEach { key, val in
            mapped[key] = try Json(val)
        }
        self.init(mapped)
    }
    
    public init<T: JsonConvertible>(_ any: [String : [String : T]]) throws {
        var mapped: [String : Json] = [:]
        try any.forEach { key, val in
            mapped[key] = try Json(val)
        }
        self.init(mapped)
    }
}

extension Json : JsonConvertible {
    public static func newInstance(json: Json) -> Json {
        return json
    }
    
    public func jsonRepresentation() -> Json {
        return self
    }
}

// MARK: String

extension String : JsonConvertible {
    public func jsonRepresentation() throws -> Json {
        return Json(self)
    }
    
    public static func newInstance(json: Json) throws -> String {
        guard let string = json.stringValue else {
            throw JsonError.UnableToConvert(json: json, toType: "\(self.dynamicType)")
        }
        return string
    }
}

// MARK: Boolean

extension Bool : JsonConvertible {
    public func jsonRepresentation() throws -> Json {
        return Json(self)
    }
    
    public static func newInstance(json: Json) throws -> Bool {
        guard let bool = json.boolValue else {
            throw JsonError.UnableToConvert(json: json, toType: "\(self.dynamicType)")
        }
        return bool
    }
}


// MARK: UnsignedIntegerType

extension UInt : JsonConvertible {}
extension UInt8 : JsonConvertible {}
extension UInt16 : JsonConvertible {}
extension UInt32 : JsonConvertible {}
extension UInt64 : JsonConvertible {}

extension UnsignedIntegerType {
    public func jsonRepresentation() throws -> Json {
        let double = Double(UIntMax(self.toUIntMax()))
        return .from(double)
    }
    
    public static func newInstance(json: Json) throws -> Self {
        guard let int = json.uintValue else {
            throw JsonError.UnableToConvert(json: json, toType: "\(self.dynamicType)")
        }
        
        return self.init(int.toUIntMax())
    }
}

// MARK: SignedIntegerType

extension Int : JsonConvertible {}
extension Int8 : JsonConvertible {}
extension Int16 : JsonConvertible {}
extension Int32 : JsonConvertible {}
extension Int64 : JsonConvertible {}

extension SignedIntegerType {
    public func jsonRepresentation() throws -> Json {
        let double = Double(IntMax(self.toIntMax()))
        return .from(double)
    }
    
    public static func newInstance(json: Json) throws -> Self {
        guard let int = json.intValue else {
            throw JsonError.UnableToConvert(json: json, toType: "\(self.dynamicType)")
        }
        
        return self.init(int.toIntMax())
    }
}


// MARK: FloatingPointType

extension Float : JsonConvertibleFloatingPointType {
    public var doubleValue: Double {
        return Double(self)
    }
}

extension Double : JsonConvertibleFloatingPointType {
    public var doubleValue: Double {
        return Double(self)
    }
}

public protocol JsonConvertibleFloatingPointType : JsonConvertible {
    var doubleValue: Double { get }
    init(_ other: Double)
}

extension JsonConvertibleFloatingPointType {
    public func jsonRepresentation() throws -> Json {
        return .from(doubleValue)
    }
    
    public static func newInstance(json: Json) throws -> Self {
        guard let double = json.doubleValue else {
            throw JsonError.UnableToConvert(json: json, toType: "\(self.dynamicType)")
        }
        return self.init(double)
    }
}
