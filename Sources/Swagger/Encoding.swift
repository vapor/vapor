public final class Encoding: Encodable {
    public var contentType: String?
    public var headers = [String: PossibleReference<Header>]()
    public var style: String?
    public var explode: Bool?
    public var allowReserved: Bool?
}
