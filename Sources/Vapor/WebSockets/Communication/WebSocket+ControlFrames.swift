/*
 'close' included in Model file to ensure safety while interacting with sensitive variables
 */

extension WebSock {
    public func ping(statusCode: UInt16? = nil, reason: String? = nil) throws {
        // TODO:
        // Reason can _only_ exist if statusCode also exists
        // statusCode may exist _without_ a reason
        if statusCode != nil {

        }
        let payload: Data = []


        let header = Frame.Header(
            fin: true,
            rsv1: false,
            rsv2: false,
            rsv3: false,
            opCode: .ping,
            isMasked: false,
            payloadLength: UInt64(payload.count),
            maskingKey: .none
        )
        let msg = Frame(header: header, payload: payload)
        try stream.send(msg)
    }

    /**
     If we receive a .ping, we must .pong identical data

     Applications may opt to send unsolicited .pong messages as a sort of keep awake heart beat
     */
    public func pong(_ payload: Data) throws {
        let header = Frame.Header(
            fin: true,
            rsv1: false,
            rsv2: false,
            rsv3: false,
            opCode: .pong,
            isMasked: false,
            payloadLength: UInt64(payload.count),
            maskingKey: .none
        )
        let msg = Frame(header: header, payload: payload)
        try stream.send(msg)
    }
}
