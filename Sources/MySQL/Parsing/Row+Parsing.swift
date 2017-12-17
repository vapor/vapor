import Foundation
import COperatingSystem
import Bits

extension Packet {
    /// Reads this packet as a row containing the data related to the provided columns
    func parseRow(columns: [Field], binary: Bool, reserveCapacity: Int? = nil) throws -> Row {
        var parser = Parser(packet: self)
        var row = Row()
        
        if let reserveCapacity = reserveCapacity {
            row.reserveCapacity(reserveCapacity)
        }
        
        // Binary packets have a bit more data to carry `null`s  and a header
        if binary {
            guard try parser.byte() == 0 else {
                throw MySQLError(.invalidPacket)
            }
            
            let nullBytes = (columns.count + 9) / 8
            
            parser.position += nullBytes
        }
        
        var offset = 0
        
        // Parses each field
        for field in columns {
            defer { offset += 1 }
            
            if binary {
                // Binary packets are parsed more literally (binary)
                let value = try parser.parseColumn(forField: field, index: offset)
                
                row.append(value, forField: field)
            } else {
                // Text packets are parsed from strings or raw data
                if field.isBinary {
                    let value = try parser.parseLenEncData()
                    
                    try row.append(value, forField: field)
                } else {
                    let value = try parser.parseLenEncBytes()
                    
                    try row.append(value, forField: field)
                }
            }
        }
        
        return row
    }
}

extension Parser {
    mutating func parseColumn(forField field: Field, index: Int) throws -> Column {
        if self.payload[1 + (index / 8)] >> (8 - (index % 8)) == 1 {
            return .null
        } else {
            switch field.fieldType {
            case .decimal: throw MySQLError(.unsupported)
            case .tiny:
                let byte = try self.byte()
                
                if field.flags.contains(.unsigned) {
                    return .uint8(byte)
                } else {
                    return .int8(numericCast(byte))
                }
            case .short:
                let num = try self.parseUInt16()
                
                if field.flags.contains(.unsigned) {
                    return .uint16(num)
                } else {
                    return .int16(numericCast(num))
                }
            case .long:
                let num = try self.parseUInt32()
                
                if field.flags.contains(.unsigned) {
                    return .uint32(num)
                } else {
                    return .int32(numericCast(num))
                }
            case .float:
                let num = try self.parseUInt32()
                
                return .float(Float(bitPattern: num))
            case .double:
                let num = try self.parseUInt64()
                
                return .double(Double(bitPattern: num))
            case .null:
                return .null
            case .timestamp: throw MySQLError(.unsupported)
            case .longlong:
                let num = try self.parseUInt64()
                
                if field.flags.contains(.unsigned) {
                    return .uint64(num)
                } else {
                    return .int64(numericCast(num))
                }
            case .int24: throw MySQLError(.unsupported)
            case .date: throw MySQLError(.unsupported)
            case .time: throw MySQLError(.unsupported)
            case .datetime:
                let format = try byte()
                
                let year = try parseUInt16()
                let month = try byte()
                let day = try byte()
                let hour = try byte()
                let minute = try byte()
                let second = try byte()
                var microseconds: UInt32 = 0
                
                if format == 11 {
                    microseconds = try parseUInt32()
                }
                
                let calendar = Calendar(identifier: .gregorian)
                
                guard let date = calendar.date(from:
                    DateComponents(
                        calendar: calendar,
                        year: numericCast(year),
                        month: numericCast(month),
                        day: numericCast(day),
                        hour: numericCast(hour),
                        minute: numericCast(minute),
                        second: numericCast(second),
                        nanosecond: numericCast(microseconds * 1000)
                    )
                ) else {
                    throw MySQLError(.invalidPacket)
                }
                
                return .datetime(date)
            case .year: throw MySQLError(.unsupported)
            case .newdate: throw MySQLError(.unsupported)
            case .varchar:
                return .varChar(try self.parseLenEncString())
            case .bit: throw MySQLError(.unsupported)
            case .json: throw MySQLError(.unsupported)
            case .newdecimal: throw MySQLError(.unsupported)
            case .enum: throw MySQLError(.unsupported)
            case .set: throw MySQLError(.unsupported)
            case .tinyBlob:
                return .tinyBlob(try self.parseLenEncData())
            case .mediumBlob:
                return .mediumBlob(try self.parseLenEncData())
            case .longBlob:
                return .longBlob(try self.parseLenEncData())
            case .blob:
                return .blob(try self.parseLenEncData())
            case .varString:
                return .varString(try self.parseLenEncString())
            case .string:
                return .string(try self.parseLenEncString())
            case .geometry: throw MySQLError(.unsupported)
            }
        }
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
    mutating func append(_ value: ByteBuffer, forField field: Field) throws {
        func makeString() -> String {
            return String(data: Data(value), encoding: .utf8) ?? ""
        }
        
        switch field.fieldType {
        case .varString, .string:
            append(.varString(makeString()), forField: field)
        case .null:
            append(.null, forField: field)
        case .longlong:
            // `longlong` is an (U)Int64 being either signed or unsigned
            value.baseAddress!.withMemoryRebound(to: Int8.self, capacity: value.count) { pointer in
                if field.flags.contains(.unsigned) {
                    let i = strtouq(pointer, nil, 10)
                    
                    append(.uint64(i), forField: field)
                } else {
                    let i = strtoq(pointer, nil, 10)
                    
                    append(.int64(i), forField: field)
                }
            }
        case .int24:
            // `int24` is represented as (U)Int32 being either signed or unsigned
            fallthrough
        case .long:
            // `long` is an (U)Int32 being either signed or unsigned
            value.baseAddress!.withMemoryRebound(to: Int8.self, capacity: value.count) { pointer in
                let i = atoi(pointer)
                
                if field.flags.contains(.unsigned) {
                    append(.uint32(numericCast(i)), forField: field)
                } else {
                    append(.int32(numericCast(i)), forField: field)
                }
            }
        case .short:
            // `long` is an (U)Int16 being either signed or unsigned
            try value.baseAddress!.withMemoryRebound(to: Int8.self, capacity: value.count) { pointer in
                let int = atoi(pointer)
                
                if field.flags.contains(.unsigned) {
                    guard int >= 0, int <= numericCast(UInt16.max) else {
                        throw MySQLError(.parsingError)
                    }
                    
                    append(.uint16(numericCast(int)), forField: field)
                } else {
                    guard int >= Int16.min, int <= numericCast(Int16.max) else {
                        throw MySQLError(.parsingError)
                    }
                    
                    append(.int16(numericCast(int)), forField: field)
                }
            }
        case .tiny:
            // `tiny` is an (U)Int8 being either signed or unsigned
            try value.baseAddress!.withMemoryRebound(to: Int8.self, capacity: value.count) { pointer in
                let int = atoi(pointer)
                
                if field.flags.contains(.unsigned) {
                    guard int >= 0, int <= numericCast(UInt8.max) else {
                        throw MySQLError(.parsingError)
                    }
                    
                    append(.uint8(numericCast(int)), forField: field)
                } else {
                    guard int >= Int8.min, int <= numericCast(Int8.max) else {
                        throw MySQLError(.parsingError)
                    }
                    
                    append(.int8(numericCast(int)), forField: field)
                }
            }
        case .double:
            // Decodes this string as a Double
            value.baseAddress!.withMemoryRebound(to: Int8.self, capacity: value.count) { pointer in
                let double = strtod(pointer, nil)
                append(.double(double), forField: field)
            }
        case .float:
            // Decodes this string as a Float
            value.baseAddress!.withMemoryRebound(to: Int8.self, capacity: value.count) { pointer in
                let float = strtof(pointer, nil)
                append(.float(float), forField: field)
            }
        case .datetime:
            guard let date = mysqlFormatter.date(from: makeString()) else {
                throw MySQLError(.parsingError)
            }
            
            append(.datetime(date), forField: field)
        default:
            throw MySQLError(.unsupported)
        }
    }
}

fileprivate let mysqlFormatter: DateFormatter = {
    var formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    
    return formatter
}()
