public protocol ServerStream: AddressStream {
    func accept() throws -> Stream
}
