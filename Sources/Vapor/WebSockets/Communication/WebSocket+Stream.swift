extension Stream {
    public func send(_ message: WebSock.Frame) throws {
        let serializer = MessageSerializer(message)
        let data = serializer.serialize()
        try send(Data(data))
    }
}
