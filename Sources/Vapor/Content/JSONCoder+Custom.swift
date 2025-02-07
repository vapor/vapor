import Foundation

extension JSONEncoder {
    /// Convenience for creating a customized ``Foundation/JSONEncoder``.
    ///
    ///     let encoder: JSONEncoder = .custom(dates: .millisecondsSince1970)
    ///
    /// - Parameters:
    ///   - dates: Date encoding strategy.
    ///   - data: Data encoding strategy.
    ///   - keys: Key encoding strategy.
    ///   - format: Output formatting.
    ///   - floats: Non-conforming float encoding strategy.
    ///   - userInfo: Coder userInfo.
    /// - Returns: Newly created ``Foundation/JSONEncoder``.
    public static func custom(
        dates dateStrategy: JSONEncoder.DateEncodingStrategy? = nil,
        data dataStrategy: JSONEncoder.DataEncodingStrategy? = nil,
        keys keyStrategy: JSONEncoder.KeyEncodingStrategy? = nil,
        format outputFormatting: JSONEncoder.OutputFormatting? = nil,
        floats floatStrategy: JSONEncoder.NonConformingFloatEncodingStrategy? = nil,
        userInfo: [CodingUserInfoKey: Any]? = nil
    ) -> JSONEncoder {
        let json = JSONEncoder()
        if let dateStrategy = dateStrategy {
            json.dateEncodingStrategy = dateStrategy
        }
        if let dataStrategy = dataStrategy {
            json.dataEncodingStrategy = dataStrategy
        }
        if let keyStrategy = keyStrategy {
            json.keyEncodingStrategy = keyStrategy
        }
        if let outputFormatting = outputFormatting {
            json.outputFormatting = outputFormatting
        }
        if let floatStrategy = floatStrategy {
            json.nonConformingFloatEncodingStrategy = floatStrategy
        }
        if let userInfo = userInfo {
            json.userInfo = userInfo
        }
        return json
    }
}

extension JSONDecoder {
    /// Convenience for creating a customized ``Foundation/JSONDecoder``.
    ///
    ///     let decoder: JSONDecoder = .custom(dates: .millisecondsSince1970)
    ///
    /// - Parameters:
    ///   - dates: Date decoding strategy.
    ///   - data: Data decoding strategy.
    ///   - keys: Key decoding strategy.
    ///   - floats: Non-conforming float decoding strategy.
    ///   - userInfo: Coder userInfo.
    /// - Returns: Newly created ``JSONDecoder``.
    public static func custom(
        dates dateStrategy: JSONDecoder.DateDecodingStrategy? = nil,
        data dataStrategy: JSONDecoder.DataDecodingStrategy? = nil,
        keys keyStrategy: JSONDecoder.KeyDecodingStrategy? = nil,
        floats floatStrategy: JSONDecoder.NonConformingFloatDecodingStrategy? = nil,
        userInfo: [CodingUserInfoKey: Any]? = nil
    ) -> JSONDecoder {
        let json = JSONDecoder()
        if let dateStrategy = dateStrategy {
            json.dateDecodingStrategy = dateStrategy
        }
        if let dataStrategy = dataStrategy {
            json.dataDecodingStrategy = dataStrategy
        }
        if let keyStrategy = keyStrategy {
            json.keyDecodingStrategy = keyStrategy
        }
        if let floatStrategy = floatStrategy {
            json.nonConformingFloatDecodingStrategy = floatStrategy
        }
        if let userInfo = userInfo {
            json.userInfo = userInfo
        }
        return json
    }
}
