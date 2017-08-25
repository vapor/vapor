import Foundation

extension Row {
    fileprivate mutating func append(_ value: Column, forField field: Field) {
        self.fields.append((field: field, column: value))
    }
    
    mutating func append(_ value: Data, forField field: Field) throws {
        switch field.fieldType {
        case .varString:
            append(.varString(value), forField: field)
        default:
            throw MySQLError.unsupported
        }
    }
    
    mutating func append(_ value: String, forField field: Field) throws {
        switch field.fieldType {
        case .null:
            append(.null, forField: field)
        case .string:
            append(.string(value), forField: field)
        case .longlong:
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
            fallthrough
        case .long:
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
            guard let double = Double(value) else {
                throw MySQLError.parsingError
            }
            
            append(.double(double), forField: field)
        case .float:
            guard let float = Float(value) else {
                throw MySQLError.parsingError
            }
            
            append(.float(float), forField: field)
        default:
            throw MySQLError.unsupported
        }
    }
}
