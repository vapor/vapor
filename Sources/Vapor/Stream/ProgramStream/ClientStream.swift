public protocol ClientStream: ProgramStream {
    func connect() throws -> Stream
}
