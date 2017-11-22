import Async

/// A stream of decoded rows related to a query
///
/// This API is currently internal so we don't break the public API when finalizing the "raw" row API
final class RowStream : ResultsStream {
    /// -
    typealias Output = Row

    /// A list of all fields' descriptions in this table
    var columns = [Field]()

    /// Used to indicate the amount of returned columns
    var columnCount: UInt64?

    /// If `true`, the server protocol version is for MySQL 4.1
    let mysql41: Bool

    /// If `true`, the results are using the binary protocols
    var binary: Bool

    /// Use a basic stream to easily implement our output stream.
    var outputStream: BasicStream<Output> = .init()

    /// Creates a new RowStream using the specified protocol (from MySQL 4.0 or 4.1) and optionally the binary protocol instead of text
    init(mysql41: Bool, binary: Bool = false) {
        self.mysql41 = mysql41
        self.binary = binary
    }

    /// See InputStream.onError
    public func onError(_ error: Error) {
        outputStream.onError(error)
    }

    /// See OutputStream.onOutput
    func onOutput<I>(_ input: I) where I : InputStream, Output == I.Input {
        outputStream.onOutput(input)
    }

    /// Parses a packet into a Row
    func parseRows(from packet: Packet) throws -> Row {
        return try packet.makeRow(columns: columns, binary: binary)
    }

    /// See ClosableStream.onClose
    public func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }

    /// For internal notification purposes only
    func close() {
        outputStream.close()
    }
}
