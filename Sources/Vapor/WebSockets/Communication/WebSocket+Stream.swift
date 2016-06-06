extension Stream {
    public func send(_ message: WebSocket.Frame) throws {
        let serializer = FrameSerializer(message)
        let data = serializer.serialize()
        try send(Data(data))
    }
}
