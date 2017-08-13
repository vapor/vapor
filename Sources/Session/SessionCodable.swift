public protocol SessionDecodable: Decodable {
    static var sessionKeyMap: [String: String?] { get }
}

import Core

extension SessionDecodable {
    public init(sessionData: SessionData) throws {
        let decoder = PolymorphicDecoder<SessionData>.init(
            data: sessionData,
            codingPath: [],
            codingKeyMap: Self._keyMap,
            userInfo: [:]
        ) { type, data, decoder in
            if let decodable = type as? SessionDecodable.Type {
                return PolymorphicDecoder<SessionData>.init(
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

    public static var sessionKeyMap: [String: String?] {
        return [:]
    }

    fileprivate static func _keyMap(key: CodingKey) -> CodingKey? {
        if let mapped = sessionKeyMap[key.stringValue] {
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

