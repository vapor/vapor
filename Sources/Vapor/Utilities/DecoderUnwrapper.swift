@available(*, deprecated, message: "This type violates Codable invariants; using it is not safe.")
public struct DecoderUnwrapper: Decodable {
    public let decoder: Decoder
    public init(from decoder: Decoder) {
        self.decoder = decoder
    }
}
