import C7

public final class WebSock {

    public typealias EventHandler<T> = (T) throws -> Void

    public enum State {
        case open
        case closing
        case closed
    }

    // MARK: EventHandlers

    public var onFrame: EventHandler<(ws: WebSock, frame: Frame)>? = nil

    public var onText: EventHandler<(ws: WebSock, text: String)>? = nil
    public var onBinary: EventHandler<(ws: WebSock, binary: Data)>? = nil

    public var onPing: EventHandler<(ws: WebSock, frame: Frame)>? = nil
    public var onPong: EventHandler<(ws: WebSock, frame: Frame)>? = nil

    public var onClose: EventHandler<(ws: WebSock, code: UInt16, reason: String, clean: Bool)>? = nil

    // MARK: Attributes

    internal let stream: Stream
    public private(set) var state: State = .open

    // MARK: Initialization

    public init(_ stream: Stream) {
        self.stream = stream
    }

    deinit {
        print("\n\n\t***** WE GONE :D *****\n\n\n")
    }
}

// MARK: Listen

extension WebSock {
    public func listen() throws {
        while state != .closed {
            // not a part of while logic, we need to separately acknowledge
            // that TCP closed w/o handshake
            if stream.closed {
                try completeCloseHandshake(cleanly: false)
                break
            }

            do {
                let parser = MessageParser(stream: stream)
                let frame = try parser.acceptMessage()
                try received(frame)
            } catch {
                Log.error("WebSocket Failed w/ error: \(error)")
                try completeCloseHandshake(cleanly: false)
            }
        }
    }

    // TODO: Sort Fragments
    private func received(_ frame: Frame) throws {
        try onFrame?((self, frame))

        switch frame.header.opCode {
        case .continuation:
            print("NOT YET HANDLING FRAGMENTS MANUALLY")
            break
        case .binary:
            let payload = frame.payload
            try onBinary?((self, payload))
        case .text:
            let text = try frame.payload.toString()
            try onText?((self, text))
        case .connectionClose:
            try receivedClose(frame)
        case .ping:
            try onPing?((self, frame))
            try pong(frame.payload)
        case .pong:
            try onPong?((self, frame))
        default:
            break
        }
    }

    private func receivedClose(_ frame: Frame) throws {
        /*

         // TODO:

         If there is a body, the first two bytes of
         the body MUST be a 2-byte unsigned integer (in network byte order)
         representing a status code with value /code/ defined in Section 7.4.
         Following the 2-byte integer, the body MAY contain UTF-8-encoded data
         with value /reason/, the interpretation of which is not defined by
         this specification.  This data is not necessarily human readable but
         may be useful for debugging or passing information relevant to the
         script that opened the connection.  As the data is not guaranteed to
         be human readable, clients MUST NOT show it to end users.
         */
        guard frame.header.opCode == .connectionClose else { throw "unexpected op code" }

        switch  state {
        case .open:
            // opponent requested close, we're responding
            try respondToClose(echo: frame.payload)
            try completeCloseHandshake(cleanly: true)
        case .closing:
            // we requested close, opponent responded
            try completeCloseHandshake(cleanly: true)
        case .closed:
            Log.info("Received close frame: \(frame) already closed.")
        }
    }
}

// MARK: Close Handshake

extension WebSock {
    public func close(statusCode: UInt16? = nil, reason: String? = nil) throws {
        // TODO: Use status code and reason data
        guard state == .open else { return }
        state = .closing

        let header = Frame.Header(
            fin: true,
            rsv1: false,
            rsv2: false,
            rsv3: false,
            opCode: .connectionClose,
            isMasked: false,
            payloadLength: 0,
            maskingKey: .none
        )
        let msg = Frame(header: header, payload: Data())
        try send(msg)
    }

    // https://tools.ietf.org/html/rfc6455#section-5.5.1
    private func respondToClose(echo payload: Data) throws {
        // ensure haven't already sent
        guard state != .closed else { return }
        state = .closing

        /*
         // TODO: Echo status code

         If an endpoint receives a Close frame and did not previously send a
         Close frame, the endpoint MUST send a Close frame in response.  (When
         sending a Close frame in response, the endpoint typically echos the
         status code it received.)
         */
        let header = Frame.Header(
            fin: true,
            rsv1: false,
            rsv2: false,
            rsv3: false,
            opCode: .connectionClose,
            isMasked: false,
            payloadLength: UInt64(payload.count),
            maskingKey: .none
        )
        let msg = Frame(header: header, payload: payload)
        try send(msg)
    }

    private func completeCloseHandshake(statusCode: UInt16 = 0, reason: String = "Not yet implemented", cleanly: Bool) throws {
        state = .closed
        try onClose?((self, statusCode, reason, cleanly))
    }
}
