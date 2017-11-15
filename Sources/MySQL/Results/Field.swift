import Bits

/// A Field/Column definition
///
/// Used for specifying both input (bound parameters) and output (results)
class Field: Hashable {
    /// The flags set for this field
    struct Flags: OptionSet, ExpressibleByIntegerLiteral {
        /// Instantiates a flag from an integer literal (used for the constants)
        init(integerLiteral value: UInt16) {
            self.rawValue = value
        }
        
        /// Instantiates a flag from an integer literal (used for the constants)
        init(rawValue: UInt16) {
            self.rawValue = rawValue
        }
        
        /// The Field Flag's raw value
        var rawValue: UInt16
        
        /// -
        typealias RawValue = UInt16
        
        /// This field may not be null
        static let notNull: Flags       = 0b0000000000000001
        
        /// This field is currently a primary key
        static let primaryKey: Flags    = 0b0000000000000010
        
        /// This field is currently a unique key
        static let uniqueKey: Flags     = 0b0000000000000100
        
        static let multiKey: Flags      = 0b0000000000001000
        
        /// This field is a blob
        static let blob: Flags          = 0b0000000000010000
        
        /// This is an unsigned integer
        static let unsigned: Flags      = 0b0000000000100000
        
        static let zeroFill: Flags      = 0b0000000001000000
        
        /// This field is binary data (doesn't mean much)
        static let binary: Flags        = 0b0000000010000000
        
        static let `enum`: Flags        = 0b0000000100000000
        
        /// This field is automatically incremented for each insert
        static let autoincrement: Flags = 0b0000001000000000
        
        /// This field is a timestamp
        static let timestamp: Flags     = 0b0000010000000000
        
        static let set: Flags           = 0b0000100000000000
    }
    
    /// The type of content in this field
    enum FieldType : Byte {
        /// A decimal integer as a string
        case decimal    = 0x00
        
        /// int8, uint8, bool
        case tiny       = 0x01
        
        /// int16, uint16
        case short      = 0x02
        
        /// int32, uint32
        case long       = 0x03
        
        /// float32
        case float      = 0x04
        
        /// double
        case double     = 0x05
        
        /// `nil`
        case null       = 0x06
        
        /// Timestamp with date, time and timezone
        case timestamp  = 0x07
        
        /// int64, uint64
        case longlong   = 0x08
        
        /// 24 bits integer (highest byte of an int32 is empty/0x00)
        case int24      = 0x09
        
        /// A date
        case date       = 0x0a
        
        /// Time (hours, minutes, seconds)
        case time       = 0x0b
        
        /// Date + Time
        case datetime   = 0x0c
        
        /// A year integer (Int16 or Int32)
        case year       = 0x0d
        
        /// A date
        case newdate    = 0x0e
        
        /// A normal predefined length string
        case varchar    = 0x0f
        
        /// A single bit
        case bit        = 0x10
        
        /// A JSON String
        case json       = 0xf5
        
        /// A decimal integer as a string
        case newdecimal = 0xf6
        
        case `enum`     = 0xf7
        
        case set        = 0xf8
        
        /// A binary blob
        case tinyBlob   = 0xf9
        
        /// A binary blob
        case mediumBlob = 0xfa
        
        /// A binary blob
        case longBlob   = 0xfb
        
        /// A binary blob
        case blob       = 0xfc
        
        /// A binary blob representing a string
        case varString  = 0xfd
        
        /// Also a string
        case string     = 0xfe
        
        /// A string specifying geometry
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
    
    /// Always "def"
    let catalog: String?
    
    let database: String?
    
    let table: String?
    
    /// The table this field originates from (for joins)
    let originalTable: String?
    
    /// The field's name
    public let name: String
    
    /// The field's original name (before mutation)
    let originalName: String?
    
    /// The character set
    let charSet: Byte
    
    /// The collation applied on this field
    /// TODO: Move this to a separate collation enum
    let collation: Byte
    
    /// The field's length (in bytes?)
    let length: UInt32
    
    /// The field's type
    let fieldType: FieldType
    
    /// The flags applied to this field, most are never set
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
