import Async

/// A stream of decoded rows related to a query
///
/// This API is currently internal so we don't break the public API when finalizing the "raw" row API
final class RowStream: Async.Stream, ClosableStream {
    /// See InputStream.Input
    typealias Input = Packet

    /// See OutputStream.Output
    typealias Output = Row

    /// A list of all fields' descriptions in this table
    var columns = [Field]()

    /// Used to indicate the amount of returned columns
    var columnCount: UInt64?

    /// If `true`, the server protocol version is for MySQL 4.1
    let mysql41: Bool

    /// If `true`, the results are using the binary protocols
    var binary: Bool

    /// Handles EOF
    typealias OnEOF = (UInt16) throws -> ()

    /// Called on EOF packet
    var onEOF: OnEOF?

    /// Basic stream to easily implement async stream.
    private var outputStream: BasicStream<Output>
    
    /// Creates a new RowStream using the specified protocol (from MySQL 4.0 or 4.1) and optionally the binary protocol instead of text
    init(mysql41: Bool, binary: Bool = false) {
        self.mysql41 = mysql41
        self.binary = binary
        outputStream = .init()
        self.onEOF = { _ in self.close() }
    }
    

    /// For internal notification purposes only
    func close() {
        outputStream.close()
    }

    /// Parses a packet into a Row
    func parseRows(from packet: Packet) throws -> Row {
        return try packet.makeRow(columns: columns, binary: binary)
    }

    /// Parses an incoming packet as part of the results
    func onInput(_ input: Packet) {
        do {
            try parse(packet: input)
        } catch {
            onError(error)
        }
    }

    /// See InputStream.onError
    func onError(_ error: Error) {
        outputStream.onError(error)
        self.close()
    }

    /// See ClosableStream.onClose
    func onClose(_ onClose: ClosableStream) {
        outputStream.onClose(onClose)
    }

    /// See OutputStream.onOutput
    func onOutput<I>(_ input: I) where I: InputStream, RowStream.Output == I.Input {
        outputStream.onOutput(input)
    }

    func parse(packet: Packet) throws {
        // If the header (column count) is not yet set
        guard let columnCount = self.columnCount else {
            // Parse the column count
            let parser = Parser(packet: packet)

            // Tries to parse the header count
            guard let columnCount = try? parser.parseLenEnc() else {
                if case .error(let error) = try packet.parseResponse(mysql41: mysql41) {
                    self.onError(error)
                    self.close()
                } else {
                    self.close()
                }
                return
            }

            // No columns means an empty stream
            if columnCount == 0 {
                self.close()
            }

            self.columnCount = columnCount
            return
        }

        // if the column count isn't met yet
        if columns.count != columnCount {
            // Parse the next column
            try parseColumns(from: packet)
            return
        }

        // Otherwise, parse the next row
        try preParseRows(from: packet)
    }

    /// Parses a row from this packet, checks
    func preParseRows(from packet: Packet) throws {
        // End of file packet
        if packet.payload.first == 0xfe {
            let parser = Parser(packet: packet)
            parser.position = 1
            let flags = try parser.parseUInt16()

            if flags & serverMoreResultsExists == 0 {
                self.close()
                return
            }

            try onEOF?(flags)
            return
        }

        // If it's an error packet
        if packet.payload.count > 0,
            let pointer = packet.payload.baseAddress,
            pointer[0] == 0xff,
            let error = try packet.parseResponse(mysql41: self.mysql41).error
        {
            throw error
        }

        try outputStream.onInput(parseRows(from: packet))
    }

    /// Parses the packet as a columm specification
    func parseColumns(from packet: Packet) throws {
        // Normal responses indicate an end of columns or an error
        if packet.isTextProtocolResponse {
            do {
                switch try packet.parseResponse(mysql41: mysql41) {
                case .error(let error):
                    throw error
                case .ok(_):
                    fallthrough
                case .eof(_):
                    // If this is the end of the stream, stop
                    return
                }
            } catch {
                throw MySQLError(.invalidPacket)
            }
        }

        do {
            // Parse the column field definition
            let field = try packet.parseFieldDefinition()

            self.columns.append(field)
        } catch {
            throw MySQLError(.invalidPacket)
        }
    }
}

fileprivate let serverMoreResultsExists: UInt16 = 0x0008
