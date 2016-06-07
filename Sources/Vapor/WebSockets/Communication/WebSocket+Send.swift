/**
 Technically WebSockets supports up to UInt64.max packet sizes, however
 frameworks have the discretion to break up large packets into fragments
 to make usage easier.
 
 The following functions DO NOT parse additional data into chunks. 
 Use these for customized behavior.
 
 Please familiarize yourself w/ WebSocket protocols before attempting to override built in behavior
 
 send(_ frame: Frame) 
 &&
 public func send(
    fin: Bool,
    rsv1: Bool = false,
    rsv2: Bool = false,
    rsv3: Bool = false,
    opCode: Frame.OpCode,
    isMasked: Bool,
    payload: Data)
 
 

 */
private let PayloadSplitSize = Int(UInt16.max)

// TODO: Move somewhere
extension Array {
    func split(by subSize: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: subSize).map { startIndex in
            let next = startIndex.advanced(by: subSize)
            let end = next <= endIndex ? next : endIndex
            return Array(self[startIndex ..< end])
        }
    }
}

extension WebSocket {
    public func send(fin: Bool,
                     rsv1: Bool = false,
                     rsv2: Bool = false,
                     rsv3: Bool = false,
                     opCode: Frame.OpCode,
                     isMasked: Bool,
                     payload: Data) throws {
        let header = Frame.Header(
            fin: fin,
            rsv1: rsv1,
            rsv2: rsv2,
            rsv3: rsv3,
            opCode: opCode,
            isMasked: isMasked,
            payloadLength: UInt64(payload.count),
            maskingKey: .make(isMasked: isMasked)
        )
        let frame = Frame(header: header, payload: payload)
        try send(frame)
    }
}

extension WebSocket {
    public func send(_ frame: Frame) throws {
        // TODO: Throw if control frame greater than 125 byte PAYLOAD. (from spec)
        let serializer = FrameSerializer(frame)
        let data = serializer.serialize()
        try stream.send(Data(data))
    }

    // TODO: Not Masking etc. assumes Server to Client, consider strategy to support both
    public func send(_ text: String) throws {
        let payload = Data(text)
        try send(.text, with: payload)
    }

    public func send(_ binary: Data) throws {
        let payload = binary
        try send(.binary, with: payload)
    }

    public func send(_ ncf: Frame.OpCode.NonControlFrameExtension, payload: Data) throws {
        try send(.nonControlExtension(ncf), with: payload)
    }

    // MARK: Private

    private func send(_ opCode: Frame.OpCode, with payload: Data) throws {
        if payload.count < PayloadSplitSize {
            try send(fin: true,
                     rsv1: false,
                     rsv2: false,
                     rsv3: false,
                     opCode: opCode,
                     isMasked: mode.maskOutgoingMessages,
                     payload: payload)
        } else {
            let chunks = payload.bytes.split(by: PayloadSplitSize)
            let first = 0
            let last = chunks.count - 1
            let isMasked = mode.maskOutgoingMessages
            try chunks.enumerated().forEach { idx, bytes in
                let payload = Data(bytes)

                if idx == first {
                    try send(fin: false,
                             opCode: opCode,
                             isMasked: isMasked,
                             payload: payload)
                } else if idx == last {
                    try send(fin: true,
                             opCode: .continuation,
                             isMasked: isMasked,
                             payload: payload)
                } else {
                    try send(fin: false,
                             opCode: .continuation,
                             isMasked: isMasked,
                             payload: payload)
                }
            }
        }
    }
}
