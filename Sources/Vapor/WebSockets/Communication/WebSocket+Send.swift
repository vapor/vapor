/**
     Technically WebSockets supports up to UInt64.max packet sizes, however
     frameworks have the discretion to break up large packets into fragments
     to make usage easier.
     
     Many implementations tested against crash on values > 64_000. Test extensively before changing
     this value
     
     The following functions DO NOT parse additional data into chunks. 
     Use these for customized behavior.
     
     Please familiarize yourself w/ WebSocket protocols before attempting to override built in behavior
     
     send(_ frame: Frame)
     
     Note that this function will still enforce protocol requirements that are enforced by RFC
     
     It is necessary to expose this functions because extensions may negotiate various usages of extensions
     etc. that is required to not be overridden

 */
private let PayloadSplitSize = Int(64_000)

extension WebSocket {
    public func send(_ text: String) throws {
        let payload = Data(text)
        try send(opCode: .text, with: payload)
    }

    public func send(_ binary: Data) throws {
        let payload = binary
        try send(opCode: .binary, with: payload)
    }

    public func send(_ ncf: Frame.OpCode.NonControlFrameExtension, payload: Data) throws {
        try send(opCode: .nonControlExtension(ncf), with: payload)
    }
}


extension WebSocket {
    public func send(_ frame: Frame) throws {
        // TODO: Throw if control frame greater than 125 byte PAYLOAD. (from spec)
        let serializer = FrameSerializer(frame)
        let data = serializer.serialize()
        try stream.send(data, flushing: true)
    }
}

extension WebSocket {
    public func send(rsv1: Bool = false,
                     rsv2: Bool = false,
                     rsv3: Bool = false,
                     opCode: Frame.OpCode,
                     with payload: Data) throws {
        let isMasked = mode.maskOutgoingMessages

        if payload.count < PayloadSplitSize {
            let header = Frame.Header(
                fin: true,
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
        } else {
            let chunks = payload.bytes.split(by: PayloadSplitSize)
            let first = 0
            let last = chunks.count - 1
            try chunks.enumerated().forEach { idx, bytes in
                let payload = Data(bytes)

                let fin: Bool
                let op: Frame.OpCode
                if idx == first {
                    // head
                    fin = false
                    op = opCode
                } else if idx == last {
                    // tail
                    fin = true
                    op = .continuation
                } else {
                    // body
                    fin = false
                    op = .continuation
                }

                let header = Frame.Header(
                    fin: fin,
                    rsv1: rsv1,
                    rsv2: rsv2,
                    rsv3: rsv3,
                    opCode: op,
                    isMasked: isMasked,
                    payloadLength: UInt64(payload.count),
                    maskingKey: .make(isMasked: isMasked)
                )
                let frame = Frame(header: header, payload: payload)
                try send(frame)
            }
        }
    }
}
