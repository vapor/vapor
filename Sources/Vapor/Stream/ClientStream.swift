public protocol ClientStream {
    static func makeConnection(host: String, port: Int, secure: Bool) throws -> Stream
}
