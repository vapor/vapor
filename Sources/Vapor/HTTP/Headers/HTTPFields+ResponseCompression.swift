import Foundation
import HTTPTypes

extension HTTPFields {
    /// A marker header internal to vapor that explicitely allows or disallows response compression.
    public struct ResponseCompression: Sendable, Hashable {
        enum Value: String {
            case enable
            case disable
            case useDefault
        }
        
        /// Explicitely use the server's default response compression determination.
        public static let useDefault = ResponseCompression(value: .useDefault)
        
        /// Implicitely use the server's default response compression determination.
        ///
        /// This value has no effect when set as a route override
        public static let unset = ResponseCompression(value: nil)
        
        /// Explicitely enable response compression.
        public static let enable = ResponseCompression(value: .enable)
        
        /// Explicitely disable response compression.
        public static let disable = ResponseCompression(value: .disable)
        
        let value: Value?
        
        init(value: Value?) {
            self.value = value
        }
        
        init(string: String?) {
            self.init(value: string.flatMap { Value(rawValue: $0) })
        }
        
        var rawValue: String? {
            value?.rawValue
        }
    }

    /// A marker header internal to vapor that explicitely allows or disallows response compression.
    public var responseCompression: ResponseCompression {
        get { ResponseCompression(string: self[values: .xVaporResponseCompression].last.map { String ($0) }) }
        set {
            if let newValue = newValue.rawValue {
                self[.xVaporResponseCompression] = newValue
            } else {
                self[.xVaporResponseCompression] = nil
            }
        }
    }
}

