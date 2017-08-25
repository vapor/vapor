import Foundation

/// An extension that implements deserialization from a Row's columns in binary to a concrete type
extension Row {
    /// A small helper to append a column and field to the fields array
    fileprivate mutating func append(_ value: Column, forField field: Field) {
        self.fields.append((field: field, column: value))
    }
    
    /// Decodes the value's Data as a binary type from the provided field
    mutating func append(_ value: Data, forField field: Field) throws {
        switch field.fieldType {
        case .null:
            append(.null, forField: field)
        case .varString:
            append(.varString(value), forField: field)
        default:
            throw MySQLError.unsupported
        }
    }
    
    /// Decodes the value's Data as a text expressed type from the provided field
    mutating func append(_ value: String, forField field: Field) throws {
        switch field.fieldType {
        case .null:
            append(.null, forField: field)
        case .string:
            append(.string(value), forField: field)
        case .longlong:
            // `longlong` is an (U)Int64 being either signed or unsigned
            if field.flags.contains(.unsigned) {
                guard let int = UInt64(value) else {
                    throw MySQLError.parsingError
                }
                
                append(.uint64(int), forField: field)
            } else {
                guard let int = Int64(value) else {
                    throw MySQLError.parsingError
                }
                
                append(.int64(int), forField: field)
            }
        case .int24:
            // `int24` is represented as (U)Int32 being either signed or unsigned
            fallthrough
        case .long:
            // `long` is an (U)Int32 being either signed or unsigned
            if field.flags.contains(.unsigned) {
                guard let int = UInt32(value) else {
                    throw MySQLError.parsingError
                }
                
                append(.uint32(int), forField: field)
            } else {
                guard let int = Int32(value) else {
                    throw MySQLError.parsingError
                }
                
                append(.int32(int), forField: field)
            }
        case .short:
            // `long` is an (U)Int16 being either signed or unsigned
            if field.flags.contains(.unsigned) {
                guard let int = UInt16(value) else {
                    throw MySQLError.parsingError
                }
                
                append(.uint16(int), forField: field)
            } else {
                guard let int = Int16(value) else {
                    throw MySQLError.parsingError
                }
                
                append(.int16(int), forField: field)
            }
        case .tiny:
            // `tiny` is an (U)Int8 being either signed or unsigned
            if field.flags.contains(.unsigned) {
                guard let int = UInt8(value) else {
                    throw MySQLError.parsingError
                }
                
                append(.uint8(int), forField: field)
            } else {
                guard let int = Int8(value) else {
                    throw MySQLError.parsingError
                }
                
                append(.int8(int), forField: field)
            }
        case .double:
            // Decodes this string as a Double
            guard let double = Double(value) else {
                throw MySQLError.parsingError
            }
            
            append(.double(double), forField: field)
        case .float:
            // Decodes this string as a Float
            guard let float = Float(value) else {
                throw MySQLError.parsingError
            }
            
            append(.float(float), forField: field)
        default:
            throw MySQLError.unsupported
        }
    }
}
