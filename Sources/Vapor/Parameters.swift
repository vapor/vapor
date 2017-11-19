import Async
import HTTP
import Routing

extension String: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-string"
    }
    
    /// Reads the raw parameter
    public static func make(for parameter: String, in request: Request) throws -> Future<String> {
        return Future(parameter)
    }
}

extension Int: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-int"
    }
    
    /// Attempts to read the parameter into a `Int`
    public static func make(for parameter: String, in request: Request) throws -> Future<Int> {
        guard let number = Int(parameter) else {
            throw VaporError(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an Int")
        }
        
        return Future(number)
    }
}

extension Double: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-double"
    }
    
    /// Attempts to read the parameter into a `Double`
    public static func make(for parameter: String, in request: Request) throws -> Future<Double> {
        guard let number = Double(parameter) else {
            throw VaporError(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to a Double")
        }
        
        return Future(number)
    }
}

extension Int8: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-int8"
    }
    
    /// Attempts to read the parameter into a `Int8`
    public static func make(for parameter: String, in request: Request) throws -> Future<Int8> {
        guard let number = Int8(parameter) else {
            throw VaporError(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an Int8")
        }
        
        return Future(number)
    }
}

extension Int16: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-int16"
    }
    
    /// Attempts to read the parameter into a `Int16`
    public static func make(for parameter: String, in request: Request) throws -> Future<Int16> {
        guard let number = Int16(parameter) else {
            throw VaporError(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an Int16")
        }
        
        return Future(number)
    }
}

extension Int32: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-int32"
    }
    
    /// Attempts to read the parameter into a `Int32`
    public static func make(for parameter: String, in request: Request) throws -> Future<Int32> {
        guard let number = Int32(parameter) else {
            throw VaporError(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an Int32")
        }
        
        return Future(number)
    }
}

extension Int64: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-int64"
    }
    
    /// Attempts to read the parameter into a `Int64`
    public static func make(for parameter: String, in request: Request) throws -> Future<Int64> {
        guard let number = Int64(parameter) else {
            throw VaporError(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an Int64")
        }
        
        return Future(number)
    }
}

extension UInt8: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-uint8"
    }
    
    /// Attempts to read the parameter into a `UInt8`
    public static func make(for parameter: String, in request: Request) throws -> Future<UInt8> {
        guard let number = UInt8(parameter) else {
            throw VaporError(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an UInt8")
        }
        
        return Future(number)
    }
}

extension UInt16: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-uint16"
    }
    
    /// Attempts to read the parameter into a `UInt16`
    public static func make(for parameter: String, in request: Request) throws -> Future<UInt16> {
        guard let number = UInt16(parameter) else {
            throw VaporError(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an UInt16")
        }
        
        return Future(number)
    }
}

extension UInt32: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-uint32"
    }
    
    /// Attempts to read the parameter into a `UInt32`
    public static func make(for parameter: String, in request: Request) throws -> Future<UInt32> {
        guard let number = UInt32(parameter) else {
            throw VaporError(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an UInt32")
        }
        
        return Future(number)
    }
}

extension UInt64: Parameter {
    /// See `Parameter.uniqueSlug`
    public static var uniqueSlug: String {
        return "swift-uint64"
    }
    
    /// Attempts to read the parameter into a `UInt64`
    public static func make(for parameter: String, in request: Request) throws -> Future<UInt64> {
        guard let number = UInt64(parameter) else {
            throw VaporError(identifier: "parameterNotAnInt", reason: "The parameter was not convertible to an UInt64")
        }
        
        return Future(number)
    }
}
