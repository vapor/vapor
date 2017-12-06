public protocol DecoderHelper : Decoder {
    associatedtype Value
    associatedtype Keyed
    associatedtype Unkeyed
    
    var either: Either<Value, Keyed, Unkeyed> { get }
    
    var lossyIntegers: Bool { get }
    var lossyStrings: Bool { get }
    
    func decode(_ wrapped: Value) throws -> String
    func decode(_ wrapped: Value) throws -> Bool
    func decode(_ wrapped: Value) throws -> Int8
    func decode(_ wrapped: Value) throws -> Int16
    func decode(_ wrapped: Value) throws -> Int32
    func decode(_ wrapped: Value) throws -> Int64
    func decode(_ wrapped: Value) throws -> Int
    func decode(_ wrapped: Value) throws -> UInt8
    func decode(_ wrapped: Value) throws -> UInt16
    func decode(_ wrapped: Value) throws -> UInt32
    func decode(_ wrapped: Value) throws -> UInt64
    func decode(_ wrapped: Value) throws -> UInt
    func decode(_ wrapped: Value) throws -> Double
    func decode(_ wrapped: Value) throws -> Float
    func decode<D: Decodable>(_ type: D.Type, from wrapped: Value) throws -> D
    
    func integers(for value: Value) throws -> Integers?
    
    init(keyed: Keyed, lossyIntegers: Bool, lossyStrings: Bool) throws
    init(value: Value, lossyIntegers: Bool, lossyStrings: Bool) throws
    init(unkeyed: Unkeyed, lossyIntegers: Bool, lossyStrings: Bool) throws
    init(any: Value, lossyIntegers: Bool, lossyStrings: Bool) throws
}

public enum Either<Value, Keyed, Unkeyed> {
    case keyed(Keyed)
    case unkeyed(Unkeyed)
    case value(Value)
    
    public func getValue() throws -> Value {
        guard case .value(let value) = self else {
            throw DecodingError.invalidContext
        }
        
        return value
    }
    
    public func getKeyed() throws -> Keyed {
        guard case .keyed(let keyed) = self else {
            throw DecodingError.invalidContext
        }
        
        return keyed
    }
}

public enum Integers {
    case uint(UInt)
    case int(Int)
    case uint64(UInt64)
    case int64(Int64)
    case uint32(UInt32)
    case int32(Int32)
    case uint16(UInt16)
    case int16(Int16)
    case uint8(UInt8)
    case int8(Int8)
    case double(Double)
    case float(Float)
    
    fileprivate var signedNumber: Int64? {
        switch self {
        case .int(let s): return numericCast(s)
        case .int8(let s): return numericCast(s)
        case .int16(let s): return numericCast(s)
        case .int32(let s): return numericCast(s)
        case .int64(let s): return numericCast(s)
        default: return nil
        }
    }
    
    fileprivate var unsignedNumber: UInt64? {
        switch self {
        case .uint(let u): return numericCast(u)
        case .uint8(let u): return numericCast(u)
        case .uint16(let u): return numericCast(u)
        case .uint32(let u): return numericCast(u)
        case .uint64(let u): return numericCast(u)
        default: return nil
        }
    }
}

extension DecoderHelper {
    public func decode(_ wrapped: Value) throws -> Int8 {
        if let integers = try integers(for: wrapped) {
            if lossyIntegers {
                return try decodeLossy(integers)
            } else {
                guard case .int8(let int) = integers else {
                    throw DecodingError.incorrectValue
                }
                
                return int
            }
        }
        
        throw DecodingError.unimplemented
    }
    
    public func decode(_ wrapped: Value) throws -> Int16 {
        if let integers = try integers(for: wrapped) {
            if lossyIntegers {
                return try decodeLossy(integers)
            } else {
                guard case .int16(let int) = integers else {
                    throw DecodingError.incorrectValue
                }
                
                return int
            }
        }
        
        throw DecodingError.unimplemented
    }
    public func decode(_ wrapped: Value) throws -> Int32 {
        if let integers = try integers(for: wrapped) {
            if lossyIntegers {
                return try decodeLossy(integers)
            } else {
                guard case .int32(let int) = integers else {
                    throw DecodingError.incorrectValue
                }
                
                return int
            }
        }
        
        throw DecodingError.unimplemented
    }
    public func decode(_ wrapped: Value) throws -> Int64 {
        if let integers = try integers(for: wrapped) {
            if lossyIntegers {
                return try decodeLossy(integers)
            } else {
                guard case .int64(let int) = integers else {
                    throw DecodingError.incorrectValue
                }
                
                return int
            }
        }
        
        throw DecodingError.unimplemented
    }
    public func decode(_ wrapped: Value) throws -> Int {
        if let integers = try integers(for: wrapped) {
            if lossyIntegers {
                return try decodeLossy(integers)
            } else {
                guard case .int(let int) = integers else {
                    throw DecodingError.incorrectValue
                }
                
                return int
            }
        }
        
        throw DecodingError.unimplemented
    }
    public func decode(_ wrapped: Value) throws -> UInt8 {
        if let integers = try integers(for: wrapped) {
            if lossyIntegers {
                return try decodeLossy(integers)
            } else {
                guard case .uint8(let int) = integers else {
                    throw DecodingError.incorrectValue
                }
                
                return int
            }
        }
        
        throw DecodingError.unimplemented
    }
    public func decode(_ wrapped: Value) throws -> UInt16 {
        if let integers = try integers(for: wrapped) {
            if lossyIntegers {
                return try decodeLossy(integers)
            } else {
                guard case .uint16(let int) = integers else {
                    throw DecodingError.incorrectValue
                }
                
                return int
            }
        }
        
        throw DecodingError.unimplemented
    }
    public func decode(_ wrapped: Value) throws -> UInt32 {
        if let integers = try integers(for: wrapped) {
            if lossyIntegers {
                return try decodeLossy(integers)
            } else {
                guard case .uint32(let int) = integers else {
                    throw DecodingError.incorrectValue
                }
                
                return int
            }
        }
        
        throw DecodingError.unimplemented
    }
    public func decode(_ wrapped: Value) throws -> UInt64 {
        if let integers = try integers(for: wrapped) {
            if lossyIntegers {
                return try decodeLossy(integers)
            } else {
                guard case .uint64(let int) = integers else {
                    throw DecodingError.incorrectValue
                }
                
                return int
            }
        }
        
        throw DecodingError.unimplemented
    }
    public func decode(_ wrapped: Value) throws -> UInt {
        if let integers = try integers(for: wrapped) {
            if lossyIntegers {
                return try decodeLossy(integers)
            } else {
                guard case .uint(let int) = integers else {
                    throw DecodingError.incorrectValue
                }
                
                return int
            }
        }
        
        throw DecodingError.unimplemented
    }
    public func decode(_ wrapped: Value) throws -> Double {
        if let integers = try integers(for: wrapped) {
            if lossyIntegers {
                return try decodeLossy(integers)
            } else {
                guard case .double(let double) = integers else {
                    throw DecodingError.incorrectValue
                }
                
                return double
            }
        }
        
        throw DecodingError.unimplemented
    }
    public func decode(_ wrapped: Value) throws -> Float {
        if let integers = try integers(for: wrapped) {
            if lossyIntegers {
                return try decodeLossy(integers)
            } else {
                guard case .float(let float) = integers else {
                    throw DecodingError.incorrectValue
                }
                
                return float
            }
        }
        
        throw DecodingError.unimplemented
    }
    
    // MARK - Integer unwrap helper
    
    func unwrap(_ wrapped: Value) throws -> Int8 {
        if lossyIntegers, let integers = try integers(for: wrapped) {
            return try decodeLossy(integers)
        }
        
        return try self.decode(wrapped)
    }
    
    func unwrap(_ wrapped: Value) throws -> Int16 {
        if lossyIntegers, let integers = try integers(for: wrapped) {
            return try decodeLossy(integers)
        }
        
        return try self.decode(wrapped)
    }
    
    func unwrap(_ wrapped: Value) throws -> Int32 {
        if lossyIntegers, let integers = try integers(for: wrapped) {
            return try decodeLossy(integers)
        }
        
        return try self.decode(wrapped)
    }
    
    func unwrap(_ wrapped: Value) throws -> Int64 {
        if lossyIntegers, let integers = try integers(for: wrapped) {
            return try decodeLossy(integers)
        }
        
        return try self.decode(wrapped)
    }
    
    func unwrap(_ wrapped: Value) throws -> Int {
        if lossyIntegers, let integers = try integers(for: wrapped) {
            return try decodeLossy(integers)
        }
        
        return try self.decode(wrapped)
    }
    
    func unwrap(_ wrapped: Value) throws -> UInt8 {
        if lossyIntegers, let integers = try integers(for: wrapped) {
            return try decodeLossy(integers)
        }
        
        return try self.decode(wrapped)
    }
    
    func unwrap(_ wrapped: Value) throws -> UInt16 {
        if lossyIntegers, let integers = try integers(for: wrapped) {
            return try decodeLossy(integers)
        }
        
        return try self.decode(wrapped)
    }
    
    func unwrap(_ wrapped: Value) throws -> UInt32 {
        if lossyIntegers, let integers = try integers(for: wrapped) {
            return try decodeLossy(integers)
        }
        
        return try self.decode(wrapped)
    }
    
    func unwrap(_ wrapped: Value) throws -> UInt64 {
        if lossyIntegers, let integers = try integers(for: wrapped) {
            return try decodeLossy(integers)
        }
        
        return try self.decode(wrapped)
    }
    
    func unwrap(_ wrapped: Value) throws -> UInt {
        if lossyIntegers, let integers = try integers(for: wrapped) {
            return try decodeLossy(integers)
        }
        
        return try self.decode(wrapped)
    }
    
    func unwrap(_ wrapped: Value) throws -> Float {
        if lossyIntegers, let integers = try integers(for: wrapped) {
            return try decodeLossy(integers)
        }
        
        return try self.decode(wrapped)
    }
    
    func unwrap(_ wrapped: Value) throws -> Double {
        if lossyIntegers, let integers = try integers(for: wrapped) {
            return try decodeLossy(integers)
        }
        
        return try self.decode(wrapped)
    }
    
    // MARK - Lossy integer decoder
    
    public func decodeLossy(_ wrapped: Integers) throws -> Int8 {
        if let num = wrapped.signedNumber {
            guard num <= numericCast(Int8.max), num >= numericCast(Int8.min) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else if let num = wrapped.unsignedNumber {
            guard num <= numericCast(Int8.max) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else {
            throw DecodingError.failedLossyIntegerConversion
        }
    }
    
    public func decodeLossy(_ wrapped: Integers) throws -> Int16 {
        if let num = wrapped.signedNumber {
            guard num <= numericCast(Int16.max), num >= numericCast(Int16.min) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else if let num = wrapped.unsignedNumber {
            guard num <= numericCast(Int16.max) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else {
            throw DecodingError.failedLossyIntegerConversion
        }
    }
    
    public func decodeLossy(_ wrapped: Integers) throws -> Int32 {
        if let num = wrapped.signedNumber {
            guard num <= numericCast(Int32.max), num >= numericCast(Int32.min) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else if let num = wrapped.unsignedNumber {
            guard num <= numericCast(Int32.max) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else {
            throw DecodingError.failedLossyIntegerConversion
        }
    }
    
    public func decodeLossy(_ wrapped: Integers) throws -> Int64 {
        if let num = wrapped.signedNumber {
            guard num <= numericCast(Int64.max), num >= numericCast(Int64.min) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else if let num = wrapped.unsignedNumber {
            guard num <= numericCast(Int64.max) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else {
            throw DecodingError.failedLossyIntegerConversion
        }
    }
    
    public func decodeLossy(_ wrapped: Integers) throws -> Int {
        if let num = wrapped.signedNumber {
            guard num <= numericCast(Int.max), num >= numericCast(Int.min) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else if let num = wrapped.unsignedNumber {
            guard num <= numericCast(Int.max) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else {
            throw DecodingError.failedLossyIntegerConversion
        }
    }
    
    public func decodeLossy(_ wrapped: Integers) throws -> UInt8 {
        if let num = wrapped.signedNumber {
            guard num <= numericCast(UInt8.max), num >= numericCast(UInt8.min) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else if let num = wrapped.unsignedNumber {
            guard num <= numericCast(UInt8.max) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else {
            throw DecodingError.failedLossyIntegerConversion
        }
    }
    
    public func decodeLossy(_ wrapped: Integers) throws -> UInt16 {
        if let num = wrapped.signedNumber {
            guard num <= numericCast(UInt16.max), num >= numericCast(UInt16.min) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else if let num = wrapped.unsignedNumber {
            guard num <= numericCast(UInt16.max) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else {
            throw DecodingError.failedLossyIntegerConversion
        }
    }
    
    public func decodeLossy(_ wrapped: Integers) throws -> UInt32 {
        if let num = wrapped.signedNumber {
            guard num <= numericCast(UInt32.max), num >= numericCast(UInt32.min) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else if let num = wrapped.unsignedNumber {
            guard num <= numericCast(UInt32.max) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else {
            throw DecodingError.failedLossyIntegerConversion
        }
    }
    
    public func decodeLossy(_ wrapped: Integers) throws -> UInt64 {
        if let num = wrapped.signedNumber {
            guard num <= numericCast(UInt64.max), num >= numericCast(UInt64.min) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else if let num = wrapped.unsignedNumber {
            guard num <= numericCast(UInt64.max) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else {
            throw DecodingError.failedLossyIntegerConversion
        }
    }
    
    public func decodeLossy(_ wrapped: Integers) throws -> UInt {
        if let num = wrapped.signedNumber {
            guard num <= numericCast(UInt.max), num >= numericCast(UInt.min) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else if let num = wrapped.unsignedNumber {
            guard num <= numericCast(UInt.max) else {
                throw DecodingError.failedLossyIntegerConversion
            }
            
            return numericCast(num)
        } else {
            throw DecodingError.failedLossyIntegerConversion
        }
    }
    
    public func decodeLossy(_ wrapped: Integers) throws -> Double {
        if case .double(let double) = wrapped {
            return double
        } else if case .float(let float) = wrapped {
            return Double(float)
        } else {
            throw DecodingError.failedLossyIntegerConversion
        }
    }
    
    public func decodeLossy(_ wrapped: Integers) throws -> Float {
        if case .float(let float) = wrapped {
            return float
        } else if case .double(let double) = wrapped {
            return Float(double)
        } else {
            throw DecodingError.failedLossyIntegerConversion
        }
    }
}

public protocol KeyedDecodingContainerProtocolHelper : KeyedDecodingContainerProtocol {
    associatedtype D: DecoderHelper
    
    var decoder: D { get }
    
    init(decoder: D)
}

public protocol KeyedDecodingHelper {
    associatedtype Value
    
    func value(forKey key: String) throws -> Value?
}

extension KeyedDecodingContainerProtocolHelper where D.Keyed : KeyedDecodingHelper, D.Keyed.Value == D.Value {
    public func value(forKey key: Key) throws -> D.Value? {
        return try decoder.either.getKeyed().value(forKey: key.stringValue)
    }

    public func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        guard let value = try decoder.either.getKeyed().value(forKey: key.stringValue) else {
            throw DecodingError.incorrectValue
        }
        
        return try decoder.unwrap(value)
    }

    public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        guard let value = try decoder.either.getKeyed().value(forKey: key.stringValue) else {
            throw DecodingError.incorrectValue
        }
        
        return try decoder.unwrap(value)
    }

    public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        guard let value = try decoder.either.getKeyed().value(forKey: key.stringValue) else {
            throw DecodingError.incorrectValue
        }
        
        return try decoder.unwrap(value)
    }

    public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        guard let value = try decoder.either.getKeyed().value(forKey: key.stringValue) else {
            throw DecodingError.incorrectValue
        }
        
        return try decoder.unwrap(value)
    }

    public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        guard let value = try decoder.either.getKeyed().value(forKey: key.stringValue) else {
            throw DecodingError.incorrectValue
        }
        
        return try decoder.unwrap(value)
    }

    public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        guard let value = try decoder.either.getKeyed().value(forKey: key.stringValue) else {
            throw DecodingError.incorrectValue
        }
        
        return try decoder.unwrap(value)
    }

    public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        guard let value = try decoder.either.getKeyed().value(forKey: key.stringValue) else {
            throw DecodingError.incorrectValue
        }
        
        return try decoder.unwrap(value)
    }

    public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        guard let value = try decoder.either.getKeyed().value(forKey: key.stringValue) else {
            throw DecodingError.incorrectValue
        }
        
        return try decoder.unwrap(value)
    }

    public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        guard let value = try decoder.either.getKeyed().value(forKey: key.stringValue) else {
            throw DecodingError.incorrectValue
        }
        
        return try decoder.unwrap(value)
    }

    public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        guard let value = try decoder.either.getKeyed().value(forKey: key.stringValue) else {
            throw DecodingError.incorrectValue
        }
        
        return try decoder.unwrap(value)
    }

    public func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        guard let value = try decoder.either.getKeyed().value(forKey: key.stringValue) else {
            throw DecodingError.incorrectValue
        }
        
        return try decoder.unwrap(value)
    }

    public func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        guard let value = try decoder.either.getKeyed().value(forKey: key.stringValue) else {
            throw DecodingError.incorrectValue
        }
        
        return try decoder.unwrap(value)
    }

    public func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
        guard let value = try decoder.either.getKeyed().value(forKey: key.stringValue) else {
            throw DecodingError.incorrectValue
        }
        
        return try decoder.decode(T.self, from: value)
    }

    public func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        guard let keyed = try decoder.either.getKeyed().value(forKey: key.stringValue) as? D.Keyed else {
            throw DecodingError.incorrectValue
        }
        
        return try D(keyed: keyed, lossyIntegers: decoder.lossyIntegers, lossyStrings: decoder.lossyStrings).container(keyedBy: type)
    }

    public func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        guard let unkeyed = try decoder.either.getKeyed().value(forKey: key.stringValue) as? D.Unkeyed else {
            throw DecodingError.incorrectValue
        }
        
        return try D(unkeyed: unkeyed, lossyIntegers: decoder.lossyIntegers, lossyStrings: decoder.lossyStrings).unkeyedContainer()
    }

    public func superDecoder() throws -> Decoder {
        guard let value = try decoder.either.getKeyed().value(forKey: "super") else {
            throw DecodingError.incorrectValue
        }
        
        return try D(any: value, lossyIntegers: decoder.lossyIntegers, lossyStrings: decoder.lossyStrings)
    }

    public func superDecoder(forKey key: Key) throws -> Decoder {
        guard let keyed = try decoder.either.getKeyed().value(forKey: key.stringValue) as? D.Keyed else {
            throw DecodingError.incorrectValue
        }
        
        return try D(keyed: keyed, lossyIntegers: decoder.lossyIntegers, lossyStrings: decoder.lossyStrings)
    }
}

public protocol SingleValueDecodingContainerHelper : SingleValueDecodingContainer {
    associatedtype D: DecoderHelper
    
    var decoder: D { get }
    
    init(decoder: D)
}

extension SingleValueDecodingContainerHelper {
    public func decode(_ type: Int.Type) throws -> Int {
        return try decoder.unwrap(try decoder.either.getValue())
    }
    
    public func decode(_ type: Int8.Type) throws -> Int8 {
        return try decoder.unwrap(try decoder.either.getValue())
    }
    
    public func decode(_ type: Int16.Type) throws -> Int16 {
        return try decoder.unwrap(try decoder.either.getValue())
    }
    
    public func decode(_ type: Int32.Type) throws -> Int32 {
        return try decoder.unwrap(try decoder.either.getValue())
    }
    
    public func decode(_ type: Int64.Type) throws -> Int64 {
        return try decoder.unwrap(try decoder.either.getValue())
    }
    
    public func decode(_ type: UInt.Type) throws -> UInt {
        return try decoder.unwrap(try decoder.either.getValue())
    }
    
    public func decode(_ type: UInt8.Type) throws -> UInt8 {
        return try decoder.unwrap(try decoder.either.getValue())
    }
    
    public func decode(_ type: UInt16.Type) throws -> UInt16 {
        return try decoder.unwrap(try decoder.either.getValue())
    }
    
    public func decode(_ type: UInt32.Type) throws -> UInt32 {
        return try decoder.unwrap(try decoder.either.getValue())
    }
    
    public func decode(_ type: UInt64.Type) throws -> UInt64 {
        return try decoder.unwrap(try decoder.either.getValue())
    }
    
    public func decode(_ type: Float.Type) throws -> Float {
        return try decoder.unwrap(try decoder.either.getValue())
    }
    
    public func decode(_ type: Double.Type) throws -> Double {
        return try decoder.unwrap(try decoder.either.getValue())
    }
    
    public func decode(_ type: Bool.Type) throws -> Bool {
        return try decoder.decode(try decoder.either.getValue())
    }
}

public enum DecodingError : Error {
    case failedLossyIntegerConversion, invalidContext, incorrectValue, unimplemented
}

