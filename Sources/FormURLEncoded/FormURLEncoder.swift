import Foundation

/// Encodes encodable structures to form-urlencoded data.
public final class FormURLEncoder {
    /// Create a new form-urlencoded encoder.
    public init() {}

    /// Encodes the supplied encodable structure to form-urlencoded data.
    public func encode(_ encodable: Encodable) throws -> Data {
        let partialData = PartialFormURLEncodedData(
            data: .dictionary([:])
        )
        let encoder = _FormURLEncoder(
            partialData: partialData,
            codingPath: []
        )
        try encodable.encode(to: encoder)
        let serializer = FormURLEncodedSerializer()
        guard case .dictionary(let dict) = partialData.data else {
            throw FormURLError(
                identifier: "invalidTopLevel",
                reason: "form-urlencoded requires a top level dictionary"
            )
        }
        return try serializer.serialize(dict)
    }
}

/// Internal form urlencoded encoder.
/// See FormURLEncoder for the public encoder.
final class _FormURLEncoder: Encoder {
    /// See Encoder.userInfo
    let userInfo: [CodingUserInfoKey: Any]

    /// See Encoder.codingPath
    let codingPath: [CodingKey]

    /// The data being decoded
    var partialData: PartialFormURLEncodedData

    /// Creates a new form url-encoded encoder
    init(partialData: PartialFormURLEncodedData, codingPath: [CodingKey]) {
        self.partialData = partialData
        self.codingPath = codingPath
        self.userInfo = [:]
    }

    /// See Encoder.container
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key>
        where Key: CodingKey
    {
        let container = FormURLKeyedEncoder<Key>(partialData: partialData, codingPath: codingPath)
        return .init(container)
    }

    /// See Encoder.unkeyedContainer
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError()
    }

    /// See Encoder.singleValueContainer
    func singleValueContainer() -> SingleValueEncodingContainer {
        return FormURLSingleValueEncoder(partialData: partialData, codingPath: codingPath)
    }
}
