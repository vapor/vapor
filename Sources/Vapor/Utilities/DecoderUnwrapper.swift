public struct DecoderUnwrapper: Decodable {
    public let decoder: Decoder
    public init(from decoder: Decoder) {
        self.decoder = decoder
    }
}
