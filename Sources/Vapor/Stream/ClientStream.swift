public protocol AddressStream {
    init(host: String, port: Int) throws
}

public protocol ClientStream: AddressStream {
    func connect() throws -> Stream
}
