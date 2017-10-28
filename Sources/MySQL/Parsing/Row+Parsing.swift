import Foundation

extension Packet {
    /// Reads this packet as a row containing the data related to the provided columns
    func makeRow(columns: [Field], binary: Bool) throws -> Row {
        let parser = Parser(packet: self)
        var row = Row()
        
        if binary {
            guard try parser.byte() == 0 else {
                throw MySQLError(.invalidPacket)
            }
            
            let nullBytes = (columns.count + 9) / 8
            
            parser.position += nullBytes
        }
        
        var offset = 0
        
        for field in columns {
            defer { offset += 1 }
            
            // If null
            if binary {
                if parser.payload[1 + (offset / 8)] >> (8 - (offset % 8)) == 1 {
                    row.append(.null, forField: field)
                } else {
                    switch field.fieldType {
                    case .decimal: throw MySQLError(.unsupported)
                    case .tiny:
                        let byte = try parser.byte()
                        
                        if field.flags.contains(.unsigned) {
                            row.append(.uint8(byte), forField: field)
                        } else {
                            row.append(.int8(numericCast(byte)), forField: field)
                        }
                    case .short:
                        let num = try parser.parseUInt16()
                        
                        if field.flags.contains(.unsigned) {
                            row.append(.uint16(num), forField: field)
                        } else {
                            row.append(.int16(numericCast(num)), forField: field)
                        }
                    case .long:
                        let num = try parser.parseUInt32()
                        
                        if field.flags.contains(.unsigned) {
                            row.append(.uint32(num), forField: field)
                        } else {
                            row.append(.int32(numericCast(num)), forField: field)
                        }
                    case .float: throw MySQLError(.unsupported)
                    case .double: throw MySQLError(.unsupported)
                    case .null:
                        row.append(.null, forField: field)
                    case .timestamp: throw MySQLError(.unsupported)
                    case .longlong:
                        let num = try parser.parseUInt64()
                        
                        if field.flags.contains(.unsigned) {
                            row.append(.uint64(num), forField: field)
                        } else {
                            row.append(.int64(numericCast(num)), forField: field)
                        }
                    case .int24: throw MySQLError(.unsupported)
                    case .date: throw MySQLError(.unsupported)
                    case .time: throw MySQLError(.unsupported)
                    case .datetime: throw MySQLError(.unsupported)
                    case .year: throw MySQLError(.unsupported)
                    case .newdate: throw MySQLError(.unsupported)
                    case .varchar:
                        row.append(
                            .varChar(try parser.parseLenEncString()),
                            forField: field
                        )
                    case .bit: throw MySQLError(.unsupported)
                    case .json: throw MySQLError(.unsupported)
                    case .newdecimal: throw MySQLError(.unsupported)
                    case .enum: throw MySQLError(.unsupported)
                    case .set: throw MySQLError(.unsupported)
                    case .tinyBlob: throw MySQLError(.unsupported)
                    case .mediumBlob: throw MySQLError(.unsupported)
                    case .longBlob: throw MySQLError(.unsupported)
                    case .blob: throw MySQLError(.unsupported)
                    case .varString:
                        row.append(
                            .varString(try parser.parseLenEncString()),
                            forField: field
                        )
                    case .string:
                        row.append(
                            .string(try parser.parseLenEncString()),
                            forField: field
                        )
                    case .geometry: throw MySQLError(.unsupported)
                    }
                }
            } else {
                if field.isBinary {
                    let value = try parser.parseLenEncData()
                    
                    try row.append(value, forField: field)
                } else {
                    let value = try parser.parseLenEncString()
                    
                    try row.append(value, forField: field)
                }
            }
        }
        
        return row
    }
}

/// An extension that implements deserialization from a Row's columns in binary to a concrete type
extension Row {
    /// A small helper to append a column and field to the fields array
    fileprivate mutating func append(_ value: Column, forField field: Field) {
        self.fieldNames.append(field.name)
        self.fields.append(field)
        self.columns.append(value)
    }
    
    /// Decodes the value's Data as a binary type from the provided field
    mutating func append(_ value: Data, forField field: Field) throws {
        switch field.fieldType {
        case .null:
            append(.null, forField: field)
        default:
            throw MySQLError(.unsupported)
        }
    }
    
    /// Decodes the value's Data as a text expressed type from the provided field
    mutating func append(_ value: String, forField field: Field) throws {
        switch field.fieldType {
        case .varString:
            append(.varString(value), forField: field)
        case .null:
            append(.null, forField: field)
        case .string:
            append(.string(value), forField: field)
        case .longlong:
            // `longlong` is an (U)Int64 being either signed or unsigned
            if field.flags.contains(.unsigned) {
                guard let int = UInt64(value) else {
                    throw MySQLError(.parsingError)
                }
                
                append(.uint64(int), forField: field)
            } else {
                guard let int = Int64(value) else {
                    throw MySQLError(.parsingError)
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
                    throw MySQLError(.parsingError)
                }
                
                append(.uint32(int), forField: field)
            } else {
                guard let int = Int32(value) else {
                    throw MySQLError(.parsingError)
                }
                
                append(.int32(int), forField: field)
            }
        case .short:
            // `long` is an (U)Int16 being either signed or unsigned
            if field.flags.contains(.unsigned) {
                guard let int = UInt16(value) else {
                    throw MySQLError(.parsingError)
                }
                
                append(.uint16(int), forField: field)
            } else {
                guard let int = Int16(value) else {
                    throw MySQLError(.parsingError)
                }
                
                append(.int16(int), forField: field)
            }
        case .tiny:
            // `tiny` is an (U)Int8 being either signed or unsigned
            if field.flags.contains(.unsigned) {
                guard let int = UInt8(value) else {
                    throw MySQLError(.parsingError)
                }
                
                append(.uint8(int), forField: field)
            } else {
                guard let int = Int8(value) else {
                    throw MySQLError(.parsingError)
                }
                
                append(.int8(int), forField: field)
            }
        case .double:
            // Decodes this string as a Double
            guard let double = Double(value) else {
                throw MySQLError(.parsingError)
            }
            
            append(.double(double), forField: field)
        case .float:
            // Decodes this string as a Float
            guard let float = Float(value) else {
                throw MySQLError(.parsingError)
            }
            
            append(.float(float), forField: field)
        default:
            throw MySQLError(.unsupported)
        }
    }
}
