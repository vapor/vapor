public protocol ClientStream {
    static func makeConnection(host: String, port: Int, usingSSL: Bool) throws -> Stream
}
