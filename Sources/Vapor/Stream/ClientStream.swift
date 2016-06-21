public protocol AddressStream {
    init(scheme: String, host: String, port: Int) throws
}

public protocol ClientStream: AddressStream {
    func connect() throws -> Stream
}
