import Foundation
import Crypto
import Bits

class Field: Hashable {
    /// The flags set for this field
    struct Flags: OptionSet, ExpressibleByIntegerLiteral {
        public init(integerLiteral value: UInt16) {
            self.rawValue = value
        }
        
        public init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
        
        public var rawValue: UInt16
        
        public typealias RawValue = UInt16
        
        static let notNull : Flags       = 0b0000000000000001
        static let primaryKey : Flags    = 0b0000000000000010
        static let uniqueKey : Flags     = 0b0000000000000100
        static let multiKey : Flags      = 0b0000000000001000
        static let blob : Flags          = 0b0000000000010000
        static let unsigned : Flags      = 0b0000000000100000
        static let zeroFill : Flags      = 0b0000000001000000
        static let binary : Flags        = 0b0000000010000000
        static let `enum` : Flags        = 0b0000000100000000
        static let autoincrement : Flags = 0b0000001000000000
        static let timestamp : Flags     = 0b0000010000000000
        static let set : Flags           = 0b0000100000000000
    }
    
    /// The type of content in this field
    enum FieldType : Byte {
        case decimal    = 0x00
        case tiny       = 0x01 // int8, uint8, bool
        case short      = 0x02 // int16, uint16
        case long       = 0x03 // int32, uint32
        case float      = 0x04 // float32
        case double     = 0x05 // float64
        case null       = 0x06 // nil
        case timestamp  = 0x07 // Timestamp
        case longlong   = 0x08 // int64, uint64
        case int24      = 0x09
        case date       = 0x0a // Date
        case time       = 0x0b // Time
        case datetime   = 0x0c // time.Time
        case year       = 0x0d
        case newdate    = 0x0e
        case varchar    = 0x0f
        case bit        = 0x10
        case json       = 0xf5
        case newdecimal = 0xf6
        case `enum`     = 0xf7
        case set        = 0xf8
        case tinyBlob   = 0xf9
        case mediumBlob = 0xfa
        case longBlob   = 0xfb
        case blob       = 0xfc // Blob
        case varString  = 0xfd // []byte
        case string     = 0xfe // string
        case geometry   = 0xff
    }
    
    /// Makes this field hashable
    public var hashValue: Int {
        return name.hashValue &+ length.hashValue &+ fieldType.rawValue.hashValue &+ flags.rawValue.hashValue
    }
    
    /// Makes this field equatable, so it can be compared to be unique
    public static func ==(lhs: Field, rhs: Field) -> Bool {
        return  lhs.table == rhs.table &&
            lhs.name == rhs.name &&
            lhs.length == rhs.length &&
            lhs.fieldType == rhs.fieldType &&
            lhs.flags == rhs.flags
    }
    
    let catalog: String?
    let database: String?
    let table: String?
    let originalTable: String?
    public let name: String
    let originalName: String?
    let charSet: Byte
    let collation: Byte
    let length: UInt32
    let fieldType: FieldType
    let flags: Flags
    let decimals: Byte
    
    /// If `true`, parse this field from binary blobs, not text strings
    var isBinary: Bool {
        switch fieldType {
        case .blob: return true
        case .longBlob: return true
        case .tinyBlob: return true
        case .mediumBlob: return true
        default: return false
        }
    }
    
    /// Creates a new field from the packet's parsed data
    init(catalog: String?,
         database: String?,
         table: String?,
         originalTable: String?,
         name: String,
         originalName: String?,
         charSet: Byte,
         collation: Byte,
         length: UInt32,
         fieldType: FieldType,
         flags: Flags,
         decimals: Byte
        ) {
        self.catalog = catalog
        self.database = database
        self.table = table
        self.originalTable = originalTable
        self.name = name
        self.originalName = originalName
        self.charSet = charSet
        self.collation = collation
        self.length = length
        self.fieldType = fieldType
        self.flags = flags
        self.decimals = decimals
    }
}

/// All supported column contents
enum Column {
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
    case null
    case varChar(String)
    case varString(String)
    case string(String)
}

/// A single row from a table
struct Row {
    /// A list of all collected columns and their metadata (Field)
    var fields = [Field]()
    var fieldNames = [String]()
    var columns = [Column]()
}

