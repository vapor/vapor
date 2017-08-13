public protocol CacheDecodable: Decodable {
    static var cacheKeyMap: [String: String?] { get }
}

import Core

extension CacheDecodable {
    public init(cacheData: CacheData) throws {
        let decoder = PolymorphicDecoder<CacheData>.init(
            data: cacheData,
            codingPath: [],
            codingKeyMap: Self._keyMap,
            userInfo: [:]
        ) { type, data, decoder in
            if let decodable = type as? CacheDecodable.Type {
                return PolymorphicDecoder<CacheData>.init(
                    data: data,
                    codingPath: decoder.codingPath,
                    codingKeyMap: decodable._keyMap,
                    userInfo: decoder.userInfo,
                    factory: decoder.factory
                )
            } else {
                return decoder
            }
        }
        try self.init(from: decoder)
     }

    public static var cacheKeyMap: [String: String?] {
        return [:]
    }

    fileprivate static func _keyMap(key: CodingKey) -> CodingKey? {
        if let mapped = cacheKeyMap[key.stringValue] {
            if let key = mapped {
                return StringKey(key)
            } else {
                return nil
            }
        } else {
            return key
        }
    }
}
