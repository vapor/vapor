import S4
// Empty for now, will eventually fill with more metadata, likely mostly types
public protocol ProtocolFormat {}
public struct HTTP: ProtocolFormat {
    // Can't nest protocol, but can typealias to make nested
    public typealias Message = HTTPMessage
    public typealias SerializerProtocol = HTTPSerializerProtocol
    public typealias ParserProtocol = HTTPParserProtocol

    public typealias Version = S4.Version
    public typealias Method = S4.Method
}
