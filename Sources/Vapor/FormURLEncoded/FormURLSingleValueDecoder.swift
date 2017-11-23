import Core

final class FormURLSingleValueDecoder: SingleValueDecodingContainer {
    /// See SingleValueDecodingContainer.codingPath
    var codingPath: [CodingKey]

    /// The data being decoded
    let data: FormURLEncodedData

    /// Creates a new form urlencoded single value decoder
    init(codingPath: [CodingKey], data: FormURLEncodedData) {
        self.data = data
        self.codingPath = codingPath
    }

    func decodeNil() -> Bool {
        fatalError("unimplemented")
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        fatalError("unimplemented")
    }

    func decode(_ type: Int.Type) throws -> Int {
        fatalError("unimplemented")
    }

    func decode(_ type: Float.Type) throws -> Float {
        fatalError("unimplemented")
    }

    func decode(_ type: Double.Type) throws -> Double {
        fatalError("unimplemented")
    }

    func decode(_ type: String.Type) throws -> String {
        fatalError("unimplemented")
    }

    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        fatalError("unimplemented")
    }
}
