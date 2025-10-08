import Foundation
import NIOHTTP1

extension HTTPHeaders {
    /// A marker header internal to vapor that explicitly allows or disallows response compression.
    public struct ResponseCompression: Sendable, Hashable {
        enum Value: String {
            case enable
            case disable
            case useDefault
        }
        
        /// Explicitly use the server's default response compression determination.
        public static let useDefault = ResponseCompression(value: .useDefault)
        
        /// Implicitly use the server's default response compression determination.
        ///
        /// This value has no effect when set as a route override
        public static let unset = ResponseCompression(value: nil)
        
        /// Explicitly enable response compression.
        public static let enable = ResponseCompression(value: .enable)
        
        /// Explicitly disable response compression.
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

    /// A marker header internal to vapor that explicitly allows or disallows response compression.
    public var responseCompression: ResponseCompression {
        get { ResponseCompression(string: self[canonicalForm: .xVaporResponseCompression].last.map { String ($0) }) }
        set {
            if let newValue = newValue.rawValue {
                self.replaceOrAdd(name: .xVaporResponseCompression, value: newValue)
            } else {
                self.remove(name: .xVaporResponseCompression)
            }
        }
    }
}

