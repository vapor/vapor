extension WebSocket {
    public enum Error: ErrorProtocol {
        case invalidPingFormat
        case unexpectedFragmentFrame
    }
}
