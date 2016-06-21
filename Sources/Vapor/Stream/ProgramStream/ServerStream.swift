public protocol ServerStream: ProgramStream {
    func accept() throws -> Stream
}
