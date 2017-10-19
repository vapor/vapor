import Foundation

/// All possibles cases for SQLite data.
public enum SQLiteData {
    case integer(Int)
    case float(Double)
    case text(String)
    case blob(Foundation.Data)
    case null
}

extension SQLiteData {
    /// Returns an Int if the data is case .integer
    public var integer: Int? {
        switch self {
        case .integer(let int):
            return int
        default:
            return nil
        }
    }

    /// Returns a String if the data is case .text
    public var text: String? {
        switch self {
        case .text(let string):
            return string
        default:
            return nil
        }
    }

    /// Returns a float if the data is case .double
    public var float: Double? {
        switch self {
        case .float(let double):
            return double
        default:
            return nil
        }
    }

    /// Returns Foundation.Data if the data is case .blob
    public var blob: Foundation.Data? {
        switch self {
        case .blob(let data):
            return data
        default:
            return nil
        }
    }

    /// Returns true if the data == .null
    public var isNull: Bool {
        switch self {
        case .null:
            return true
        default:
            return false
        }
    }
}

extension SQLiteData: CustomStringConvertible {
    /// Description of data
    public var description: String {
        switch self {
        case .blob(let data):
            return data.description
        case .float(let float):
            return float.description
        case .integer(let int):
            return int.description
        case .null:
            return "<null>"
        case .text(let text):
            return text
        }
    }
}
