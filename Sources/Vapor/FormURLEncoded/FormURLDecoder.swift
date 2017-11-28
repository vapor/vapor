import Core

/// Internal form urlencoded decoder.
/// See FormURLDecoder for the public decoder.
final class _FormURLDecoder: Decoder {
    /// See Decoder.codingPath
    let codingPath: [CodingKey]

    /// See Decoder.userInfo
    let userInfo: [CodingUserInfoKey : Any]

    /// The data being decoded
    let data: FormURLEncodedData

    /// Creates a new form urlencoded decoder
    init(data: FormURLEncodedData) {
        self.data = data
        self.codingPath = []
        self.userInfo = [:]
    }

    /// See Decoder.container
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
        where Key: CodingKey {
        fatalError("unimplemented")
    }

    /// See Decoder.unkeyedContainer
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        fatalError("unimplemented")
    }

    /// See Decoder.singleValueContainer
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return FormURLSingleValueDecoder(codingPath: codingPath, data: data)
    }
}

extension FormURLEncodedData {
    /// Returns the value, if one at from the given path.
    func get(at path: [CodingKey]) -> FormURLEncodedData? {
        var child = self

        for seg in path {
            if let index = seg as? ArrayKey {
                guard let c = child.array?[safe: index.index] else {
                    return nil
                }
                child = c
            } else {
                guard let c = child.dictionary?[seg.stringValue] else {
                    return nil
                }
                child = c
            }
        }

        return child
    }
}
