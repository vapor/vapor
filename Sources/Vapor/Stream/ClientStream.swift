public protocol ClientStream {
    static func makeConnection(host: String, port: Int) throws -> Stream
}
