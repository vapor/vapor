/// A stream of decoded rows related to a query
///
/// This API is currently internal so we don't break the public API when finalizing the "raw" row API
final class RowStream : ResultsStream {
    var onEOF: ((UInt16) throws -> ())? {
        return { _ in
            self.close()
        }
    }
    
    /// For internal notification purposes only
    func close() {
        self.onClose?()
    }
    
    /// Parses a packet into a Row
    func parseRows(from packet: Packet) throws -> Row {
        return try packet.makeRow(columns: columns, binary: binary)
    }
    
    /// Creates a new RowStream using the specified protocol (from MySQL 4.0 or 4.1) and optionally the binary protocol instead of text
    init(mysql41: Bool, binary: Bool = false) {
        self.mysql41 = mysql41
        self.binary = binary
    }
    
    /// A list of all fields' descriptions in this table
    var columns = [Field]()
    
    /// Used to indicate the amount of returned columns
    var columnCount: UInt64?
    
    /// -
    typealias Output = Row
    
    /// See `OutputStream.OutputHandler`
    public var outputStream: OutputHandler?
    
    /// See `BaseStream.ErrorHandler`
    public var errorStream: ErrorHandler?
    
    /// If `true`, the server protocol version is for MySQL 4.1
    let mysql41: Bool
    
    /// If `true`, the results are using the binary protocols
    var binary: Bool
    
    /// Registers an onClose handler
    public var onClose: CloseHandler?
}
