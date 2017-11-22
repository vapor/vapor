import Foundation
import Crypto
import Bits

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
    case datetime(Date)
    case float(Float)
    case null
    case tinyBlob(Data)
    case mediumBlob(Data)
    case longBlob(Data)
    case blob(Data)
    case varChar(String)
    case varString(String)
    case string(String)
}

/// A single row from a table
///
/// All of `field`, `fieldNames` and `columns` *must* be the same count
struct Row {
    /// A list of all collected columns and their metadata (Field)
    var fields = [Field]()
    
    /// All field names for fast searching
    var fieldNames = [String]()
    
    /// All column data associated with the field
    var columns = [Column]()
}

