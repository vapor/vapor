// TODO:
// More thorough testing
// Client/Server Dual Support
//

import C7

public final class WebSocket {

    public typealias EventHandler<T> = (T) throws -> Void

    public enum State {
        case open
        case closing
        case closed
    }

    internal enum Mode {
        case client, server

        var maskOutgoingMessages: Bool {
            // RFC: Client must mask messages
            return self == .client
        }
    }

    // MARK: All Frames

    public var onFrame: EventHandler<(ws: WebSocket, frame: Frame)>? = nil

    // MARK: Non Control Frames

    public var onText: EventHandler<(ws: WebSocket, text: String)>? = nil
    public var onBinary: EventHandler<(ws: WebSocket, binary: Data)>? = nil

    // MARK: Non Control Extensions

    public var onNonControlExtension:
        EventHandler<(ws: WebSocket, code: Frame.OpCode.NonControlFrameExtension, data: Data)>? = nil

    // MARK: Control Frames

    public var onPing: EventHandler<(ws: WebSocket, frame: Data)>? = nil
    public var onPong: EventHandler<(ws: WebSocket, frame: Data)>? = nil

    // MARK: Control Frame Extensions

    public var onControlExtension:
        EventHandler<(ws: WebSocket, code: Frame.OpCode.ControlFrameExtension, data: Data)>? = nil

    // MARK: Close: (Control Frame)

    public var onClose: EventHandler<(ws: WebSocket, code: UInt16?, reason: String?, clean: Bool)>? = nil

    // MARK: Attributes

    internal let stream: Stream
    internal let mode: Mode
    public private(set) var state: State = .open
    // TODO: Should aggregator be disablable?
    private var aggregator = FragmentAggregator()

    // MARK: Initialization

    public init(_ stream: Stream) {
        self.stream = stream
        self.mode = .server // TODO: Expose in api when ready
    }

    deinit {
        // TODO: Rm on ship
        print("\n\n\t***** WE GONE :D *****\n\n\n")
    }
}

// MARK: Listen

/**

 [WARNING] **********
 Sensitive code below, ensure you are fully familiar w/ various control flows and protocols
 before changing or moving things including access control

 */
extension WebSocket {
    /**
     Tells the WebSocket to begin accepting frames
     */
    public func listen() throws {
        let buffer = StreamBuffer(stream)
        let deserializer = FrameDeserializer(buffer: buffer)
        try loop(with: deserializer)
    }

    /**
     [WARNING] - deserializer MUST be declared OUTSIDE of while-loop
     to prevent losing bytes trapped in the buffer. ALWAYS pass deserializer
     as argument
     */
    private func loop<Buffer: InputBuffer>(with deserializer: FrameDeserializer<Buffer>) throws {
        while state != .closed {
            // not a part of while logic, we need to separately acknowledge
            // that TCP closed w/o handshake
            if stream.closed {
                try completeCloseHandshake(statusCode: nil, reason: nil, cleanly: false)
                break
            }

            do {
                let frame = try deserializer.acceptFrame()
                try received(frame)
            } catch {
                Log.error("WebSocket Failed w/ error: \(error)")
                try completeCloseHandshake(statusCode: nil, reason: nil, cleanly: false)
            }
        }
    }

    private func received(_ frame: Frame) throws {
        try onFrame?((self, frame))

        if frame.isFragment {
            try receivedFragment(frame)
        } else {
            try routeMessage(for: frame.header.opCode, payload: frame.payload)
        }
    }

    private func routeMessage(for opCode: Frame.OpCode, payload: Data) throws {
        switch opCode {
        case .continuation:
            // fragment handled above
            throw "received unexpected fragment frame"
        case .binary:
            try onBinary?((self, payload))
        case .text:
            let text = try payload.toString()
            try onText?((self, text))
        case let .nonControlExtension(nc):
            try onNonControlExtension?((self, nc, payload))
        case .connectionClose:
            try handleClose(payload: payload)
        case .ping:
            try onPing?((self, payload))
            try pong(payload)
        case .pong:
            try onPong?((self, payload))
        case let .controlExtension(ce):
            try onControlExtension?((self, ce, payload))
        }
    }

    private func receivedFragment(_ frame: Frame) throws {
        let fragment = try FragmentedFrame(frame)
        try aggregator.append(fragment: fragment)

        guard let (opCode, payload) = aggregator.receiveCompleteMessage() else { return }
        try routeMessage(for: opCode, payload: payload)
    }

    private func handleClose(payload: Data) throws {
        /*
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
        var statusCode: UInt16?
        var statusCodeData: Data? = nil
        var reason: String? = nil
        if !payload.isEmpty {
            var iterator = payload.makeIterator()
            let statusCodeBytes = try iterator.chunk(length: 2)
            statusCode = try UInt16(statusCodeBytes)
            statusCodeData = Data(statusCodeBytes)
            // TODO: Test this only grabs bytes left
            reason = try Data(iterator).toString()
        }

        switch  state {
        case .open:
            // opponent requested close, we're responding

            /*
             If an endpoint receives a Close frame and did not previously send a
             Close frame, the endpoint MUST send a Close frame in response.  (When
             sending a Close frame in response, the endpoint typically echos the
             status code it received.
             
             First two bytes MUST be status code if they exist
             */
            try respondToClose(echo: statusCodeData ?? [])
            try completeCloseHandshake(statusCode: statusCode, reason: reason, cleanly: true)
        case .closing:
            // we requested close, opponent responded
            try completeCloseHandshake(statusCode: statusCode, reason: reason, cleanly: true)
        case .closed:
            Log.info("Received close frame, already closed.")
        }
    }
}

// MARK: Close Handshake

extension WebSocket {
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

    private func completeCloseHandshake(statusCode: UInt16?, reason: String?, cleanly: Bool) throws {
        state = .closed
        try onClose?((self, statusCode, reason, cleanly))
    }
}
