extension WebSocket {
    public func send(_ msg: Frame) throws {
        // TODO: Throw if control frame greater than 125 byte PAYLOAD.
        try stream.send(msg)
    }

    // TODO: Not Masking etc. assumes Server to Client, consider strategy to support both
    public func send(_ text: String) throws {
        let payload = Data(text)
        let header = Frame.Header(
            fin: true,
            rsv1: false,
            rsv2: false,
            rsv3: false,
            opCode: .text,
            isMasked: false,
            payloadLength: UInt64(payload.count),
            maskingKey: .none
        )

        let msg = Frame(header: header, payload: payload)
        try send(msg)
    }

    public func send(_ binary: Data) throws {
        let payload = binary
        let header = Frame.Header(
            fin: true,
            rsv1: false,
            rsv2: false,
            rsv3: false,
            opCode: .binary,
            isMasked: false,
            payloadLength: UInt64(payload.count),
            maskingKey: .none
        )
        let msg = Frame(header: header, payload: payload)
        try send(msg)
    }
}
