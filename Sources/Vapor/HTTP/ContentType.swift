import HTTP
import Vapor

extension Vapor.KeyAccessible where Key == HeaderKey, Value == String {
    
    var contentType: String? {
        get {
            return self["Content-Type"]
        }
        set {
            self["Content-Type"] = newValue
        }
    }
    
}

public enum ContentType: Hashable {
    case any
    case html
    case json
    case other(String)
    
    var stringValue: String {
        switch self {
        case .any:
            return "*/*"
        case .html:
            return "text/html"
        case .json:
            return "application/json"
        case .other(let type):
            return type
        }
    }
    
    public static func from(string: String) -> ContentType {
        switch string {
        case ContentType.html.stringValue:
            return .html
        case ContentType.json.stringValue:
            return .json
        case ContentType.any.stringValue:
            return .any
        default:
            return .other(string)
        }
    }
    
    public var hashValue: Int {
        return stringValue.hashValue
    }
    
    public static func ==(lhs: ContentType, rhs: ContentType) -> Bool {
        return lhs.stringValue == rhs.stringValue
    }
    
}
