import Async

/// A stream of decoded models related to a query
public final class ModelStream<D: Decodable> : ResultsStream {
    /// For internal notification purposes only
    public func close() {
        self.onClose?()
    }
    
    /// Registers an onClose handler
    public var onClose: CloseHandler?
    
    /// A list of all fields' descriptions in this table
    var columns = [Field]()
    
    /// Used to indicate the amount of returned columns
    var columnCount: UInt64?
    
    /// If `true`, the server protocol version is for MySQL 4.1
    let mysql41: Bool
    
    /// If `true`, the results are using the binary protocols
    var binary: Bool
    
    /// -
    public typealias Output = D
    
    /// See `OutputStream.OutputHandler`
    public var outputStream: OutputHandler?
    
    /// See `BaseStream.ErrorHandler`
    public var errorStream: ErrorHandler?
    
    /// Creates a new ModelStream using the specified protocol (from MySQL 4.0 or 4.1) and optionally the binary protocol instead of text
    init(mysql41: Bool, binary: Bool = false) {
        self.mysql41 = mysql41
        self.binary = binary
    }
    
    /// Parses a packet into a Decodable entity
    func parseRows(from packet: Packet) throws -> D {
        let row = try packet.makeRow(columns: columns, binary: binary)
        
        let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
        return try D(from: decoder)
    }
}
