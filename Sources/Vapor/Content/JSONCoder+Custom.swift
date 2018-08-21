/* FIXME: add key strategy support once available on Linux */

extension JSONEncoder {
    /// Convenience for creating a customized `JSONEncoder`.
    ///
    ///     let encoder: JSONEncoder = .custom(dates: .millisecondsSince1970)
    ///
    /// - parameters:
    ///     - dates: Date encoding strategy.
    ///     - data: Data encoding strategy.
    ///     - format: Output formatting.
    ///     - floats: Non-conforming float encoding strategy.
    /// - returns: Newly created `JSONEncoder`.
    public static func custom(
        dates dateStrategy: JSONEncoder.DateEncodingStrategy? = nil,
        data dataStrategy: JSONEncoder.DataEncodingStrategy? = nil,
        // keys keyStrategy: JSONEncoder.KeyEncodingStrategy? = nil,
        format outputFormatting: JSONEncoder.OutputFormatting? = nil,
        floats floatStrategy: JSONEncoder.NonConformingFloatEncodingStrategy? = nil
    ) -> JSONEncoder {
        let json = JSONEncoder()
        if let dateStrategy = dateStrategy {
            json.dateEncodingStrategy = dateStrategy
        }
        if let dataStrategy = dataStrategy {
            json.dataEncodingStrategy = dataStrategy
        }
        // if let keyStrategy = keyStrategy {
        //     json.keyEncodingStrategy = keyStrategy
        // }
        if let outputFormatting = outputFormatting {
            json.outputFormatting = outputFormatting
        }
        if let floatStrategy = floatStrategy {
            json.nonConformingFloatEncodingStrategy = floatStrategy
        }
        return json
    }
}

extension JSONDecoder {
    /// Convenience for creating a customized `JSONDecoder`.
    ///
    ///     let decoder: JSONDecoder = .custom(dates: .millisecondsSince1970)
    ///
    /// - parameters:
    ///     - dates: Date encoding strategy.
    ///     - data: Data encoding strategy.
    ///     - floats: Non-conforming float encoding strategy.
    /// - returns: Newly created `JSONDecoder`.
    public static func custom(
        dates dateStrategy: JSONDecoder.DateDecodingStrategy? = nil,
        data dataStrategy: JSONDecoder.DataDecodingStrategy? = nil,
        // keys keyStrategy: JSONDecoder.KeyDecodingStrategy? = nil,
        floats floatStrategy: JSONDecoder.NonConformingFloatDecodingStrategy? = nil
    ) -> JSONDecoder {
        let json = JSONDecoder()
        if let dateStrategy = dateStrategy {
            json.dateDecodingStrategy = dateStrategy
        }
        if let dataStrategy = dataStrategy {
            json.dataDecodingStrategy = dataStrategy
        }
        // if let keyStrategy = keyStrategy {
        //     json.keyDecodingStrategy = keyStrategy
        // }
        if let floatStrategy = floatStrategy {
            json.nonConformingFloatDecodingStrategy = floatStrategy
        }
        return json
    }
}
