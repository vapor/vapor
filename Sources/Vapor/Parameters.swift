import HTTP
import Routing

extension String: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-string"
    }
    
    /// Reads the raw parameter
    public static func make(for parameter: String, in request: Request) throws -> String {
        return parameter
    }
}

extension Int: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-int"
    }
    
    /// Attempts to read the parameter into a `Int`
    public static func make(for parameter: String, in request: Request) throws -> Int {
        guard let number = Int(parameter) else {
            throw Error(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an Int")
        }
        
        return number
    }
}

extension Double: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-double"
    }
    
    /// Attempts to read the parameter into a `Double`
    public static func make(for parameter: String, in request: Request) throws -> Double {
        guard let number = Double(parameter) else {
            throw Error(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to a Double")
        }
        
        return number
    }
}

extension Int8: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-int8"
    }
    
    /// Attempts to read the parameter into a `Int8`
    public static func make(for parameter: String, in request: Request) throws -> Int8 {
        guard let number = Int8(parameter) else {
            throw Error(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an Int8")
        }
        
        return number
    }
}

extension Int16: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-int16"
    }
    
    /// Attempts to read the parameter into a `Int16`
    public static func make(for parameter: String, in request: Request) throws -> Int16 {
        guard let number = Int16(parameter) else {
            throw Error(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an Int16")
        }
        
        return number
    }
}

extension Int32: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-int32"
    }
    
    /// Attempts to read the parameter into a `Int32`
    public static func make(for parameter: String, in request: Request) throws -> Int32 {
        guard let number = Int32(parameter) else {
            throw Error(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an Int32")
        }
        
        return number
    }
}

extension Int64: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-int64"
    }
    
    /// Attempts to read the parameter into a `Int64`
    public static func make(for parameter: String, in request: Request) throws -> Int64 {
        guard let number = Int64(parameter) else {
            throw Error(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an Int64")
        }
        
        return number
    }
}

extension UInt8: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-uint8"
    }
    
    /// Attempts to read the parameter into a `UInt8`
    public static func make(for parameter: String, in request: Request) throws -> UInt8 {
        guard let number = UInt8(parameter) else {
            throw Error(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an UInt8")
        }
        
        return number
    }
}

extension UInt16: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-uint16"
    }
    
    /// Attempts to read the parameter into a `UInt16`
    public static func make(for parameter: String, in request: Request) throws -> UInt16 {
        guard let number = UInt16(parameter) else {
            throw Error(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an UInt16")
        }
        
        return number
    }
}

extension UInt32: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-uint32"
    }
    
    /// Attempts to read the parameter into a `UInt32`
    public static func make(for parameter: String, in request: Request) throws -> UInt32 {
        guard let number = UInt32(parameter) else {
            throw Error(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an UInt32")
        }
        
        return number
    }
}

extension UInt64: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-uint64"
    }
    
    /// Attempts to read the parameter into a `UInt64`
    public static func make(for parameter: String, in request: Request) throws -> UInt64 {
        guard let number = UInt64(parameter) else {
            throw Error(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an UInt64")
        }
        
        return number
    }
}
